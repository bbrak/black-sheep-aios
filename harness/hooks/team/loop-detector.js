#!/usr/bin/env node
// Hook: UserPromptSubmit
// Rede de segurança para sessões longas. Guarda as últimas mensagens da pessoa
// (por projeto, em pasta temporária) e, se as 3 últimas forem praticamente iguais,
// injeta um protocolo de "quebra de loop" — sinal de que o agente está travado
// repetindo a mesma coisa e a pessoa está tendo que repedir.
// Autônomo, sem estado de framework. Nunca trava (exit 0 em qualquer erro).

'use strict';

try {
  const fs = require('fs');
  const os = require('os');
  const path = require('path');
  const crypto = require('crypto');
  const { findProjectRoot, outputHook, readStdinJson } = require('./utils.js');

  const input = readStdinJson();
  let msg = input.prompt || input.message || input.content || '';
  if (typeof msg === 'object') msg = JSON.stringify(msg);
  if (!msg || msg.length < 5) process.exit(0);

  // Normaliza para comparar intenção, não pontuação
  const norm = msg.toLowerCase().replace(/\s+/g, ' ').trim().slice(0, 300);

  const cwd = process.env.CLAUDE_PROJECT_DIR || process.cwd();
  const root = findProjectRoot(cwd) || cwd;
  const key = crypto.createHash('md5').update(root).digest('hex').slice(0, 12);
  const statePath = path.join(os.tmpdir(), `claude-loop-${key}.json`);

  let turns = [];
  try { turns = JSON.parse(fs.readFileSync(statePath, 'utf-8')); } catch { /* fresh */ }
  turns.push({ h: norm, ts: Date.now() });
  if (turns.length > 6) turns = turns.slice(-6);
  try { fs.writeFileSync(statePath, JSON.stringify(turns), 'utf-8'); } catch { /* silent */ }

  const N = 3;
  if (turns.length < N) process.exit(0);
  const recent = turns.slice(-N);
  const allSame = recent.every(t => t.h === recent[0].h);
  if (!allSame) process.exit(0);

  const elapsed = Math.round((recent[N - 1].ts - recent[0].ts) / 1000);
  const lines = [
    '<possível-loop>',
    `A pessoa repetiu essencialmente o mesmo pedido ${N} vezes (${elapsed}s). Provável loop: a abordagem atual não está resolvendo.`,
    'Protocolo de quebra de loop:',
    '  1. Pare a abordagem atual — não repita a mesma ação.',
    '  2. Diga em uma frase por que ela não está funcionando (causa raiz).',
    '  3. Proponha um caminho diferente OU peça à pessoa a informação que falta.',
    '  4. Se o bloqueio for externo (credencial, acesso, decisão), diga isso claramente.',
    '</possível-loop>'
  ];
  outputHook('UserPromptSubmit', lines.join('\n'));
} catch {
  process.exit(0);
}
