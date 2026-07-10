#!/usr/bin/env node
// Black Sheep AIOS — health check do harness (sinal de saude leve, read-only).
// Reusado por: instaladores (pos-install), comando de update (verify pos-swap) e /bsaios-rollback.
// Node puro, zero deps, cross-platform. Nunca escreve — so le e reporta.
//
// Uso:
//   node verify-harness.js --claude-home <dir> [--quiet]
//
// Verifica (o que NAO pode quebrar em silencio no time):
//   1. settings.json da JSON.parse e habilita bsaios-core@bsaios (senao GateGuard nem carrega).
//   2. Os hooks do GateGuard (pre:bash:dispatcher + pre:edit-write:gateguard-fact-force) existem no
//      hooks.json do plugin instalado — "GateGuard continua vivo".
//   3. Os 3 plugins claude-plugins-official habilitados estao declarados no settings.
// Exit 0 = saudavel; exit 1 = GateGuard/pluginz ausente (critico).
'use strict';

const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
function opt(flag, dflt) { const i = args.indexOf(flag); return i !== -1 && args[i + 1] !== undefined ? args[i + 1] : dflt; }
const QUIET = args.includes('--quiet');

let claudeHome = opt('--claude-home', '');
if (!claudeHome) { console.error('[verify-harness] ERRO: --claude-home e obrigatorio'); process.exit(2); }
claudeHome = path.resolve(claudeHome);

const GATEGUARD_HOOK_IDS = ['pre:bash:dispatcher', 'pre:edit-write:gateguard-fact-force'];
const OFFICIAL_PLUGINS = [
  'claude-md-management@claude-plugins-official',
  'claude-code-setup@claude-plugins-official',
  'frontend-design@claude-plugins-official'
];

const problems = [];
const oks = [];

// 1 + 3. settings.json
const settingsPath = path.join(claudeHome, 'settings.json');
let settings = null;
try { settings = JSON.parse(fs.readFileSync(settingsPath, 'utf-8')); }
catch (e) { problems.push('settings.json ausente ou invalido (' + e.message + ')'); }

if (settings) {
  const enabled = settings.enabledPlugins || {};
  if (enabled['bsaios-core@bsaios'] === true) oks.push('bsaios-core@bsaios habilitado');
  else problems.push('bsaios-core@bsaios NAO habilitado em settings.enabledPlugins (GateGuard nao carrega)');

  const missingOfficial = OFFICIAL_PLUGINS.filter(p => enabled[p] !== true);
  if (missingOfficial.length === 0) oks.push('3 plugins claude-plugins-official habilitados');
  else problems.push('plugins oficiais nao habilitados: ' + missingOfficial.join(', '));
}

// 2. GateGuard vivo — procura o hooks.json do plugin instalado
const hookCandidates = [
  path.join(claudeHome, 'plugins', 'bsaios-marketplace', 'bsaios-core', 'hooks', 'hooks.json'),
  ...cacheHooksPaths(claudeHome)
];
const hooksFile = hookCandidates.find(p => fs.existsSync(p));
if (!hooksFile) {
  problems.push('hooks.json do bsaios-core nao encontrado (' + hookCandidates[0] + ')');
} else {
  let raw = '';
  try { raw = fs.readFileSync(hooksFile, 'utf-8'); } catch { /* noop */ }
  const missingHooks = GATEGUARD_HOOK_IDS.filter(id => !raw.includes('"' + id + '"'));
  if (missingHooks.length === 0) oks.push('GateGuard vivo (' + GATEGUARD_HOOK_IDS.join(' + ') + ')');
  else problems.push('hooks do GateGuard ausentes no plugin: ' + missingHooks.join(', '));
}

if (!QUIET) {
  oks.forEach(o => console.log('  [ok] ' + o));
  problems.forEach(p => console.error('  [!!] ' + p));
}

if (problems.length) { console.error('[verify-harness] FALHA — ' + problems.length + ' problema(s).'); process.exit(1); }
console.log('[verify-harness] OK — harness saudavel.');
process.exit(0);

function cacheHooksPaths(home) {
  const base = path.join(home, 'plugins', 'cache', 'bsaios', 'bsaios-core');
  try {
    return fs.readdirSync(base, { withFileTypes: true })
      .filter(d => d.isDirectory())
      .map(d => path.join(base, d.name, 'hooks', 'hooks.json'));
  } catch { return []; }
}
