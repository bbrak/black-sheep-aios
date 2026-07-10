---
description: Atualiza o harness Black Sheep AIOS (skills, agents, rules, hooks, settings) com 1 comando e 1 sim/nao. Nunca toca no seu pessoal.
allowed-tools: Bash
---

Voce vai conduzir a atualizacao do harness **Black Sheep AIOS**. O trabalho pesado e feito por um
script Node **fora da sessao** — voce so orquestra e faz a pergunta. **Nao edite arquivos voce mesmo.**

1. **Preview (nada e aplicado).** Rode:
   ```bash
   H="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
   node "$H/.bsaios/updater/lib/bsaios-update.js" --claude-home "$H" --check
   ```
   Mostra a versao instalada, a ultima disponivel e o delta do CHANGELOG. Se aparecer
   **"Ja esta atualizado"**, informe isso ao usuario e **pare** — nao ha o que fazer.

2. **Pergunte em pt-BR:** *"Quer atualizar de vX para vY? (sim/nao)"*, resumindo o delta do CHANGELOG.

3. **So com o "sim" explicito**, aplique:
   ```bash
   H="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
   node "$H/.bsaios/updater/lib/bsaios-update.js" --claude-home "$H" --yes
   ```
   O updater e **transacional**: em qualquer falha restaura o backup e mantem a versao antiga. Ele
   **nunca** toca no seu pessoal (`settings.local.json`, credenciais, `model`/`theme`) e aposenta
   arquivos que sairam do repo (orfaos), sempre com backup.

4. Ao final, diga para rodar `/reload-plugins` **ou reiniciar a sessao** para aplicar (mudancas de
   plugin/hook/settings entram na proxima sessao). Se algo sair errado: **`/bsaios-rollback`**.
