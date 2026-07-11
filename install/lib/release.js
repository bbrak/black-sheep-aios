#!/usr/bin/env node
// Black Sheep AIOS — release de 1 comando (ritual atomico: impossivel shipar pela metade).
//
// Numa acao so: bump da versao (install/manifest.json = fonte unica) -> promove o CHANGELOG
// `## [Nao lancado]` -> `## [X.Y.Z] — data` (e recria um `[Nao lancado]` vazio) -> roda
// sync-manifest.js --write (propaga a versao e a contagem de skills para plugin.json,
// marketplace.json e VERSION) -> commit `chore(release): vX.Y.Z`. Ao final IMPRIME o comando de
// mover a tag `stable` — a publicacao (push da tag) e acao externa e fica com o owner (conta bbrak).
//
// Por que existe: o esquecimento do bump/changelog deixa a versao parada -> o banner de update nunca
// dispara e ninguem sabe o que mudou. Aqui o caminho certo vira UM comando.
//
// Uso:
//   node install/lib/release.js <patch|minor|major> [--date YYYY-MM-DD] [--no-commit]
'use strict';

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const REPO = path.resolve(__dirname, '..', '..');
const level = process.argv[2];
if (!['patch', 'minor', 'major'].includes(level)) {
  die('uso: node install/lib/release.js <patch|minor|major> [--date YYYY-MM-DD] [--no-commit]');
}
const dateArg = argVal('--date');
const noCommit = process.argv.includes('--no-commit');

const manifestPath = path.join(REPO, 'install', 'manifest.json');
const changelogPath = path.join(REPO, 'CHANGELOG.md');

const manifest = readJson(manifestPath);
const cur = String(manifest.version || '0.0.0');
const next = bump(cur, level);
const date = dateArg || new Date().toISOString().slice(0, 10);

// 1. CHANGELOG — exige `[Nao lancado]` COM conteudo e o promove para uma versao datada.
let cl = fs.readFileSync(changelogPath, 'utf-8');
const headerRe = /^## \[Não lançado\][^\n]*\n/m;
const hm = cl.match(headerRe);
if (!hm) die('CHANGELOG.md sem a secao "## [Não lançado]" — nao sei onde promover.');
const afterHeader = cl.slice(hm.index + hm[0].length);
const nextVerIdx = afterHeader.search(/^## \[/m);
const body = (nextVerIdx === -1 ? afterHeader : afterHeader.slice(0, nextVerIdx)).trim();
if (!body) die('CHANGELOG `[Não lançado]` esta vazio — nada a lancar. Registre as mudancas primeiro.');
const tail = nextVerIdx === -1 ? '' : afterHeader.slice(nextVerIdx).replace(/^\n+/, '');
cl = cl.slice(0, hm.index)
  + '## [Não lançado]\n\n'
  + `## [${next}] — ${date}\n\n${body}\n\n`
  + tail;
fs.writeFileSync(changelogPath, cl, 'utf-8');

// 2. Versao (fonte unica) — o sync-manifest propaga o resto.
manifest.version = next;
fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n', 'utf-8');

// 3. Propaga versao + contagem para plugin.json / marketplace.json / VERSION.
run('node', [path.join(REPO, 'install', 'lib', 'sync-manifest.js'), '--write']);

// 4. Commit (a menos que --no-commit) — so os arquivos do release, nao varre WIP alheio.
const releaseFiles = [
  'CHANGELOG.md', 'VERSION', 'install/manifest.json',
  'plugins/bsaios-core/.claude-plugin/plugin.json',
  'plugins/.claude-plugin/marketplace.json',
  '.claude-plugin/marketplace.json'
].filter(f => fs.existsSync(path.join(REPO, f)));

console.log(`\n[release] ${cur} -> ${next} (${date})`);
if (!noCommit) {
  run('git', ['-C', REPO, 'add', '--', ...releaseFiles]);
  run('git', ['-C', REPO, 'commit', '-m', `chore(release): v${next}`, '--', ...releaseFiles]);
  console.log(`[release] commit chore(release): v${next} criado.`);
} else {
  console.log('[release] --no-commit: arquivos alterados, sem commit.');
}

console.log('\nPara PUBLICAR (o banner do time so dispara depois disto):');
console.log('  1. leve este commit para a main (push da branch + PR + merge).');
console.log('  2. mova a tag stable para a main (conta bbrak; depois volte para brokers):');
console.log('       git tag -f stable origin/main && git push -f origin stable');
process.exit(0);

// ---------------------------------------------------------------- helpers
function bump(v, lvl) {
  const p = String(v).replace(/^v/, '').split('.').map(n => parseInt(n, 10) || 0);
  while (p.length < 3) p.push(0);
  if (lvl === 'major') { p[0]++; p[1] = 0; p[2] = 0; }
  else if (lvl === 'minor') { p[1]++; p[2] = 0; }
  else { p[2]++; }
  return p.slice(0, 3).join('.');
}
function argVal(flag) { const i = process.argv.indexOf(flag); return i !== -1 ? process.argv[i + 1] : undefined; }
function readJson(p) { try { return JSON.parse(fs.readFileSync(p, 'utf-8')); } catch (e) { die('nao consegui ler ' + p + ': ' + e.message); } }
function run(cmd, args) { try { execFileSync(cmd, args, { stdio: 'inherit' }); } catch (e) { die(cmd + ' falhou: ' + e.message); } }
function die(m) { console.error('[release] ERRO: ' + m); process.exit(1); }
