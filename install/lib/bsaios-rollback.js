#!/usr/bin/env node
// Black Sheep AIOS — rollback (FORA da sessao: shell-out do /bsaios-rollback). Restaura o backup
// mais novo (ou --backup <stamp>), EXCLUINDO segredos, e re-verifica. Node puro, zero deps.
//
// Uso:
//   node bsaios-rollback.js --claude-home <dir> [--backup <stamp>] [--yes] [--list]
'use strict';

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

// nunca restaura/sobrescreve segredos, mesmo que um backup antigo os contenha
const SECRET_RE = /(^|\/)(settings\.local\.json|\.credentials\.json)$|\.(pem|key)$/i;

const args = process.argv.slice(2);
function opt(f, d) { const i = args.indexOf(f); return i !== -1 && args[i + 1] !== undefined ? args[i + 1] : d; }
const has = f => args.includes(f);
function die(m) { console.error('[bsaios-rollback] ERRO: ' + m); process.exit(1); }

let claudeHome = opt('--claude-home', '');
if (!claudeHome) die('--claude-home e obrigatorio');
claudeHome = path.resolve(claudeHome);
const backupsRoot = path.join(claudeHome, 'backups');

let dirs = [];
try { dirs = fs.readdirSync(backupsRoot).filter(d => d.startsWith('bsaios-')).sort(); } catch { /* none */ }
if (!dirs.length) die('nenhum backup em ' + backupsRoot);

if (has('--list')) {
  console.log('Backups disponiveis (mais novo por ultimo):');
  for (const d of dirs) {
    const v = (readJson(path.join(backupsRoot, d, '.bsaios', 'version.json')) || {}).product_version || '?';
    console.log('  ' + d + '  (v' + v + ')');
  }
  process.exit(0);
}

const stamp = opt('--backup', '');
const chosen = stamp ? ('bsaios-' + stamp) : dirs[dirs.length - 1];
const backupDir = path.join(backupsRoot, chosen);
if (!fs.existsSync(backupDir)) die('backup nao encontrado: ' + backupDir);

const restoredVersion = (readJson(path.join(backupDir, '.bsaios', 'version.json')) || {}).product_version || '?';
console.log('== Rollback -> ' + chosen + ' (restaura v' + restoredVersion + ') ==');

if (!has('--yes')) {
  process.stdout.write('Restaurar este backup? Seu pessoal (settings.local.json, credenciais) NAO e tocado. (s/N) ');
  if (!confirmSync()) { console.log('Cancelado. Nada mudou.'); process.exit(0); }
}

const files = walk(backupDir);
let restored = 0, skipped = 0;
for (const abs of files) {
  const rel = path.relative(backupDir, abs).split(path.sep).join('/');
  if (SECRET_RE.test(rel)) { skipped++; continue; }
  const to = path.join(claudeHome, rel);
  fs.mkdirSync(path.dirname(to), { recursive: true });
  fs.copyFileSync(abs, to);
  restored++;
}
console.log('  [ok] ' + restored + ' arquivos restaurados (' + skipped + ' segredos preservados)');

const v = spawnSync(process.execPath, [path.join(__dirname, 'verify-harness.js'), '--claude-home', claudeHome], { stdio: 'inherit' });
console.log('');
console.log('== Rollback concluido (v' + restoredVersion + ') ==');
console.log('Rode /reload-plugins ou reinicie a sessao para aplicar.');
process.exit(v.status || 0);

function walk(dir) { const out = []; for (const e of fs.readdirSync(dir, { withFileTypes: true })) { const p = path.join(dir, e.name); if (e.isDirectory()) out.push(...walk(p)); else out.push(p); } return out; }
function readJson(p) { try { return JSON.parse(fs.readFileSync(p, 'utf-8')); } catch { return null; } }
function confirmSync() { if (!process.stdin.isTTY) return false; const b = Buffer.alloc(64); try { const n = fs.readSync(0, b, 0, 64, null); return /^s/i.test(b.toString('utf-8', 0, n).trim()); } catch { return false; } }
