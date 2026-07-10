@echo off
REM Black Sheep AIOS - desfazer o ultimo update (duplo-clique no Windows; caminho de recuperacao).
REM O caminho principal e /bsaios-rollback dentro do Claude Code.
powershell -ExecutionPolicy Bypass -NoProfile -Command "$h= if($env:CLAUDE_CONFIG_DIR){$env:CLAUDE_CONFIG_DIR}else{Join-Path $env:USERPROFILE '.claude'}; node \"$h\.bsaios\updater\lib\bsaios-rollback.js\" --claude-home \"$h\""
pause
