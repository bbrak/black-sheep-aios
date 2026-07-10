#!/bin/bash
# Black Sheep AIOS — desfazer o ultimo update (duplo-clique no macOS; caminho de recuperacao).
# O caminho principal e /bsaios-rollback dentro do Claude Code.
H="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
node "$H/.bsaios/updater/lib/bsaios-rollback.js" --claude-home "$H"
echo ""
read -n1 -r -p "Pressione qualquer tecla para fechar..."
