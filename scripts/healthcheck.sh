#!/usr/bin/env bash
# Verifica se o Blocky resolve e bloqueia. Se HEALTHCHECK_URL estiver definido
# (ex.: healthchecks.io), envia ping de sucesso/falha — você é notificado quando
# a VM some ou o DNS para de responder (dead man's switch externo).
set -uo pipefail

# shellcheck source=/dev/null
source /etc/blocky-cloud-dns/env

resolve=$(dig +short +time=3 +tries=2 @127.0.0.1 cloudflare.com A | head -1)
block=$(dig +short +time=3 +tries=2 @127.0.0.1 pagead2.googlesyndication.com A | head -1)

if [[ "$resolve" =~ ^[0-9.]+$ && "$block" == "0.0.0.0" ]]; then
  status=ok
  suffix=""
else
  status=fail
  suffix="/fail"
fi

echo "[healthcheck] $status resolve=${resolve:-none} block=${block:-none}"

if [[ -n "${HEALTHCHECK_URL:-}" ]]; then
  curl -fsS -m 10 --retry 3 -o /dev/null "${HEALTHCHECK_URL}${suffix}" || true
fi

[[ "$status" == ok ]]
