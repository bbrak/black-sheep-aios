#!/usr/bin/env node
// Black Sheep AIOS — fonte unica de versao + guarda de drift de contagem (resolve BSA-3).
//
// install/manifest.json.version e a AUTORIDADE da versao do produto. plugin.json e
// marketplace.json sincronizam dela em vez de duplicar o numero. As mencoes "NN skills" nas
// descricoes sao mantidas honestas contra a contagem real do filesystem (o drift 49-vs-53).
//
// Uso:
//   node sync-manifest.js            # --check (default): falha (exit 1) se houver drift — para CI
//   node sync-manifest.js --write    # corrige versoes e contagens in-place
'use strict';

const fs = require('fs');
const path = require('path');

const REPO = path.resolve(__dirname, '..', '..');
const WRITE = process.argv.includes('--write');

const manifestPath = path.join(REPO, 'install', 'manifest.json');
const pluginPath = path.join(REPO, 'plugins', 'bsaios-core', '.claude-plugin', 'plugin.json');
// Ambos os marketplaces sao mantidos honestos: o da raiz (github, canonico pos-cutover) e o do
// subdir (directory, entrega ativa ate o cutover). Pula o que nao existir.
const marketPaths = [
  path.join(REPO, '.claude-plugin', 'marketplace.json'),
  path.join(REPO, 'plugins', '.claude-plugin', 'marketplace.json')
].filter(p => fs.existsSync(p));

const manifest = readJson(manifestPath);
const version = manifest.version;
if (!version) die('manifest.json sem campo "version"');

const skills = countDirs(path.join(REPO, 'plugins', 'bsaios-core', 'skills'));
const reSkills = /\b(\d+)\s+skills\b/i;

const problems = [];

// targets: cada arquivo a validar. `doc` guarda version+description; `root` e o objeto a re-gravar
// (para marketplace, root=manifest inteiro e doc=entry aninhado do bsaios-core).
const plugin = readJson(pluginPath);
const targets = [{ label: 'plugin.json', file: pluginPath, doc: plugin, root: plugin }];
for (const mp of marketPaths) {
  const market = readJson(mp);
  const entry = (market.plugins || []).find(p => p.name === 'bsaios-core');
  if (!entry) die(mp + ' sem o plugin bsaios-core');
  targets.push({ label: path.relative(REPO, mp), file: mp, doc: entry, root: market });
}

const changed = new Set();
for (const t of targets) {
  // 1. versao sincronizada com o manifest (fonte unica)
  if (t.doc.version !== version) {
    problems.push(`${t.label} version=${t.doc.version} != manifest ${version}`);
    t.doc.version = version; changed.add(t);
  }
  // 2. contagem "NN skills" honesta na descricao (o numero deve bater com o filesystem)
  const desc = t.doc.description || '';
  const m = desc.match(reSkills);
  if (m && Number(m[1]) !== skills) {
    problems.push(`${t.label} description diz "${m[1]} skills" mas o filesystem tem ${skills}`);
    t.doc.description = desc.replace(reSkills, skills + ' skills'); changed.add(t);
  } else if (!m) {
    problems.push(`${t.label} description nao menciona "NN skills" (nao da para validar a contagem)`);
  }
}

// 3. VERSION (raiz) — arquivo texto lido pelo banner de update via raw; espelha o manifest.
const versionFilePath = path.join(REPO, 'VERSION');
let versionFileChanged = false;
if (fs.existsSync(versionFilePath)) {
  const cur = fs.readFileSync(versionFilePath, 'utf-8').trim();
  if (cur !== version) { problems.push(`VERSION="${cur}" != manifest ${version}`); versionFileChanged = true; }
}

if (problems.length === 0) {
  console.log(`[sync-manifest] OK — versao ${version}, ${skills} skills, ${targets.length} alvos, sem drift.`);
  process.exit(0);
}

if (WRITE) {
  for (const t of changed) writeJson(t.file, t.root);
  if (versionFileChanged) fs.writeFileSync(versionFilePath, version + '\n', 'utf-8');
  console.log('[sync-manifest] CORRIGIDO:\n  - ' + problems.join('\n  - '));
  process.exit(0);
}

console.error('[sync-manifest] DRIFT detectado (rode com --write para corrigir):\n  - ' + problems.join('\n  - '));
process.exit(1);

function readJson(p) { try { return JSON.parse(fs.readFileSync(p, 'utf-8')); } catch (e) { die('nao consegui ler/parsear ' + p + ': ' + e.message); } }
function writeJson(p, o) { fs.writeFileSync(p, JSON.stringify(o, null, 2) + '\n', 'utf-8'); }
function countDirs(d) { try { return fs.readdirSync(d, { withFileTypes: true }).filter(x => x.isDirectory()).length; } catch { return 0; } }
function die(m) { console.error('[sync-manifest] ERRO: ' + m); process.exit(2); }
