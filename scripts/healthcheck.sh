#!/usr/bin/env bash
# Verifica se o Blocky resolve e bloqueia, e se a rede de casa continua chegando
# até ele. Se HEALTHCHECK_URL estiver definido (ex.: healthchecks.io), envia ping
# de sucesso/falha — você é notificado quando a VM some, o DNS para de responder
# ou a casa perde o acesso (dead man's switch externo).
set -uo pipefail

# shellcheck source=/dev/null
source /etc/blocky-cloud-dns/env

# Silêncio da rede de casa por mais que isso = casa sem acesso ao DNS (ex.: o IP
# de casa mudou e o firewall barrou). Uma casa típica faz milhares de consultas/dia.
idle_window_min=30
querylog_dir=/var/lib/docker/volumes/blocky_blocky-logs/_data

resolve=$(dig +short +time=3 +tries=2 @127.0.0.1 cloudflare.com A | head -1)
block=$(dig +short +time=3 +tries=2 @127.0.0.1 pagead2.googlesyndication.com A | head -1)

# Consultas de clientes externos (fora das redes Docker/loopback) na janela.
home_queries() {
  local since files
  since=$(date -d "-${idle_window_min} min" '+%F %T')
  files=$(printf '%s\n' "$querylog_dir/$(date -d "-${idle_window_min} min" +%F)_ALL.log" \
    "$querylog_dir/$(date +%F)_ALL.log" | sort -u)
  # shellcheck disable=SC2086
  cat $files 2>/dev/null |
    awk -F'\t' -v t="$since" '$1 >= t && $2 !~ /^(172\.|127\.)/' | wc -l
}

uptime_min=$(($(cut -d. -f1 /proc/uptime) / 60))
if ((uptime_min < idle_window_min)); then
  home="skip"
else
  home=$(home_queries)
fi

if [[ "$resolve" =~ ^[0-9.]+$ && "$block" == "0.0.0.0" && "$home" != "0" ]]; then
  status=ok
  suffix=""
else
  status=fail
  suffix="/fail"
fi

echo "[healthcheck] $status resolve=${resolve:-none} block=${block:-none} home_queries_${idle_window_min}m=${home}"
[[ "$home" == "0" ]] && echo "[healthcheck] nenhuma consulta da rede de casa em ${idle_window_min} min — o IP de casa mudou? rode 'make update-ip'"

if [[ -n "${HEALTHCHECK_URL:-}" ]]; then
  curl -fsS -m 10 --retry 3 -o /dev/null "${HEALTHCHECK_URL}${suffix}" || true
fi

[[ "$status" == ok ]]
