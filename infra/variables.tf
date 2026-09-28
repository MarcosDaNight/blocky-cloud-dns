variable "mgc_api_key" {
  description = "API key da Magalu Cloud (via TF_VAR_mgc_api_key no .env)."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Região da Magalu Cloud."
  type        = string
  default     = "br-se1"
}

variable "name" {
  description = "Prefixo dos recursos."
  type        = string
  default     = "blocky"
}

variable "machine_type" {
  description = "Tipo da VM. BV1-1-10 (1 vCPU, 1 GB RAM, 10 GB disco) é suficiente para uso residencial."
  type        = string
  default     = "BV1-1-10"
}

variable "image" {
  description = "Imagem do SO."
  type        = string
  default     = "cloud-ubuntu-24.04 LTS"
}

variable "ssh_key_name" {
  description = "Nome da chave SSH já cadastrada na Magalu Cloud."
  type        = string
  default     = "mgdn-key"
}

variable "home_ip" {
  description = "IP público IPv4 da residência. Único IP autorizado em DNS (53) e SSH (22). Atualize com `make update-ip`."
  type        = string

  validation {
    condition     = can(cidrhost("${var.home_ip}/32", 0))
    error_message = "home_ip deve ser um IPv4 válido, sem máscara (ex.: 203.0.113.10)."
  }
}

variable "extra_allowed_cidrs" {
  description = "CIDRs IPv4 adicionais autorizados a usar o DNS (ex.: casa de familiares)."
  type        = list(string)
  default     = []
}

variable "repo_url" {
  description = "URL HTTPS do repositório Git que a VM acompanha (GitOps pull)."
  type        = string
  default     = "https://github.com/MarcosDaNight/blocky-cloud-dns.git"
}

variable "repo_branch" {
  description = "Branch acompanhada pela VM."
  type        = string
  default     = "main"
}

variable "healthcheck_url" {
  description = "Opcional: URL de ping (ex.: healthchecks.io) chamada a cada 5 min quando o DNS está saudável. Vazio desativa."
  type        = string
  default     = ""
  sensitive   = true
}
