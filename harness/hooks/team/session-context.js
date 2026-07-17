#!/usr/bin/env node
// Hook: SessionStart (startup | clear | compact)
// Ao abrir o Claude num projeto, injeta um resumo curto do estado atual:
// branch git, arquivos modificados, stack detectada e se existe CLAUDE.md.
// Objetivo: a pessoa "entra no projeto" sem ter que explicar nada ao agente.
// Autônomo — não depende de nenhum framework. Nunca trava (exit 0 em qualquer erro).

'use strict';

try {
  const path = require('path');
  const fs = require('fs');
  const { findProjectRoot, getGitInfo, detectTechStack, outputHook } = require('./utils.js');
  const { updateBannerLine } = require('./update-check.js');

  // Banner de defasagem do harness (independe do projeto) — cache-based, nao-bloqueante, fail-soft.
  const claudeHome = path.resolve(__dirname, '..', '..');
  const banner = updateBannerLine(claudeHome);

  const cwd = process.env.CLAUDE_PROJECT_DIR || process.cwd();
  const root = findProjectRoot(cwd);
  if (!root) {
    if (banner) outputHook('SessionStart', null, banner);
    process.exit(0);
  }

  const git = getGitInfo(root);
  const stack = detectTechStack(root);
  const hasClaudeMd = fs.existsSync(path.join(root, 'CLAUDE.md'));

  const lines = ['<contexto-do-projeto>'];
  lines.push(`Pasta: ${path.basename(root)}`);
  lines.push(`Stack: ${stack}`);
  if (git.branch) lines.push(`Branch: ${git.branch}`);
  lines.push(`Arquivos modificados (git): ${git.dirtyCount}`);
  if (hasClaudeMd) lines.push('Há CLAUDE.md na raiz — leia antes de agir se ainda não leu.');
  lines.push('</contexto-do-projeto>');
  // banner do harness -> systemMessage (visivel ao USUARIO); contexto do projeto -> additionalContext (modelo)
  outputHook('SessionStart', lines.join('\n'), banner);
} catch {
  process.exit(0);
}
