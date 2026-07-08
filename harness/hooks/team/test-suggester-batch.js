#!/usr/bin/env node
// Harness de teste em lote do skill-suggester.
// Roda a MESMA logica de pontuacao do hook contra uma lista de frases, usando
// o indice real de skills (.skill-index.json). Nao chama IA. Uso:
//
//   node test-suggester-batch.js <indice.json> <frases.txt> [--min N]
//
// - <indice.json>: caminho do .skill-index.json (gerado pelo skill-suggester).
// - <frases.txt> : uma frase por linha.
// - --min N      : override do SCORE_MINIMO (default 2).
//
// Saida: para cada frase, as skills com score >= minimo (ou "—" se nenhuma),
// e no fim um resumo. Serve para calibrar SCORE_MINIMO e descricoes de skills.

'use strict';

const fs = require('fs');

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

const args = process.argv.slice(2);
const idxPath = args[0];
const phrasesPath = args[1];
const minIdx = args.indexOf('--min');
const SCORE_MINIMO = minIdx !== -1 ? Number(args[minIdx + 1]) : 2;

if (!idxPath || !phrasesPath) {
  console.error('uso: node test-suggester-batch.js <indice.json> <frases.txt> [--min N]');
  process.exit(1);
}

const index = JSON.parse(fs.readFileSync(idxPath, 'utf-8'));
let skills = index.skills || [];

// Se o indice for de versao antiga (sem nameTokens), recomputa a partir de name/desc.
skills = skills.map(function (s) {
  const nameTokens = s.nameTokens && s.nameTokens.length ? s.nameTokens : tokenize(s.name || '', 3);
  const triggers = s.triggers && s.triggers.length ? s.triggers : tokenize(s.desc || s.description || '', 4);
  return { name: s.name, desc: s.desc || s.description || '', nameTokens: nameTokens, triggers: triggers };
});

const phrases = fs.readFileSync(phrasesPath, 'utf-8').split(/\r?\n/).map(function (l) { return l.trim(); }).filter(Boolean);

function scorePhrase(phrase) {
  const m = ' ' + deaccent(phrase.toLowerCase()).replace(/\s+/g, ' ').trim() + ' ';
  const scored = [];
  for (const s of skills) {
    let score = 0;
    for (const t of s.nameTokens) if (m.indexOf(' ' + t) !== -1) score += 2;
    for (const t of s.triggers) if (m.indexOf(' ' + t) !== -1) score += 1;
    if (score > 0) scored.push({ name: s.name, score: score });
  }
  scored.sort(function (a, b) { return b.score - a.score; });
  return scored;
}

let comSugestao = 0;
const results = [];
for (const p of phrases) {
  const scored = scorePhrase(p);
  const hits = scored.filter(function (s) { return s.score >= SCORE_MINIMO; }).slice(0, 2);
  if (hits.length) comSugestao++;
  results.push({ phrase: p, hits: hits, top: scored.slice(0, 3) });
}

console.log('== TESTE EM LOTE — SCORE_MINIMO=' + SCORE_MINIMO + ' — skills no indice: ' + skills.length + ' ==\n');
for (const r of results) {
  const sug = r.hits.length
    ? r.hits.map(function (h) { return h.name + '(' + h.score + ')'; }).join(', ')
    : '—  [top: ' + (r.top.map(function (t) { return t.name + '=' + t.score; }).join(', ') || 'nada') + ']';
  console.log('• ' + r.phrase.slice(0, 90));
  console.log('    -> ' + sug + '\n');
}
console.log('== RESUMO: ' + comSugestao + '/' + phrases.length + ' frases geraram sugestao ('
  + Math.round(100 * comSugestao / phrases.length) + '%) ==');
