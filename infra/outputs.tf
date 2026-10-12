output "dns_ip" {
  description = "IP público do Blocky. Configure como DNS primário no roteador."
  value       = mgc_network_public_ips.this.public_ip
}

output "ssh" {
  description = "Comando de acesso SSH."
  value       = "ssh ubuntu@${mgc_network_public_ips.this.public_ip}"
}

output "home_ddns_host" {
  description = "Hostname DDNS cujo IP a VM libera (veja `make allowlist`)."
  value       = var.home_ddns_host
}
