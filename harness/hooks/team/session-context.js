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

  const cwd = process.env.CLAUDE_PROJECT_DIR || process.cwd();
  const root = findProjectRoot(cwd);
  if (!root) process.exit(0);

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

  outputHook('SessionStart', lines.join('\n'));
} catch {
  process.exit(0);
}
