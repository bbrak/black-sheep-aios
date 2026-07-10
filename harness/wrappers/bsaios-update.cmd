@echo off
REM Black Sheep AIOS - atualizar o harness (duplo-clique no Windows; caminho de recuperacao).
REM O caminho principal e /bsaios-update dentro do Claude Code. Usa powershell -ExecutionPolicy
REM Bypass para nao esbarrar em politica de execucao ao chamar o updater Node.
powershell -ExecutionPolicy Bypass -NoProfile -Command "node \"$env:USERPROFILE\.claude\.bsaios\updater\lib\bsaios-update.js\" --claude-home \"$env:USERPROFILE\.claude\""
pause
