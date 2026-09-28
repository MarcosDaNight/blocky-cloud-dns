#!/usr/bin/env bash
# Reconcilia a VM com o estado declarado no Git (GitOps pull-based).
# Executado pelo blocky-gitops.timer. Fluxo:
#   fetch -> há commit novo? -> valida (compose, blocky, prometheus) -> aplica
#   -> verifica se o DNS responde -> se não, volta para o último commit bom.
#
# Uso: gitops-sync.sh [--force]   (--force reaplica mesmo sem commit novo)
#
# Todo o corpo fica dentro de main(): o bash lê o script inteiro antes de executar,
# então o `git checkout` pode reescrever este arquivo com segurança.

main() {
  set -euo pipefail

  # shellcheck source=/dev/null
  source /etc/blocky-cloud-dns/env
  local repo=/opt/blocky-cloud-dns
  local state_dir=/var/lib/blocky-cloud-dns
  local force="${1:-}"
  mkdir -p "$state_dir"
  cd "$repo"

  git fetch --quiet origin "$REPO_BRANCH"
  local target applied failed
  target=$(git rev-parse "origin/$REPO_BRANCH")
  applied=$(cat "$state_dir/applied" 2>/dev/null || true)
  failed=$(cat "$state_dir/failed" 2>/dev/null || true)

  if [[ "$force" != "--force" ]]; then
    [[ "$target" == "$applied" ]] && exit 0
    if [[ "$target" == "$failed" ]]; then
      log "commit ${target:0:7} já falhou antes; aguardando um novo commit"
      exit 0
    fi
  fi

  log "reconciliando ${applied:0:7} -> ${target:0:7}"

  if ! validate "$target"; then
    log "ERRO: validação falhou para ${target:0:7}; nada foi aplicado"
    echo "$target" >"$state_dir/failed"
    [[ -n "$applied" ]] && checkout "$applied"
    exit 1
  fi

  apply "$applied" "$target"

  if dns_healthy; then
    echo "$target" >"$state_dir/applied"
    rm -f "$state_dir/failed"
    docker image prune -f >/dev/null
    log "OK: ${target:0:7} aplicado"
  else
    log "ERRO: DNS não respondeu após aplicar ${target:0:7}"
    echo "$target" >"$state_dir/failed"
    if [[ -n "$applied" ]]; then
      log "rollback para ${applied:0:7}"
      apply "$target" "$applied"
      dns_healthy || log "ERRO: DNS segue indisponível após rollback"
    fi
    exit 1
  fi
}

log() { echo "[gitops] $*"; }

checkout() { git -c advice.detachedHead=false checkout --quiet --force "$1"; }

compose() { docker compose --project-directory /opt/blocky-cloud-dns/deploy -f /opt/blocky-cloud-dns/deploy/compose.yaml "$@"; }

validate() {
  checkout "$1"
  compose config --quiet &&
    compose run --rm --no-deps -T blocky validate &&
    compose run --rm --no-deps -T --entrypoint promtool prometheus \
      check config /etc/prometheus/prometheus.yml >/dev/null
}

# apply <de> <para>: instala units do systemd, sobe a stack e reinicia os serviços
# cujos arquivos de configuração mudaram (bind mounts não disparam recriação).
apply() {
  local from="$1" to="$2"
  checkout "$to"

  local unit reload=false
  for unit in deploy/systemd/*; do
    if ! cmp -s "$unit" "/etc/systemd/system/${unit##*/}"; then
      install -m 0644 "$unit" /etc/systemd/system/
      reload=true
    fi
  done
  if $reload; then
    systemctl daemon-reload
    systemctl enable --now blocky-gitops.timer blocky-healthcheck.timer
  fi

  compose pull --quiet
  compose up -d --remove-orphans

  [[ -z "$from" ]] && return 0
  local svc
  for svc in blocky prometheus grafana; do
    if ! git diff --quiet "$from" "$to" -- "deploy/$svc"; then
      log "config de $svc mudou; reiniciando"
      compose restart "$svc"
    fi
  done
}

dns_healthy() {
  for _ in $(seq 1 30); do
    if dig +short +time=2 +tries=1 @127.0.0.1 cloudflare.com A | grep -qE '^[0-9.]+$'; then
      return 0
    fi
    sleep 2
  done
  return 1
}

main "$@"
