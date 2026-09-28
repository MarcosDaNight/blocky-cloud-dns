terraform {
  required_version = ">= 1.10"

  required_providers {
    mgc = {
      source  = "magalucloud/mgc"
      version = "~> 0.55"
    }
  }

  # State remoto no Object Storage da Magalu (API S3). Bucket privado e versionado,
  # criado uma única vez por `make bootstrap`. Credenciais via AWS_ACCESS_KEY_ID /
  # AWS_SECRET_ACCESS_KEY (key pair da API key, carregadas do .env).
  backend "s3" {
    bucket = "blocky-cloud-dns-tfstate-b29a4ccd"
    key    = "blocky-cloud-dns/terraform.tfstate"
    region = "br-se1"

    endpoints = {
      s3 = "https://br-se1.magaluobjects.com"
    }

    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}

provider "mgc" {
  region  = var.region
  api_key = var.mgc_api_key
}
