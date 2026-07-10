#!/usr/bin/env node
// Black Sheep AIOS — gate de higiene de release (roda no CI; exit 1 se algo escapou).
// Impede exatamente o que ja aconteceu: shipar sem atualizar CHANGELOG/versao/contagens.
//
//   R1  A versao do manifest tem uma secao `## [versao]` no CHANGELOG.
//       (bump sem promover o changelog -> falha)
//   R2  As contagens do README batem com o filesystem (skills/user-skills/agents/rules).
//       (adicionou/removeu conteudo e esqueceu de atualizar o README -> falha, com o numero certo)
//   R3  Se o diff base..HEAD tocou conteudo do harness (skills/agents/hooks/rules/commands) mas
//       NAO tocou CHANGELOG.md -> falha ("mudou conteudo sem registrar o que mudou").
//
// R2 e check-only de proposito: as contagens do README sao compositivas (53 = 49+4, 44 = 21+15+8),
// entao a correcao e humana (o gate diz o numero, voce reconcilia total + detalhamento). Os
// arquivos-maquina (versao, "NN skills" em plugin/marketplace/VERSION) ficam com sync-manifest.js.
//
// Uso: node install/lib/check-release.js [--base <ref>]   (default: origin/main)
'use strict';

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const REPO = path.resolve(__dirname, '..', '..');
const base = argVal('--base') || 'origin/main';
const problems = [];

// ---------------------------------------------------------------- R1: versao ↔ CHANGELOG
const manifest = readJson(path.join(REPO, 'install', 'manifest.json'));
const version = String(manifest.version || '');
const changelog = read(path.join(REPO, 'CHANGELOG.md'));
if (!version) {
  problems.push('install/manifest.json sem "version".');
} else {
  const hi = changelog.search(new RegExp('^## \\[' + escapeRe(version) + '\\]', 'm'));
  if (hi === -1) {
    problems.push(`CHANGELOG.md nao tem a secao "## [${version}]" — a versao subiu sem promover o changelog (rode: node install/lib/release.js <patch|minor|major>).`);
  } else {
    const after = changelog.slice(hi).replace(/^[^\n]*\n/, ''); // tira a linha do header
    const nb = after.search(/\n## \[/);
    const secBody = (nb === -1 ? after : after.slice(0, nb)).trim();
    if (!secBody) problems.push(`CHANGELOG.md tem "## [${version}]" mas SEM corpo — descreva o que mudou (nao promova uma secao vazia).`);
  }
}

// ---------------------------------------------------------------- R2: contagens do README
const readme = read(path.join(REPO, 'README.md'));
const counts = {
  skills: countDirs('plugins/bsaios-core/skills'),
  userSkills: countDirs('harness/skills'),
  agents: countFiles('harness/agents', '.md'),
  rules: countFiles('harness/rules', '.md')
};
// cada alvo: um rotulo, o valor real, e todos os numeros que o README afirma para ele.
checkReadme(/(\d+) skills (?:curadas|\+ GateGuard)/g, counts.skills, 'skills (plugin)');
checkReadme(/Skills de usuário \((\d+)\)/g, counts.userSkills, 'skills de usuário');
checkReadme(/Agents \((\d+)\)/g, counts.agents, 'agents');
checkReadme(/Rules \((\d+)\)/g, counts.rules, 'rules');

// ---------------------------------------------------------------- R3: conteudo mudou ↔ CHANGELOG
const changed = diffNames(base);
if (changed === null) {
  console.error('[check-release] AVISO: nao consegui calcular o diff — R3 (conteudo↔changelog) foi pulado.');
} else {
  // Tudo que e ENTREGUE ao ~/.claude do time: o plugin vendorizado inteiro (skills, hooks do
  // GateGuard, rules, scripts...) e o harness inteiro (agents, rules, hooks, wrappers, templates...).
  const CONTENT = [/^plugins\//, /^harness\//];
  const touchedContent = changed.filter(f => CONTENT.some(re => re.test(f)));
  if (touchedContent.length && !changed.includes('CHANGELOG.md')) {
    problems.push('conteudo entregue ao time (plugins/ ou harness/) mudou mas CHANGELOG.md nao foi tocado no mesmo diff — registre em "## [Não lançado]". Exemplos: ' + touchedContent.slice(0, 5).join(', '));
  }
}

// ---------------------------------------------------------------- veredito
if (problems.length === 0) {
  console.log(`[check-release] OK — versao ${version} promovida, contagens do README honestas, changelog acompanha o conteudo.`);
  process.exit(0);
}
console.error('[check-release] FALHOU:\n  - ' + problems.join('\n  - '));
process.exit(1);

// ---------------------------------------------------------------- helpers
function checkReadme(re, real, label) {
  const found = [...readme.matchAll(re)].map(m => Number(m[1]));
  if (found.length === 0) { problems.push(`README nao menciona a contagem de ${label} (esperado ${real}) — nao da para validar.`); return; }
  const wrong = found.filter(n => n !== real);
  if (wrong.length) problems.push(`README diz ${label} = ${[...new Set(wrong)].join('/')} mas o filesystem tem ${real} — atualize o total e o detalhamento.`);
}
function diffNames(ref) {
  try { execFileSync('git', ['-C', REPO, 'rev-parse', ref], { stdio: 'ignore' }); }
  catch {
    console.error(`[check-release] AVISO: base "${ref}" nao resolveu — R3 comparando so com HEAD~1 (escopo reduzido).`);
    return safeDiff('HEAD~1');
  }
  return safeDiff(ref);
}
function safeDiff(ref) {
  try {
    return execFileSync('git', ['-C', REPO, 'diff', '--name-only', `${ref}...HEAD`], { encoding: 'utf8' })
      .split('\n').filter(Boolean);
  } catch { return null; }
}
function countDirs(rel) { try { return fs.readdirSync(path.join(REPO, rel), { withFileTypes: true }).filter(x => x.isDirectory()).length; } catch { return 0; } }
function countFiles(rel, ext) { try { return fs.readdirSync(path.join(REPO, rel)).filter(f => f.endsWith(ext)).length; } catch { return 0; } }
function read(p) { try { return fs.readFileSync(p, 'utf-8'); } catch { return ''; } }
function readJson(p) { try { return JSON.parse(fs.readFileSync(p, 'utf-8')); } catch { return {}; } }
function argVal(flag) { const i = process.argv.indexOf(flag); return i !== -1 ? process.argv[i + 1] : undefined; }
function escapeRe(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }
