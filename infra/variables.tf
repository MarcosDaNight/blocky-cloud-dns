variable "mgc_api_key" {
  description = "API key da Magalu Cloud (via TF_VAR_mgc_api_key no .env)."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Região da Magalu Cloud."
  type        = string
  default     = "br-ne1"
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

variable "home_ddns_host" {
  description = "Hostname DDNS mantido pelo roteador de casa. A VM resolve a cada 2 min e libera só esse IP em DNS (53) e SSH (22)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9.-]+\\.[a-z]{2,}$", var.home_ddns_host))
    error_message = "home_ddns_host deve ser um hostname (ex.: minha-casa.duckdns.org)."
  }
}

variable "extra_allowed_cidrs" {
  description = "CIDRs IPv4 fixos autorizados além do IP de casa (ex.: casa de familiares, break-glass)."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.extra_allowed_cidrs : can(cidrhost(c, 0))])
    error_message = "extra_allowed_cidrs deve conter CIDRs IPv4 (ex.: 198.51.100.7/32)."
  }
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
