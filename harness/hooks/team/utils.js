#!/usr/bin/env node
// Utilitários compartilhados dos hooks do time.
// Node puro, zero dependências externas. Nunca lança — sempre retorna valor seguro.

'use strict';

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

/** Sobe na árvore procurando a raiz do projeto (primeiro diretório com .git). */
function findProjectRoot(startDir) {
  let dir = startDir || process.cwd();
  for (let i = 0; i < 25; i++) {
    if (fs.existsSync(path.join(dir, '.git'))) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return null;
}

function readFileSafe(p) {
  try { return fs.readFileSync(p, 'utf-8'); } catch { return null; }
}

/** Branch atual + nº de arquivos modificados. Silencioso se não houver git. */
function getGitInfo(root) {
  const info = { branch: null, dirtyCount: 0 };
  try {
    info.branch = execSync('git rev-parse --abbrev-ref HEAD', { cwd: root, stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim();
  } catch { /* sem git */ }
  try {
    const status = execSync('git status --porcelain', { cwd: root, stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim();
    info.dirtyCount = status ? status.split('\n').length : 0;
  } catch { /* silent */ }
  return info;
}

/** Detecta a stack por arquivos-marcador na raiz. Retorna string curta. */
function detectTechStack(root) {
  const marks = [];
  const has = (f) => fs.existsSync(path.join(root, f));
  if (has('package.json')) {
    marks.push('Node/JS');
    const pkg = readFileSafe(path.join(root, 'package.json')) || '';
    if (/"next"/.test(pkg)) marks.push('Next.js');
    if (/"react"/.test(pkg)) marks.push('React');
    if (/"typescript"/.test(pkg)) marks.push('TypeScript');
    if (/"vitest"|"jest"/.test(pkg)) marks.push('tests');
  }
  if (has('requirements.txt') || has('pyproject.toml')) marks.push('Python');
  if (has('go.mod')) marks.push('Go');
  if (has('Cargo.toml')) marks.push('Rust');
  if (has('supabase')) marks.push('Supabase');
  return marks.length ? marks.join(', ') : 'indefinida';
}

/** Emite o JSON de hook do Claude Code. `additionalContext` vai para o modelo;
 *  `systemMessage` (opcional) e mostrado ao USUARIO no terminal. */
function outputHook(eventName, additionalContext, systemMessage) {
  const out = {};
  if (systemMessage) out.systemMessage = systemMessage;
  if (additionalContext) out.hookSpecificOutput = { hookEventName: eventName, additionalContext };
  if (!out.systemMessage && !out.hookSpecificOutput) return;
  process.stdout.write(JSON.stringify(out));
}

/** Lê o stdin do hook (JSON do Claude Code) e devolve objeto — {} se falhar. */
function readStdinJson() {
  try {
    if (process.stdin.isTTY) return {};
    const raw = fs.readFileSync(0, 'utf-8');
    return JSON.parse(raw);
  } catch { return {}; }
}

module.exports = {
  findProjectRoot, readFileSafe, getGitInfo,
  detectTechStack, outputHook, readStdinJson
};
