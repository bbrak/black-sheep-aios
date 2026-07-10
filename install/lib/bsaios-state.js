#!/usr/bin/env node
// Black Sheep AIOS — grava o estado da instalacao em <CLAUDE_HOME>/.bsaios/.
// Chamado como ULTIMO passo bem-sucedido pelos DOIS instaladores (install.sh + install.ps1):
// uma implementacao unica, cross-platform, para nao duplicar logica entre .sh e .ps1 (paridade).
// Node puro, zero deps. O estado e SEMPRE re-derivado na maquina de destino — nunca sincronizado
// entre SOs (o `platform` grava qual binario/arvore aquela maquina usa).
//
// Uso:
//   node bsaios-state.js --claude-home <dir> --platform <windows|mac> --repo <repoDir>
//                        [--manifest <manifest.json>] [--name ...] [--role ...] [--focus ...]
//
// Escreve (base de tudo o que vem depois: avisar, comparar, migrar, prune de orfaos, desfazer):
//   <claude-home>/.bsaios/version.json            {product_version, git_sha, platform, installed_at}
//   <claude-home>/.bsaios/profile.json            {name, role, focus}  — so se identidade fornecida;
//                                                  nunca sobrescreve a existente com vazio
//   <claude-home>/.bsaios/manifest.installed.json {product_version, installed_at, owned:[relpaths]}
'use strict';

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { computeOwned } = require('./owned.js');

function fail(m) { console.error('[bsaios-state] ERRO: ' + m); process.exit(1); }

const args = process.argv.slice(2);
function opt(flag, dflt) {
  const i = args.indexOf(flag);
  return i !== -1 && args[i + 1] !== undefined ? args[i + 1] : dflt;
}

const platform = opt('--platform', process.platform === 'win32' ? 'windows' : 'mac');
if (platform !== 'windows' && platform !== 'mac') fail('--platform deve ser windows ou mac');

let claudeHome = opt('--claude-home', '');
if (!claudeHome) fail('--claude-home e obrigatorio');
claudeHome = path.resolve(claudeHome);

const repo = path.resolve(opt('--repo', path.join(__dirname, '..', '..')));
const manifestPath = opt('--manifest', path.join(repo, 'install', 'manifest.json'));

let manifest;
try { manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf-8')); }
catch (e) { fail('nao consegui ler/parsear o manifest: ' + manifestPath + ' (' + e.message + ')'); }
const productVersion = manifest.version || 'unknown';

const now = new Date().toISOString();

let gitSha = 'unknown';
try {
  gitSha = execFileSync('git', ['-C', repo, 'rev-parse', '--short', 'HEAD'], { encoding: 'utf-8' }).trim() || 'unknown';
} catch { gitSha = 'unknown'; }

const stateDir = path.join(claudeHome, '.bsaios');
fs.mkdirSync(stateDir, { recursive: true });

// profile.json — identidade cacheada para re-renderizar o CLAUDE.md num update sem re-perguntar.
// So escreve se veio identidade; nunca apaga um profile existente com valores vazios.
const name = opt('--name', ''), role = opt('--role', ''), focus = opt('--focus', '');
if (name || role || focus) {
  writeJson(path.join(stateDir, 'profile.json'), { name, role, focus });
}

// manifest.installed.json — inventario do que o harness POSSUI nesta maquina. Base para aposentar
// orfaos num update (owned_antigo − owned_novo), sem tocar em arquivos que o usuario criou.
const owned = computeOwned(repo);
writeJson(path.join(stateDir, 'manifest.installed.json'), {
  product_version: productVersion,
  installed_at: now,
  owned
});

// version.json — a ANCORA de versao, escrita por ULTIMO: se algo acima falhar, a versao fica a
// antiga e o re-run refaz (idempotente); nunca fica "nova" apontando para um inventario velho.
writeJson(path.join(stateDir, 'version.json'), {
  product_version: productVersion,
  git_sha: gitSha,
  platform,
  installed_at: now
});

console.log('[bsaios-state] OK -> ' + stateDir +
  ' (v' + productVersion + ' sha ' + gitSha + ' platform ' + platform + ', ' + owned.length + ' itens)');

function writeJson(p, obj) { fs.writeFileSync(p, JSON.stringify(obj, null, 2) + '\n', 'utf-8'); }
