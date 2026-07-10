---
description: Desfaz o ultimo update do harness Black Sheep AIOS restaurando o backup mais novo. Seu pessoal e suas credenciais nao sao tocados.
allowed-tools: Bash
---

Desfaca o ultimo update do harness **Black Sheep AIOS**. O trabalho e feito por um script Node
**fora da sessao** — voce so orquestra. **Nao edite arquivos voce mesmo.**

1. **Liste os backups:**
   ```bash
   node ~/.claude/.bsaios/updater/lib/bsaios-rollback.js --claude-home ~/.claude --list
   ```
2. **Pergunte em pt-BR** se o usuario quer restaurar o **mais novo** (mostre a versao que ele traz de
   volta) ou um `<stamp>` especifico.
3. **So com o "sim"**, restaure:
   ```bash
   node ~/.claude/.bsaios/updater/lib/bsaios-rollback.js --claude-home ~/.claude --yes
   ```
   (ou `... --backup <stamp> --yes` para um especifico). Segredos (`settings.local.json`,
   `.credentials.json`, `*.pem`, `*.key`) **nunca** sao tocados.
4. Ao final, diga para rodar `/reload-plugins` ou reiniciar a sessao para aplicar.
