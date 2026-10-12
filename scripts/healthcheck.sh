#!/usr/bin/env bash
# Verifica se o Blocky resolve e bloqueia, se a rede de casa continua chegando
# até ele e se o disco tem folga. Se HEALTHCHECK_URL estiver definido (ex.:
# healthchecks.io), envia ping de sucesso/falha — você é notificado quando a VM
# some, o DNS para de responder, a casa perde o acesso ou o disco enche
# (dead man's switch externo).
set -uo pipefail

# shellcheck source=/dev/null
source /etc/blocky-cloud-dns/env

# Silêncio da rede de casa por mais que isso = casa sem acesso ao DNS (ex.: o IP
# de casa mudou e o firewall barrou). Uma casa típica faz milhares de consultas/dia.
idle_window_min=30
# Acima disso o disco de 10 GB está perto de encher (limites e limpeza devem manter < 75%).
disk_max_pct=85
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

disk=$(df --output=pcent / | tail -1 | tr -dc '0-9')

if [[ "$resolve" =~ ^[0-9.]+$ && "$block" == "0.0.0.0" && "$home" != "0" ]] && ((disk < disk_max_pct)); then
  status=ok
  suffix=""
else
  status=fail
  suffix="/fail"
fi

echo "[healthcheck] $status resolve=${resolve:-none} block=${block:-none} home_queries_${idle_window_min}m=${home} disk=${disk}%"
((disk >= disk_max_pct)) && echo "[healthcheck] disco em ${disk}% — veja 'docker system df' e 'du -xh / | sort -h | tail'"
[[ "$home" == "0" ]] && echo "[healthcheck] nenhuma consulta da rede de casa em ${idle_window_min} min — DDNS do roteador desatualizado? veja 'make allowlist'"

if [[ -n "${HEALTHCHECK_URL:-}" ]]; then
  curl -fsS -m 10 --retry 3 -o /dev/null "${HEALTHCHECK_URL}${suffix}" || true
fi

[[ "$status" == ok ]]
