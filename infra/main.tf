# Desativado: a infraestrutura migrou para o mgdn-platform
# (https://github.com/MarcosDaNight/mgdn-platform, ADR 0004). O IP público
# 201.23.0.88 é entregue intacto e importado lá, então o roteador de casa não muda.
# Os demais recursos (VM, security group, regras, attach) são destruídos.
removed {
  from = mgc_network_public_ips.this

  lifecycle {
    destroy = false
  }
}
