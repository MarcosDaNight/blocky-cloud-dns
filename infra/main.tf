locals {
  dns_allowed_cidrs = concat(["${var.home_ip}/32"], var.extra_allowed_cidrs)

  # Regras de entrada: DNS (udp+tcp) para os CIDRs autorizados e SSH só da residência.
  ingress_rules = merge(
    { for pair in setproduct(local.dns_allowed_cidrs, ["udp", "tcp"]) :
      "dns-${pair[1]}-${pair[0]}" => { protocol = pair[1], port = 53, cidr = pair[0], description = "DNS ${pair[1]}" }
    },
    {
      "ssh-${var.home_ip}/32" = { protocol = "tcp", port = 22, cidr = "${var.home_ip}/32", description = "SSH (casa)" }
    },
  )
}

data "mgc_network_vpcs" "all" {}

locals {
  default_vpc_id = one([for v in data.mgc_network_vpcs.all.items : v.id if v.name == "vpc_default"])
}

# --- Firewall -------------------------------------------------------------------

resource "mgc_network_security_groups" "this" {
  name                  = "${var.name}-sg"
  description           = "Blocky DNS: entrada apenas da residencia"
  disable_default_rules = true
}

resource "mgc_network_security_groups_rules" "egress" {
  for_each = toset(["IPv4", "IPv6"])

  security_group_id = mgc_network_security_groups.this.id
  description       = "Saida liberada (upstreams DoH, listas, apt, git)"
  direction         = "egress"
  ethertype         = each.key
  remote_ip_prefix  = each.key == "IPv4" ? "0.0.0.0/0" : "::/0"
}

resource "mgc_network_security_groups_rules" "ingress" {
  for_each = local.ingress_rules

  security_group_id = mgc_network_security_groups.this.id
  description       = each.value.description
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = each.value.protocol
  port_range_min    = each.value.port
  port_range_max    = each.value.port
  remote_ip_prefix  = each.value.cidr
}

# --- IP público -----------------------------------------------------------------
# Recurso separado da VM: o IP sobrevive a recriações da VM, então a configuração
# do roteador de casa nunca precisa mudar.

resource "mgc_network_public_ips" "this" {
  vpc_id      = local.default_vpc_id
  description = "${var.name} DNS"
}

resource "mgc_network_public_ips_attach" "this" {
  public_ip_id = mgc_network_public_ips.this.id
  interface_id = one([for n in mgc_virtual_machine_instances.this.network_interfaces : n.id if n.primary])
}

# --- VM -------------------------------------------------------------------------

resource "mgc_virtual_machine_instances" "this" {
  name                     = var.name
  machine_type             = var.machine_type
  image                    = var.image
  ssh_key_name             = var.ssh_key_name
  vpc_id                   = local.default_vpc_id
  allocate_public_ipv4     = false
  creation_security_groups = [mgc_network_security_groups.this.id]

  user_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tftpl", {
    repo_url        = var.repo_url
    repo_branch     = var.repo_branch
    healthcheck_url = var.healthcheck_url
  }))
}
