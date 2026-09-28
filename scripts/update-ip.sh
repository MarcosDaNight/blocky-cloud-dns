#!/usr/bin/env bash
# Detecta o IP público atual da residência e, se mudou, atualiza o firewall da VM.
# Usa 1.1.1.1 por IP literal: funciona mesmo quando o DNS de casa já parou
# (que é justamente o sintoma de IP trocado).
set -euo pipefail

cd "$(dirname "$0")/../infra"
tfvars=terraform.tfvars

ip=$(curl -fsS -m 10 https://1.1.1.1/cdn-cgi/trace | awk -F= '/^ip=/{print $2}')
if [[ ! "$ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
  echo "não foi possível detectar um IPv4 público (obtido: '${ip}')" >&2
  exit 1
fi

current=$(sed -nE 's/^home_ip *= *"([^"]*)".*/\1/p' "$tfvars" 2>/dev/null || true)
if [[ "$ip" == "$current" ]]; then
  echo "IP inalterado ($ip). Nada a fazer."
  exit 0
fi

echo "IP da residência: ${current:-<vazio>} -> $ip"
if grep -q '^home_ip' "$tfvars" 2>/dev/null; then
  sed -i -E "s/^home_ip *=.*/home_ip = \"$ip\"/" "$tfvars"
else
  echo "home_ip = \"$ip\"" >>"$tfvars"
fi

"${TF:-terraform}" apply -input=false ${AUTO_APPROVE:+-auto-approve}
