#!/usr/bin/env node
// Liga o skill-suggester no ~/.claude/settings.json de forma segura e idempotente.
// - Faz backup (settings.json.bak-<timestamp>) antes de tocar em nada.
// - Não remove nenhum hook existente; só ACRESCENTA o skill-suggester em UserPromptSubmit.
// - Se já estiver ligado, não faz nada.
// Uso:  node _wire-into-settings.js
// Para desligar depois, remova a entrada 'skill-suggester.js' do settings.json (ou rode com --off).

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');

const OFF = process.argv.includes('--off');
const HOME = process.env.USERPROFILE || process.env.HOME || os.homedir();
const SETTINGS = path.join(HOME, '.claude', 'settings.json');
const CMD = 'node ' + path.join(HOME, '.claude', 'hooks', 'team', 'skill-suggester.js').replace(/\\/g, '/');

let raw;
try { raw = fs.readFileSync(SETTINGS, 'utf-8'); }
catch (e) { console.error('Nao achei ' + SETTINGS + ' — abra o Claude Code ao menos uma vez.'); process.exit(1); }

let cfg;
try { cfg = JSON.parse(raw); }
catch (e) { console.error('settings.json nao e JSON valido. Nao vou tocar nele.'); process.exit(1); }

const bak = SETTINGS + '.bak-' + new Date().toISOString().replace(/[:.]/g, '-');
fs.writeFileSync(bak, raw, 'utf-8');

cfg.hooks = cfg.hooks || {};
cfg.hooks.UserPromptSubmit = Array.isArray(cfg.hooks.UserPromptSubmit) ? cfg.hooks.UserPromptSubmit : [];

const has = JSON.stringify(cfg.hooks.UserPromptSubmit).includes('skill-suggester.js');

if (OFF) {
  cfg.hooks.UserPromptSubmit = cfg.hooks.UserPromptSubmit
    .map(function (g) {
      if (g && Array.isArray(g.hooks)) g.hooks = g.hooks.filter(function (h) { return !(h.command || '').includes('skill-suggester.js'); });
      return g;
    })
    .filter(function (g) { return !g.hooks || g.hooks.length > 0; });
  fs.writeFileSync(SETTINGS, JSON.stringify(cfg, null, 2), 'utf-8');
  console.log('skill-suggester DESLIGADO. Backup: ' + bak);
  process.exit(0);
}

if (has) { console.log('Ja estava ligado — nada a fazer. (backup salvo em ' + bak + ')'); process.exit(0); }

cfg.hooks.UserPromptSubmit.push({ hooks: [{ type: 'command', command: CMD, timeout: 5000 }] });
fs.writeFileSync(SETTINGS, JSON.stringify(cfg, null, 2), 'utf-8');
console.log('skill-suggester LIGADO em UserPromptSubmit.');
console.log('Backup do settings anterior: ' + bak);
console.log('Reinicie o Claude Code para valer.');
