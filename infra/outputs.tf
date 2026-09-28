output "dns_ip" {
  description = "IP público do Blocky. Configure como DNS primário no roteador."
  value       = mgc_network_public_ips.this.public_ip
}

output "ssh" {
  description = "Comando de acesso SSH."
  value       = "ssh ubuntu@${mgc_network_public_ips.this.public_ip}"
}

output "allowed_cidrs" {
  description = "CIDRs autorizados no firewall."
  value       = local.dns_allowed_cidrs
}
