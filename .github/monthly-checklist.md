Checklist mensal de manutenção do DNS de casa. Marque os itens e feche a issue quando terminar.

### DDNS (o mais importante)
- [ ] **No-IP:** confirmar o hostname (e-mail *"Confirm your hostname"*, ou em <https://my.noip.com> → *Dynamic DNS*). No plano gratuito, ele expira se não for confirmado a cada 30 dias.
- [ ] `make allowlist`: o IP liberado é igual ao IP atual de casa (`curl -s https://1.1.1.1/cdn-cgi/trace | grep ip=`).

### Saúde
- [ ] <https://healthchecks.io>: check **up**, sem falhas inesperadas no mês.
- [ ] `make test`: resolve e bloqueia.
- [ ] `make status`: RAM disponível > 100 MB, disco < 80%, commit aplicado = último da `main`.

### Atualizações
- [ ] Revisar e mergear os PRs abertos do Dependabot. Isso também mantém o repo ativo: o GitHub desativa workflows agendados (como este) após 60 dias sem commits.

### Prazos
- [ ] API key `blocky-terraform` expira em **28/09/2027**. A partir de 08/2027, renove com o comando do `.env.example`.
