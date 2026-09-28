SHELL := /bin/bash
.DEFAULT_GOAL := help

TF      ?= terraform
ENV     := set -a && source ./.env && set +a &&
TFDIR   := infra
IP       = $$(cd $(TFDIR) && $(ENV_ABS) $(TF) output -raw dns_ip)
ENV_ABS := set -a && source ../.env && set +a &&
SSH      = ssh -o StrictHostKeyChecking=accept-new ubuntu@$(IP)
COMPOSE := sudo docker compose -f /opt/blocky-cloud-dns/deploy/compose.yaml

.PHONY: help
help: ## Lista os comandos
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

# --- Infra ----------------------------------------------------------------------

.PHONY: bootstrap init plan apply destroy update-ip
bootstrap: ## Cria o bucket do state remoto (uma vez) e roda o init
	@$(ENV) scripts/bootstrap-state.sh
	@$(MAKE) --no-print-directory init

init: ## terraform init
	@cd $(TFDIR) && $(ENV_ABS) $(TF) init -input=false

plan: ## terraform plan
	@cd $(TFDIR) && $(ENV_ABS) $(TF) plan

apply: ## terraform apply
	@cd $(TFDIR) && $(ENV_ABS) $(TF) apply

destroy: ## Destroi VM, IP e firewall (o bucket de state permanece)
	@cd $(TFDIR) && $(ENV_ABS) $(TF) destroy

update-ip: ## Detecta o IP atual de casa e atualiza o firewall (AUTO_APPROVE=1 p/ não perguntar)
	@$(ENV) TF=$(TF) scripts/update-ip.sh

# --- Operação -------------------------------------------------------------------

.PHONY: ssh tunnel grafana-password status vm-bootstrap sync logs querylog test
ssh: ## SSH na VM
	@$(SSH)

tunnel: ## Grafana :3000, Prometheus :9090 e API do Blocky :4000 em localhost
	@echo "Grafana    http://localhost:3000  (user admin; senha: make grafana-password)"
	@echo "Prometheus http://localhost:9090"
	@echo "Blocky API http://localhost:4000"
	@$(SSH) -N -L 3000:127.0.0.1:3000 -L 9090:127.0.0.1:9090 -L 4000:127.0.0.1:4000

grafana-password: ## Mostra a senha do admin do Grafana
	@$(SSH) sudo cut -d= -f2 /etc/blocky-cloud-dns/grafana.env

status: ## Estado dos containers, commit aplicado e último sync
	@$(SSH) 'echo "commit aplicado: $$(sudo cat /var/lib/blocky-cloud-dns/applied | cut -c1-7)"; \
	  $(COMPOSE) ps --format "table {{.Service}}\t{{.Status}}"; echo; \
	  systemctl list-timers "blocky-*" --no-pager; echo; free -h; df -h /'

vm-bootstrap: ## Clona o repo na VM (se faltar) e roda o primeiro sync — se o repo não estava acessível no boot
	@$(SSH) "sudo bash -c '. /etc/blocky-cloud-dns/env; test -d /opt/blocky-cloud-dns/.git || git clone -q -b \$$REPO_BRANCH \$$REPO_URL /opt/blocky-cloud-dns; /opt/blocky-cloud-dns/scripts/gitops-sync.sh --force'"

sync: ## Força o GitOps sync agora (sem esperar o timer)
	@$(SSH) 'sudo systemctl start blocky-gitops.service; sudo journalctl -u blocky-gitops -n 20 --no-pager'

logs: ## Logs do Blocky (SERVICE=grafana etc.)
	@$(SSH) '$(COMPOSE) logs --tail 100 -f $(or $(SERVICE),blocky)'

querylog: ## Últimos domínios bloqueados (N=50)
	@$(SSH) 'sudo sh -c "cat /var/lib/docker/volumes/blocky_blocky-logs/_data/*.log" | awk -F"\t" "\$$5 ~ /BLOCKED/ {print \$$1, \$$6}" | tail -n $(or $(N),50)'

test: ## Testa resolução e bloqueio a partir desta máquina
	@ip=$(IP); \
	 echo -n "resolve cloudflare.com -> "; dig +short @$$ip cloudflare.com | head -1; \
	 echo -n "bloqueia pagead2.googlesyndication.com -> "; dig +short @$$ip pagead2.googlesyndication.com | head -1

# --- Qualidade ------------------------------------------------------------------

.PHONY: fmt lint
fmt: ## Formata o Terraform
	@$(TF) fmt -recursive $(TFDIR)

lint: ## Validações locais (as mesmas do CI, exceto as que precisam de Docker)
	@$(TF) fmt -check -recursive $(TFDIR)
	@cd $(TFDIR) && $(TF) validate
	@if command -v shellcheck >/dev/null; then shellcheck scripts/*.sh; else echo "shellcheck ausente, pulando"; fi
	@for f in deploy/grafana/dashboards/*.json; do python3 -m json.tool $$f >/dev/null; done
	@echo "lint ok"
