#!/bin/bash
# Black Sheep AIOS — desfazer o ultimo update (duplo-clique no macOS; caminho de recuperacao).
# O caminho principal e /bsaios-rollback dentro do Claude Code.
node "$HOME/.claude/.bsaios/updater/lib/bsaios-rollback.js" --claude-home "$HOME/.claude"
echo ""
read -n1 -r -p "Pressione qualquer tecla para fechar..."
