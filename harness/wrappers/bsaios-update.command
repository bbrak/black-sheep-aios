#!/bin/bash
# Black Sheep AIOS — atualizar o harness (duplo-clique no macOS; caminho de recuperacao/emergencia).
# O caminho principal e /bsaios-update dentro do Claude Code.
node "$HOME/.claude/.bsaios/updater/lib/bsaios-update.js" --claude-home "$HOME/.claude"
echo ""
read -n1 -r -p "Pressione qualquer tecla para fechar..."
