#!/usr/bin/env node
// Black Sheep AIOS — renderiza templates do harness para o destino final.
// Usado pelos DOIS instaladores (install.ps1 e install.sh). Node puro, zero deps.
//
// Uso:
//   node render-settings.js <template> <saida> --claude-home <dir> --platform <windows|mac>
//                           [--name "..."] [--role "..."] [--focus "..."]
//
// Comportamento:
//   *.json  → substitui tokens, remove "_comment", no Windows remove o hook "rtk hook claude"
//             (RTK no Windows nativo opera em modo CLAUDE.md via @RTK.md), valida com JSON.parse.
//   demais  → substituição simples de tokens ({{USER_NAME}}, {{USER_ROLE}}, {{USER_FOCUS}},
//             {{CLAUDE_HOME}}, {{PYTHON}}).
'use strict';

const fs = require('fs');
const path = require('path');

function fail(msg) { console.error('[render-settings] ERRO: ' + msg); process.exit(1); }

const args = process.argv.slice(2);
if (args.length < 2) fail('uso: node render-settings.js <template> <saida> --claude-home <dir> --platform <windows|mac> [--name --role --focus]');

const templatePath = args[0];
const outPath = args[1];

function opt(flag, dflt) {
  const i = args.indexOf(flag);
  return i !== -1 && args[i + 1] !== undefined ? args[i + 1] : dflt;
}

const platform = opt('--platform', process.platform === 'win32' ? 'windows' : 'mac');
if (platform !== 'windows' && platform !== 'mac') fail('--platform deve ser windows ou mac');

let claudeHome = opt('--claude-home', '');
if (!claudeHome) fail('--claude-home e obrigatorio');
claudeHome = path.resolve(claudeHome).replace(/\\/g, '/');

// Identidade: flags tem precedencia; senao o profile.json cacheado (.bsaios/profile.json), para
// re-renderizar o CLAUDE.md num update sem re-perguntar; senao vazio (o guarda abaixo recusa).
const profilePath = opt('--profile', '');
let profile = {};
if (profilePath) { try { profile = JSON.parse(fs.readFileSync(profilePath, 'utf-8')); } catch { profile = {}; } }
const identity = {
  '{{USER_NAME}}': opt('--name', profile.name || ''),
  '{{USER_ROLE}}': opt('--role', profile.role || ''),
  '{{USER_FOCUS}}': opt('--focus', profile.focus || '')
};

let text;
try { text = fs.readFileSync(templatePath, 'utf-8'); }
catch (e) { fail('nao consegui ler o template: ' + templatePath); }

// Mata o bug do <SEU NOME>: se o template referencia identidade, ela precisa existir e nao ser um
// placeholder <...>. Sem isso, RECUSA escrever (nunca renderiza um CLAUDE.md com identidade quebrada).
const isPlaceholder = v => !String(v).trim() || /<[^>]*>/.test(String(v));
for (const [tok, val] of Object.entries(identity)) {
  if (text.includes(tok) && isPlaceholder(val)) {
    fail('identidade ausente ou placeholder para ' + tok + ' — recuso escrever ' + path.basename(outPath) +
      '. Forneca --name/--role/--focus ou um profile.json valido em ~/.claude/.bsaios/.');
  }
}

const tokens = Object.assign({
  '{{CLAUDE_HOME}}': claudeHome,
  '{{PYTHON}}': platform === 'windows' ? 'python' : 'python3'
}, identity);

for (const [k, v] of Object.entries(tokens)) text = text.split(k).join(v);

if (/\{\{[A-Z_]+\}\}/.test(text)) fail('sobrou token nao substituido em ' + templatePath + ': ' + text.match(/\{\{[A-Z_]+\}\}/)[0]);

if (templatePath.toLowerCase().endsWith('.json')) {
  let cfg;
  try { cfg = JSON.parse(text); } catch (e) { fail('template JSON invalido apos substituicao: ' + e.message); }
  delete cfg._comment;

  if (platform === 'windows' && cfg.hooks) {
    for (const event of Object.keys(cfg.hooks)) {
      cfg.hooks[event] = cfg.hooks[event]
        .map(group => {
          if (group && Array.isArray(group.hooks)) {
            group.hooks = group.hooks.filter(h => (h.command || '') !== 'rtk hook claude');
          }
          return group;
        })
        .filter(group => !group.hooks || group.hooks.length > 0);
      if (cfg.hooks[event].length === 0) delete cfg.hooks[event];
    }
  }

  text = JSON.stringify(cfg, null, 2) + '\n';
  JSON.parse(text); // sanity final
}

fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, text, 'utf-8');
console.log('[render-settings] OK -> ' + outPath + ' (platform=' + platform + ')');
