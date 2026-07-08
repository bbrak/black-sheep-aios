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

const tokens = {
  '{{CLAUDE_HOME}}': claudeHome,
  '{{PYTHON}}': platform === 'windows' ? 'python' : 'python3',
  '{{USER_NAME}}': opt('--name', '<SEU NOME>'),
  '{{USER_ROLE}}': opt('--role', '<SUA FUNCAO>'),
  '{{USER_FOCUS}}': opt('--focus', '<ex.: automacoes com IA, marketing, desenvolvimento web>')
};

let text;
try { text = fs.readFileSync(templatePath, 'utf-8'); }
catch (e) { fail('nao consegui ler o template: ' + templatePath); }

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
