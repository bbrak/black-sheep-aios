#!/usr/bin/env node
// Hook: UserPromptSubmit
// Descobre as skills instaladas EM TEMPO REAL (usuario + projeto + plugins),
// le a description de cada SKILL.md e, se o assunto da mensagem casar, injeta
// um lembrete curto sugerindo a skill certa. Zero IA / zero token (codigo local).
//
// Pontuacao: palavra do NOME da skill = +2; palavra da DESCRICAO = +1.
// Casamento por PALAVRA INTEIRA (aceita plural em 's') e acentos ignorados.
//
// ALLOWLIST (recomendado p/ quem tem MUITAS skills):
//   crie ~/.claude/hooks/team/suggest-allowlist.txt com um nome de skill por linha.
//   Se existir e nao estiver vazio, SO essas skills entram nas sugestoes.
//   Sem allowlist, considera todas (pode gerar ruido se voce tiver centenas).
//
// TESTE: node skill-suggester.js --debug --prompt "montar uns slides"
// AJUSTES: MAX_SUGESTOES / SCORE_MINIMO / COOLDOWN_H. Nunca trava (exit 0).

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { findProjectRoot, outputHook, readStdinJson } = require('./utils.js');

const INDEX_VER = 4;
const MAX_SUGESTOES = 2;
const SCORE_MINIMO = 2;
const COOLDOWN_H = 6;

const STOP = new Set(('a o e de da do das dos para por com sem que uma um the and for use when this that with your you into from will can any '
  + 'skill skills use used using create creating creates file files user users request requests task tasks help '
  + 'documento documentos criar edita editar usar quando esse essa este esta como qualquer sobre tambem').split(/\s+/));

function deaccent(s) { return s.normalize('NFD').replace(/[̀-ͯ]/g, ''); }

function tokenize(text, minLen) {
  return deaccent(String(text).toLowerCase())
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter(function (w) { return w.length >= minLen && !STOP.has(w); });
}

// casa palavra inteira: ' token' seguido de espaco ou 's' (plural). Evita icon->icone.
function hasWord(m, t) {
  let from = 0;
  while (true) {
    const i = m.indexOf(' ' + t, from);
    if (i === -1) return false;
    const after = m[i + 1 + t.length];
    if (after === ' ' || after === 's') return true;
    from = i + 1;
  }
}

function argValue(flag) {
  const i = process.argv.indexOf(flag);
  return (i !== -1 && process.argv[i + 1]) ? process.argv[i + 1] : null;
}

function main() {
  const DEBUG = process.argv.indexOf('--debug') !== -1;
  const promptArg = argValue('--prompt');

  let msg = promptArg;
  if (!msg) {
    const input = readStdinJson();
    msg = input.prompt || input.message || input.content || '';
    if (typeof msg === 'object') msg = JSON.stringify(msg);
  }
  if (!msg || msg.length < 5) { if (DEBUG) console.error('[debug] mensagem vazia/curta'); return; }
  const m = ' ' + deaccent(msg.toLowerCase()).replace(/\s+/g, ' ').trim() + ' ';

  const HOME = process.env.HOME || process.env.USERPROFILE || os.homedir();
  const cwd = process.env.CLAUDE_PROJECT_DIR || process.cwd();
  const projRoot = findProjectRoot(cwd);
  const teamDir = path.join(HOME, '.claude', 'hooks', 'team');

  const ROOTS = [
    { dir: path.join(HOME, '.claude', 'skills'), depth: 2 },
    { dir: path.join(HOME, '.claude', 'plugins'), depth: 6 }
  ];
  if (projRoot) ROOTS.push({ dir: path.join(projRoot, '.claude', 'skills'), depth: 2 });

  const INDEX_PATH = path.join(teamDir, '.skill-index.json');
  const COOLDOWN_PATH = path.join(os.tmpdir(), 'claude-skill-cooldown.json');

  // allowlist opcional
  let allow = null;
  try {
    const raw = fs.readFileSync(path.join(teamDir, 'suggest-allowlist.txt'), 'utf-8');
    const names = raw.split(/\r?\n/).map(function (l) { return l.trim(); }).filter(function (l) { return l && l[0] !== '#'; });
    if (names.length) allow = new Set(names.map(function (n) { return n.toLowerCase(); }));
  } catch (e) { allow = null; }

  let index = null;
  try { index = JSON.parse(fs.readFileSync(INDEX_PATH, 'utf-8')); } catch (e) { index = null; }
  if (!indexFresh(index, ROOTS)) {
    index = { ver: INDEX_VER, builtAt: Date.now(), sig: rootsSignature(ROOTS), skills: buildSkills(ROOTS) };
    try { fs.writeFileSync(INDEX_PATH, JSON.stringify(index), 'utf-8'); } catch (e) {}
  }

  let pool = index.skills;
  if (allow) pool = pool.filter(function (s) { return allow.has((s.name || '').toLowerCase()); });

  if (DEBUG) {
    console.error('[debug] skills no indice: ' + index.skills.length + (allow ? ' | allowlist ativa: ' + pool.length : ' | sem allowlist'));
  }

  const scored = [];
  const seen = new Set();
  for (const s of pool) {
    if (seen.has(s.name)) continue;
    seen.add(s.name);
    let score = 0;
    for (const t of (s.nameTokens || [])) if (hasWord(m, t)) score += 2;
    for (const t of (s.triggers || [])) if (hasWord(m, t)) score += 1;
    scored.push({ name: s.name, desc: s.desc, score: score });
  }
  scored.sort(function (a, b) { return b.score - a.score; });
  if (DEBUG) console.error('[debug] top: ' + scored.slice(0, 6).map(function (s) { return s.name + '=' + s.score; }).join(', ') + ' | min=' + SCORE_MINIMO);

  const hits = scored.filter(function (s) { return s.score >= SCORE_MINIMO; });
  if (hits.length === 0) { if (DEBUG) console.error('[debug] nenhuma atingiu o minimo'); return; }

  const filtered = applyCooldown(hits, COOLDOWN_PATH).slice(0, MAX_SUGESTOES);
  if (filtered.length === 0) { if (DEBUG) console.error('[debug] todas em cooldown'); return; }

  const lines = ['<sugestao-de-skill>'];
  for (const h of filtered) {
    const desc = h.desc ? (' - ' + h.desc.slice(0, 140)) : '';
    lines.push('Skill disponivel: "' + h.name + '"' + desc + '. Use se for pertinente; ignore se nao for.');
  }
  lines.push('</sugestao-de-skill>');
  outputHook('UserPromptSubmit', lines.join('\n'));
}

// ================= helpers =================

function applyCooldown(hits, cdPath) {
  let cd = {};
  try { cd = JSON.parse(fs.readFileSync(cdPath, 'utf-8')); } catch (e) { cd = {}; }
  const now = Date.now();
  const windowMs = COOLDOWN_H * 3600 * 1000;
  const out = [];
  for (const h of hits) {
    if (cd[h.name] && now - cd[h.name] < windowMs) continue;
    out.push(h); cd[h.name] = now;
  }
  try { fs.writeFileSync(cdPath, JSON.stringify(cd), 'utf-8'); } catch (e) {}
  return out;
}

function rootsSignature(roots) {
  const sig = {};
  for (const r of roots) { try { sig[r.dir] = fs.statSync(r.dir).mtimeMs; } catch (e) { sig[r.dir] = 0; } }
  return sig;
}

function indexFresh(idx, roots) {
  if (!idx || idx.ver !== INDEX_VER || !idx.builtAt || !idx.sig) return false;
  if (Date.now() - idx.builtAt > 24 * 3600 * 1000) return false;
  const now = rootsSignature(roots);
  const keys = Object.keys(now);
  return keys.length === Object.keys(idx.sig).length && keys.every(function (k) { return idx.sig[k] === now[k]; });
}

function buildSkills(roots) {
  const files = [];
  for (const r of roots) collectSkillMd(r.dir, r.depth, files, 0);
  const out = [];
  const seen = new Set();
  for (const f of files.slice(0, 500)) {
    const meta = parseFrontmatter(f);
    if (!meta.name || seen.has(meta.name)) continue;
    seen.add(meta.name);
    out.push({
      name: meta.name,
      desc: meta.description || '',
      nameTokens: tokenize(meta.name, 3),
      triggers: tokenize(meta.description || '', 4)
    });
  }
  return out;
}

function collectSkillMd(dir, maxDepth, acc, depth) {
  if (depth > maxDepth || acc.length > 500) return;
  let entries;
  try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch (e) { return; }
  for (const e of entries) {
    if (e.name === 'node_modules' || e.name === '.git') continue;
    const full = path.join(dir, e.name);
    if (e.isFile() && e.name === 'SKILL.md') acc.push(full);
    else if (e.isDirectory()) collectSkillMd(full, maxDepth, acc, depth + 1);
  }
}

// Parser de frontmatter que ENTENDE block scalars (description: >- ou |).
function parseFrontmatter(file) {
  let raw;
  try { raw = fs.readFileSync(file, 'utf-8'); } catch (e) { return {}; }
  const fmMatch = raw.match(/^---\s*\r?\n([\s\S]*?)\r?\n---/);
  if (!fmMatch) return {};
  const lines = fmMatch[1].split(/\r?\n/);
  const fields = {};
  let curKey = null, buf = [];
  for (const line of lines) {
    const km = /^\s/.test(line) ? null : line.match(/^([A-Za-z_][\w-]*):\s?(.*)$/);
    if (km) {
      if (curKey) fields[curKey] = buf.join(' ').trim();
      curKey = km[1]; buf = [];
      const v = km[2];
      if (!/^[|>][-+0-9]*\s*$/.test(v)) buf.push(v); // se nao for indicador de block scalar, guarda o valor inline
    } else if (curKey) {
      buf.push(line.trim());
    }
  }
  if (curKey) fields[curKey] = buf.join(' ').trim();
  const clean = function (v) { return v ? v.trim().replace(/^["']|["']$/g, '').replace(/\s+/g, ' ') : ''; };
  return { name: clean(fields.name), description: clean(fields.description) };
}

try { main(); } catch (e) { process.exit(0); }
