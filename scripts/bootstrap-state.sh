#!/usr/bin/env bash
# Cria (uma única vez) o bucket privado e versionado do state do Terraform no
# Object Storage da Magalu. Idempotente. Requer AWS_ACCESS_KEY_ID/SECRET do .env.
set -euo pipefail

bucket=$(sed -nE 's/^ *bucket *= *"([^"]+)".*/\1/p' "$(dirname "$0")/../infra/versions.tf")
endpoint=https://br-se1.magaluobjects.com
s3() { AWS_REGION=br-se1 aws --endpoint-url "$endpoint" s3api "$@"; }

if s3 head-bucket --bucket "$bucket" 2>/dev/null; then
  echo "bucket $bucket já existe"
else
  s3 create-bucket --bucket "$bucket" >/dev/null
  echo "bucket $bucket criado"
fi
s3 put-bucket-versioning --bucket "$bucket" --versioning-configuration Status=Enabled
echo "versionamento habilitado"
