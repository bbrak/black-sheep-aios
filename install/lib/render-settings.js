#!/usr/bin/env node
// Black Sheep AIOS — renderiza templates do harness para o destino final.
// Usado pelos DOIS instaladores (install.ps1 e install.sh). Node puro, zero deps.
//
// Uso:
//   node render-settings.js <template> <saida> --claude-home <dir> --platform <windows|mac>
//                           [--name "..."] [--role "..."] [--focus "..."]
//
// Comportamento (nunca perde o que o usuario ja tinha):
//   *.json  → substitui tokens, remove "_comment", no Windows remove o hook "rtk hook claude".
//             Se a SAIDA ja existe, faz DEEP-MERGE preservando o config do usuario:
//               permissions.allow/deny/ask → uniao + dedupe   |  mcpServers → merge por chave
//               enabledPlugins / extraKnownMarketplaces / env → merge por chave (harness vence)
//               hooks → por evento, dedupe por (matcher+command) — nao duplica em reinstalacao
//               defaultMode / statusLine → PRESERVA o do usuario se ja existir
//   *.md    → bloco gerenciado. O template delimita a parte do harness com
//             <!-- BSAIOS:MANAGED:START ... --> ... <!-- BSAIOS:MANAGED:END -->.
//               saida inexistente        → escreve o template inteiro
//               saida com marcadores      → troca SO o bloco; preserva identidade e customizacoes
//               saida sem marcadores      → preserva o arquivo do usuario 100% e anexa o bloco
//             (sem marcadores no template → comportamento legado: sobrescreve)
//   demais  → substituicao simples de tokens e escrita.
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

// ---------------------------------------------------------------- helpers de merge (JSON)
function isObj(x) { return x && typeof x === 'object' && !Array.isArray(x); }

function unionArr(a, b) {
  const out = [];
  const seen = new Set();
  for (const item of [...(a || []), ...(b || [])]) {
    const key = typeof item === 'string' ? item : JSON.stringify(item);
    if (!seen.has(key)) { seen.add(key); out.push(item); }
  }
  return out;
}

function hookKey(group, hook) { return (group.matcher || '') + '::' + (hook.command || ''); }

function mergeHooks(base = {}, incoming = {}) {
  const out = {};
  for (const ev of new Set([...Object.keys(base), ...Object.keys(incoming)])) {
    const groups = (base[ev] || []).map(g => ({ ...g, hooks: [...(g.hooks || [])] }));
    const seen = new Set();
    for (const g of groups) for (const h of g.hooks) seen.add(hookKey(g, h));
    for (const g of (incoming[ev] || [])) {
      const fresh = (g.hooks || []).filter(h => !seen.has(hookKey(g, h)));
      if (fresh.length) { groups.push({ ...g, hooks: fresh }); fresh.forEach(h => seen.add(hookKey(g, h))); }
    }
    if (groups.length) out[ev] = groups;
  }
  return out;
}

// base = config existente do usuario; inc = template do harness. Preserva o usuario, garante o harness.
function mergeSettings(base, inc) {
  const out = { ...base };

  out.env = { ...(base.env || {}), ...(inc.env || {}) };

  if (base.permissions || inc.permissions) {
    const bp = base.permissions || {}, ip = inc.permissions || {};
    out.permissions = { ...bp };
    if (bp.allow || ip.allow) out.permissions.allow = unionArr(bp.allow, ip.allow);
    if (bp.deny || ip.deny) out.permissions.deny = unionArr(bp.deny, ip.deny);
    if (bp.ask || ip.ask) out.permissions.ask = unionArr(bp.ask, ip.ask);
    out.permissions.defaultMode = bp.defaultMode !== undefined ? bp.defaultMode : ip.defaultMode; // preserva usuario
  }

  if (base.hooks || inc.hooks) out.hooks = mergeHooks(base.hooks, inc.hooks);

  for (const k of ['enabledPlugins', 'extraKnownMarketplaces', 'mcpServers']) {
    if (base[k] || inc[k]) out[k] = { ...(base[k] || {}), ...(inc[k] || {}) };
  }

  out.statusLine = base.statusLine !== undefined ? base.statusLine : inc.statusLine; // preserva usuario

  for (const k of Object.keys(inc)) if (!(k in out)) out[k] = inc[k];
  return out;
}

function writeOut(content, note) {
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, content, 'utf-8');
  console.log('[render-settings] OK -> ' + outPath + ' (platform=' + platform + (note ? '; ' + note : '') + ')');
}

// ---------------------------------------------------------------- JSON
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

  let note = 'novo';
  if (fs.existsSync(outPath)) {
    let existing;
    try { existing = JSON.parse(fs.readFileSync(outPath, 'utf-8')); }
    catch (e) { fail('settings.json existente e JSON invalido (' + outPath + '): ' + e.message + ' — corrija ou remova antes de reinstalar'); }
    if (isObj(existing)) { cfg = mergeSettings(existing, cfg); note = 'merge com config existente (preservado)'; }
  }

  const outText = JSON.stringify(cfg, null, 2) + '\n';
  JSON.parse(outText); // sanity final
  writeOut(outText, note);
  process.exit(0);
}

// ---------------------------------------------------------------- Markdown (bloco gerenciado)
const BLOCK_RE = /<!--\s*BSAIOS:MANAGED:START[\s\S]*?BSAIOS:MANAGED:END\s*-->/;

if (BLOCK_RE.test(text)) {
  const newBlock = text.match(BLOCK_RE)[0];
  if (!fs.existsSync(outPath)) {
    writeOut(text, 'novo (identidade + bloco gerenciado)');
  } else {
    const existing = fs.readFileSync(outPath, 'utf-8');
    if (BLOCK_RE.test(existing)) {
      writeOut(existing.replace(BLOCK_RE, newBlock), 'bloco gerenciado atualizado; resto do arquivo preservado');
    } else {
      writeOut(existing.replace(/\s*$/, '') + '\n\n' + newBlock + '\n', 'CLAUDE.md existente preservado 100%; bloco bsaios anexado ao final');
    }
  }
  process.exit(0);
}

// sem marcadores no template → comportamento legado (sobrescreve)
writeOut(text, 'sem marcadores no template — escrito integral');
