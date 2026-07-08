#!/usr/bin/env node
// Status line do Black Sheep AIOS — cross-platform (Windows + macOS), Node puro.
// Mostra: pasta  branch  modelo  [██████░░░░] 60%
// Substitui a versão bash (que dependia de jq + python3, ausentes no Windows nativo).
'use strict';

const { execFileSync } = require('child_process');
const path = require('path');

let input = '';
try { input = require('fs').readFileSync(0, 'utf-8'); } catch (e) { /* sem stdin */ }

let d = {};
try { d = JSON.parse(input); } catch (e) { /* segue com defaults */ }

const cwd = (d.workspace && d.workspace.current_dir) || d.cwd || '';
const model = (d.model && d.model.display_name) || '';
const usedPct = d.context_window && d.context_window.used_percentage;

const folder = cwd ? path.basename(cwd) : '';

let branch = '';
if (cwd) {
  try {
    branch = execFileSync('git', ['-C', cwd, '--no-optional-locks', 'symbolic-ref', '--short', 'HEAD'],
      { encoding: 'utf-8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 2000 }).trim();
  } catch (e) { /* fora de repo git */ }
}

let bar = '';
if (usedPct !== undefined && usedPct !== null && usedPct !== '') {
  const pct = Number(usedPct);
  if (!Number.isNaN(pct)) {
    const filled = Math.max(0, Math.min(10, Math.round(pct / 10)));
    bar = '[' + '█'.repeat(filled) + '░'.repeat(10 - filled) + '] ' + Math.round(pct) + '%';
  }
}

let out = folder;
if (branch) out += '  ' + branch;
if (model) out += '  ' + model;
if (bar) out += '  ' + bar;

process.stdout.write(out);
