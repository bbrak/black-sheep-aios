@echo off
REM Black Sheep AIOS - atualizar o harness (duplo-clique no Windows; caminho de recuperacao).
REM O caminho principal e /bsaios-update dentro do Claude Code. Usa powershell -ExecutionPolicy
REM Bypass para nao esbarrar em politica de execucao ao chamar o updater Node.
powershell -ExecutionPolicy Bypass -NoProfile -Command "$h= if($env:CLAUDE_CONFIG_DIR){$env:CLAUDE_CONFIG_DIR}else{Join-Path $env:USERPROFILE '.claude'}; node \"$h\.bsaios\updater\lib\bsaios-update.js\" --claude-home \"$h\""
pause
