@echo off
REM Black Sheep AIOS - desfazer o ultimo update (duplo-clique no Windows; caminho de recuperacao).
REM O caminho principal e /bsaios-rollback dentro do Claude Code.
powershell -ExecutionPolicy Bypass -NoProfile -Command "node \"$env:USERPROFILE\.claude\.bsaios\updater\lib\bsaios-rollback.js\" --claude-home \"$env:USERPROFILE\.claude\""
pause
