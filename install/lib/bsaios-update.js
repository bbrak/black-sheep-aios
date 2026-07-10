#!/usr/bin/env node
// Black Sheep AIOS — updater transacional (FORA da sessao do Claude: shell-out do /bsaios-update,
// nunca edita arquivo dentro da sessao => nao bate no GateGuard). Node puro, zero deps.
//
// Uso:
//   node bsaios-update.js --claude-home <dir> [--platform mac|windows] [--ref <ref>]
//                         [--repo <sourceRepo>] [--no-pull] [--yes] [--force] [--quiet]
//
// Fluxo (spec Fase 3): garante o clone-fonte -> compara versao (idempotente) -> imprime delta do
// CHANGELOG -> 1 sim/nao -> backup -> migrations pendentes -> APPLY (copia harness+plugin, merge
// so das chaves do time no settings re-renderizado por-SO, re-render do CLAUDE.md do profile.json,
// prune de orfaos) -> VERIFY (JSON.parse, arquivos do manifesto existem, hooks resolvem, GateGuard
// vivo) -> em falha restaura o backup e MANTEM a versao antiga; em sucesso carimba a versao NOVA
// por ultimo e rotaciona backups (keep-5).
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync, spawnSync } = require('child_process');
const { computeOwned } = require('./owned.js');

// origem do clone-fonte; overridavel para forks/self-host e para o e2e (file:// de um repo local)
const REPO_URL = process.env.BSAIOS_REPO_URL || 'https://github.com/bbrak/black-sheep-aios';
const KEEP_BACKUPS = 5;
// chaves do time substituidas por inteiro no merge (pessoal vive em settings.local.json).
// Declarado no topo (nao no corpo) para nao cair na TDZ quando applyPayload roda antes.
const TEAM_REPLACE = ['hooks', 'statusLine', 'enabledPlugins', 'extraKnownMarketplaces', 'enableAllProjectMcpServers'];

// ---------------------------------------------------------------- args
const args = process.argv.slice(2);
function opt(flag, dflt) { const i = args.indexOf(flag); return i !== -1 && args[i + 1] !== undefined ? args[i + 1] : dflt; }
const has = flag => args.includes(flag);

const QUIET = has('--quiet');
function say(m) { if (!QUIET) console.log(m); }
function ok(m) { if (!QUIET) console.log('  [ok] ' + m); }
function warn(m) { console.error('  [!!] ' + m); }
function die(m, code) { console.error('[bsaios-update] ERRO: ' + m); process.exit(code === undefined ? 1 : code); }

const platform = opt('--platform', process.platform === 'win32' ? 'windows' : 'mac');
if (platform !== 'windows' && platform !== 'mac') die('--platform deve ser windows ou mac');
let claudeHome = path.resolve(opt('--claude-home', path.join(os.homedir(), '.claude')));
const ref = opt('--ref', process.env.BSAIOS_UPDATE_REF || 'stable');

// ---------------------------------------------------------------- 1. clone-fonte
const cloneDir = path.join(claudeHome, '.bsaios', 'repo');
let repo = opt('--repo', '');
if (repo) {
  repo = path.resolve(repo); // modo teste/local: aplica direto deste repo
} else {
  repo = ensureSourceClone(cloneDir, ref, !has('--no-pull'));
}
const repoManifest = readJson(path.join(repo, 'install', 'manifest.json'));
if (!repoManifest || !repoManifest.version) die('clone-fonte sem install/manifest.json valido (' + repo + ')');
const latest = repoManifest.version;

// ---------------------------------------------------------------- 2. comparar versao (idempotente)
const stateDir = path.join(claudeHome, '.bsaios');
const installed = (readJson(path.join(stateDir, 'version.json')) || {}).product_version || '0.0.0';
if (!has('--force') && !isNewer(latest, installed)) {
  say('[bsaios-update] Ja esta atualizado (v' + installed + ').');
  process.exit(0);
}

// ---------------------------------------------------------------- 3. delta do CHANGELOG
say('== Black Sheep AIOS — update v' + installed + ' -> v' + latest + ' (ref ' + ref + ', ' + platform + ') ==');
printChangelogDelta(path.join(repo, 'CHANGELOG.md'), installed);

// --check: preview (mostra delta e sai; o comando in-session usa isto para perguntar antes de aplicar)
if (has('--check')) { say('(preview — nada aplicado. Confirme para atualizar de fato.)'); process.exit(0); }

// ---------------------------------------------------------------- 4. confirmacao (1 sim/nao)
const isMajor = major(latest) > major(installed);
if (!has('--yes')) {
  const q = isMajor ? 'Atualizacao MAJOR (v' + installed + ' -> v' + latest + '). Confirmar? (s/N) '
                    : 'Atualizar v' + installed + ' -> v' + latest + '? (s/N) ';
  if (!confirmSync(q)) { say('Cancelado. Nada mudou.'); process.exit(0); }
}

// ---------------------------------------------------------------- 5. backup
const stamp = timestamp();
const backupDir = path.join(claudeHome, 'backups', 'bsaios-' + stamp);
const ownedOld = ((readJson(path.join(stateDir, 'manifest.installed.json')) || {}).owned) || [];
const ownedNew = computeOwned(repo);
const stateRel = ['.bsaios/version.json', '.bsaios/profile.json', '.bsaios/manifest.installed.json'];
const backupPaths = uniq([...ownedOld, ...ownedNew, ...stateRel]);
const backedUp = backupTree(claudeHome, backupPaths, backupDir);
ok('backup -> ' + backupDir + ' (' + backedUp.length + ' itens)');

// ---------------------------------------------------------------- APPLY (transacional)
try {
  runMigrations(repo, installed, latest);
  applyPayload(repo, claudeHome, platform, ownedOld, ownedNew);
  verifyOrThrow(claudeHome, ownedNew);
} catch (e) {
  warn('APPLY/VERIFY falhou: ' + e.message);
  say('Restaurando backup e mantendo a versao antiga (v' + installed + ')...');
  restoreTree(claudeHome, backupPaths, backupDir, backedUp, ownedNew);
  die('update revertido. Nada foi perdido. (' + e.message + ')');
}

// ---------------------------------------------------------------- stamp (por ultimo) + rotacao
const stateArgs = ['--claude-home', claudeHome, '--platform', platform, '--repo', repo,
  '--manifest', path.join(repo, 'install', 'manifest.json')];
runNode(path.join(__dirname, 'bsaios-state.js'), stateArgs); // regrava version/manifest.installed; profile intacto
rotateBackups(path.join(claudeHome, 'backups'), KEEP_BACKUPS);
selfUpdateUpdater(repo, claudeHome);

say('');
say('== Atualizado para v' + latest + ' ==');
say('Aplique agora: rode /reload-plugins; se algo novo nao aparecer, reinicie a sessao.');
say('Desfazer: /bsaios-rollback');
process.exit(0);

// ================================================================ helpers

function ensureSourceClone(dir, gitRef, doPull) {
  if (!hasGit()) die('git ausente — necessario para atualizar. Instale git e rode de novo.');
  try {
    if (!fs.existsSync(path.join(dir, '.git'))) {
      fs.mkdirSync(path.dirname(dir), { recursive: true });
      say('Clonando o repo-fonte (' + gitRef + ')...');
      try { git(['clone', '--depth', '1', '--branch', gitRef, REPO_URL, dir]); }
      catch { git(['clone', '--depth', '1', REPO_URL, dir]); } // ref pode nao existir ainda
    } else if (doPull) {
      say('Atualizando o clone-fonte (' + gitRef + ')...');
      try { git(['-C', dir, 'fetch', '--depth', '1', '--tags', 'origin', gitRef]); git(['-C', dir, 'checkout', '-f', 'FETCH_HEAD']); }
      catch { try { git(['-C', dir, 'fetch', 'origin']); git(['-C', dir, 'checkout', '-f', gitRef]); } catch { warn('nao consegui atualizar o clone; usando o que ja existe'); } }
    }
  } catch (e) {
    if (!fs.existsSync(path.join(dir, 'install', 'manifest.json'))) die('nao consegui obter o repo-fonte: ' + e.message);
    warn('git falhou; usando clone existente (possivelmente defasado)');
  }
  return dir;
}

function applyPayload(srcRepo, home, plat, oldOwned, newOwned) {
  const H = path.join(srcRepo, 'harness');
  // arquivos fixos + arvores
  copyInto(path.join(H, 'RTK.md'), path.join(home, 'RTK.md'));
  copyInto(path.join(H, 'statusline-command.js'), path.join(home, 'statusline-command.js'));
  copyDirChildren(path.join(H, 'skills'), path.join(home, 'skills'));
  copyDirFiles(path.join(H, 'agents'), path.join(home, 'agents'), '.md');
  copyInto(path.join(H, 'hooks', 'git-moment-advisor.sh'), path.join(home, 'hooks', 'git-moment-advisor.sh'));
  copyInto(path.join(H, 'hooks', 'validate-agent-frontmatter.py'), path.join(home, 'hooks', 'validate-agent-frontmatter.py'));
  copyInto(path.join(H, 'hooks', 'team'), path.join(home, 'hooks', 'team'));
  copyDirFiles(path.join(H, 'rules'), path.join(home, 'rules'), '.md');
  copyDirFiles(path.join(H, 'commands'), path.join(home, 'commands'), '.md');
  // plugin vendorizado
  copyInto(path.join(srcRepo, 'plugins'), path.join(home, 'plugins', 'bsaios-marketplace'));

  // settings.json: renderiza o template do time por-SO num temp, depois MERGE so das chaves do time
  const tmpSettings = path.join(home, '.bsaios', 'settings.rendered.json');
  const profilePath = path.join(home, '.bsaios', 'profile.json');
  runNode(path.join(__dirname, 'render-settings.js'),
    [path.join(H, 'settings.team.json'), tmpSettings, '--claude-home', home, '--platform', plat]);
  const rendered = readJson(tmpSettings);
  // le o settings.json ATUAL distinguindo "nao existe" (ok, base {}) de "existe mas invalido".
  // Invalido => ABORTA (nunca regenera cego: isso apagaria o pessoal). O catch restaura o backup.
  const settingsFile = path.join(home, 'settings.json');
  let existing = {};
  if (fs.existsSync(settingsFile)) {
    try { existing = JSON.parse(fs.readFileSync(settingsFile, 'utf-8')); }
    catch (e) { throw new Error('settings.json atual invalido — nao vou sobrescrever seu pessoal: ' + e.message); }
  }
  const merged = mergeSettings(existing, rendered);
  fs.writeFileSync(path.join(home, 'settings.json'), JSON.stringify(merged, null, 2) + '\n', 'utf-8');
  try { fs.unlinkSync(tmpSettings); } catch { /* noop */ }

  // CLAUDE.md re-renderizado do profile.json (recusa se identidade quebrada -> throw -> restore)
  const r = runNodeCapture(path.join(__dirname, 'render-settings.js'),
    [path.join(H, 'CLAUDE.md.template'), path.join(home, 'CLAUDE.md'), '--claude-home', home, '--platform', plat, '--profile', profilePath]);
  if (r.status !== 0) throw new Error('render do CLAUDE.md recusado (identidade ausente/placeholder). ' + (r.stderr || '').trim());

  // prune de orfaos: owned_antigo - owned_novo (com backup ja feito), sem tocar em arquivos do usuario
  const orphans = oldOwned.filter(p => !newOwned.includes(p));
  for (const rel of orphans) { rmrf(path.join(home, rel)); ok('orfao aposentado: ' + rel); }
}

function mergeSettings(existing, rendered) {
  const merged = { ...existing };
  // env: shallow-merge — atualiza as chaves do time, preserva env pessoal posto no settings.json
  if (rendered.env) merged.env = { ...(existing.env || {}), ...rendered.env };
  // permissions: escalares do time (defaultMode), arrays allow/deny por uniao (nunca perde allow pessoal)
  if (rendered.permissions) {
    const p = { ...(existing.permissions || {}), ...rendered.permissions };
    p.allow = unionDedupe(existing.permissions && existing.permissions.allow, rendered.permissions.allow);
    p.deny = unionDedupe(existing.permissions && existing.permissions.deny, rendered.permissions.deny);
    // bsheep: uniao mantem um allow que o time REMOVEU; conservador. Revisar se virar problema.
    merged.permissions = p;
  }
  // demais chaves do time: substituicao (pessoal vive em settings.local.json, runtime-merged e vence)
  for (const k of TEAM_REPLACE) if (k in rendered) merged[k] = rendered[k];
  return merged;
}

function verifyOrThrow(home, newOwned) {
  // settings.json parseavel
  const settingsRaw = readFile(path.join(home, 'settings.json'));
  let settings; try { settings = JSON.parse(settingsRaw); } catch (e) { throw new Error('settings.json invalido: ' + e.message); }
  // todo arquivo do manifesto novo existe
  const missing = newOwned.filter(rel => !fs.existsSync(path.join(home, rel)));
  if (missing.length) throw new Error('faltam arquivos do manifesto: ' + missing.slice(0, 5).join(', '));
  // todo comando de hook que aponta para <home>/... resolve para um arquivo real
  const bad = unresolvedHookFiles(settings, home);
  if (bad.length) throw new Error('hooks apontam para arquivos inexistentes: ' + bad.slice(0, 5).join(', '));
  // GateGuard vivo + plugins habilitados
  const v = runNodeCapture(path.join(__dirname, 'verify-harness.js'), ['--claude-home', home, '--quiet']);
  if (v.status !== 0) throw new Error('health check falhou: ' + (v.stderr || v.stdout || '').trim());
}

function unresolvedHookFiles(settings, home) {
  const bad = [];
  const hooks = settings.hooks || {};
  const homeSlash = home.replace(/\\/g, '/');
  for (const ev of Object.keys(hooks)) {
    for (const group of hooks[ev] || []) {
      for (const h of (group.hooks || [])) {
        const cmd = (h.command || '').replace(/\\/g, '/');
        const re = new RegExp(escapeRe(homeSlash) + '[^"\'\\s]+', 'g');
        const matches = cmd.match(re) || [];
        for (let f of matches) { f = f.replace(/[)"';]+$/, ''); if (!fs.existsSync(f)) bad.push(path.relative(home, f)); }
      }
    }
  }
  return bad;
}

// ---------- migrations: install/migrations/NNNN-slug.js, ordenadas, idempotentes, version-gated
function runMigrations(srcRepo, fromV, toV) {
  const dir = path.join(srcRepo, 'install', 'migrations');
  let files = [];
  try { files = fs.readdirSync(dir).filter(f => /^\d+.*\.js$/.test(f)).sort(); } catch { return; }
  for (const f of files) {
    let mod; try { mod = require(path.join(dir, f)); } catch (e) { throw new Error('migration ' + f + ' nao carregou: ' + e.message); }
    const mv = mod.version || '0.0.0';
    if (isNewer(mv, fromV) && !isNewer(mv, toV)) { // fromV < mv <= toV
      say('  migration ' + f + ' (v' + mv + ')...');
      mod.apply({ claudeHome, platform, repo: srcRepo, say, ok, warn });
    }
  }
}

// ---------- backup / restore
function backupTree(home, rels, dest) {
  const done = [];
  for (const rel of rels) {
    const src = path.join(home, rel);
    if (!fs.existsSync(src)) continue;
    const to = path.join(dest, rel);
    fs.mkdirSync(path.dirname(to), { recursive: true });
    fs.cpSync(src, to, { recursive: true });
    done.push(rel);
  }
  return done;
}
function restoreTree(home, rels, dest, backedUp, newOwned) {
  // remove tudo que a apply pode ter criado/alterado, depois recopia o backup exato
  for (const rel of uniq([...rels, ...newOwned])) rmrf(path.join(home, rel));
  for (const rel of backedUp) {
    const from = path.join(dest, rel), to = path.join(home, rel);
    fs.mkdirSync(path.dirname(to), { recursive: true });
    fs.cpSync(from, to, { recursive: true });
  }
}
function rotateBackups(backupsRoot, keep) {
  let dirs = [];
  try { dirs = fs.readdirSync(backupsRoot).filter(d => d.startsWith('bsaios-')).sort(); } catch { return; }
  for (const d of dirs.slice(0, Math.max(0, dirs.length - keep))) rmrf(path.join(backupsRoot, d));
}

// ---------- copia
function copyInto(src, dest) { if (!fs.existsSync(src)) return; rmrf(dest); fs.mkdirSync(path.dirname(dest), { recursive: true }); fs.cpSync(src, dest, { recursive: true }); }
function copyDirChildren(srcDir, destDir) { for (const name of dirEntries(srcDir, true)) copyInto(path.join(srcDir, name), path.join(destDir, name)); }
function copyDirFiles(srcDir, destDir, ext) { for (const name of dirEntries(srcDir, false).filter(f => f.endsWith(ext))) copyInto(path.join(srcDir, name), path.join(destDir, name)); }
function dirEntries(dir, dirsOnly) { try { return fs.readdirSync(dir, { withFileTypes: true }).filter(e => dirsOnly ? e.isDirectory() : e.isFile()).map(e => e.name); } catch { return []; } }

function selfUpdateUpdater(srcRepo, home) {
  // mantem a copia estavel do updater fresca para a proxima rodada (self-update do updater)
  try {
    copyInto(path.join(srcRepo, 'install', 'lib'), path.join(home, '.bsaios', 'updater', 'lib'));
    copyInto(path.join(srcRepo, 'install', 'migrations'), path.join(home, '.bsaios', 'updater', 'migrations'));
    copyInto(path.join(srcRepo, 'install', 'manifest.json'), path.join(home, '.bsaios', 'updater', 'manifest.json'));
  } catch { /* nao critico */ }
}

// ---------- util
function readFile(p) { return fs.readFileSync(p, 'utf-8'); }
function readJson(p) { try { return JSON.parse(fs.readFileSync(p, 'utf-8')); } catch { return null; } }
function uniq(a) { return [...new Set(a)]; }
function unionDedupe(a, b) { const seen = new Set(); const out = []; for (const v of [...(a || []), ...(b || [])]) { const k = typeof v === 'string' ? v : JSON.stringify(v); if (!seen.has(k)) { seen.add(k); out.push(v); } } return out; }
function rmrf(p) { try { fs.rmSync(p, { recursive: true, force: true }); } catch { /* noop */ } }
function escapeRe(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }
function major(v) { return parseInt(String(v).replace(/^v/, '').split('.')[0], 10) || 0; }
function isNewer(a, b) {
  const pa = String(a).replace(/^v/, '').split('.').map(n => parseInt(n, 10) || 0);
  const pb = String(b).replace(/^v/, '').split('.').map(n => parseInt(n, 10) || 0);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) { const x = pa[i] || 0, y = pb[i] || 0; if (x > y) return true; if (x < y) return false; }
  return false;
}
function timestamp() { const d = new Date(); const p = n => String(n).padStart(2, '0'); return d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate()) + '-' + p(d.getHours()) + p(d.getMinutes()) + p(d.getSeconds()); }
function printChangelogDelta(changelogPath, fromV) {
  const raw = readJsonRaw(changelogPath); if (!raw) return;
  const lines = raw.split('\n'); const out = [];
  for (const l of lines) { if (new RegExp('^##\\s*\\[' + escapeRe(fromV) + '\\]').test(l)) break; out.push(l); }
  const body = out.join('\n').trim();
  if (body) { say(''); say('--- Novidades desde v' + fromV + ' ---'); say(body); say(''); }
}
function readJsonRaw(p) { try { return fs.readFileSync(p, 'utf-8'); } catch { return null; } }
function confirmSync(q) {
  if (!process.stdin.isTTY) return false; // sem TTY e sem --yes => nao assume sim
  process.stdout.write(q);
  const buf = Buffer.alloc(256);
  try { const n = fs.readSync(0, buf, 0, 256, null); return /^s/i.test(buf.toString('utf-8', 0, n).trim()); }
  catch { return false; }
}
function hasGit() { try { git(['--version']); return true; } catch { return false; } }
function git(a) { return execFileSync('git', a, { stdio: ['ignore', 'pipe', 'pipe'], encoding: 'utf-8' }); }
function runNode(script, a) { const r = spawnSync(process.execPath, [script, ...a], { stdio: 'inherit' }); if (r.status !== 0) throw new Error(path.basename(script) + ' saiu com codigo ' + r.status); }
function runNodeCapture(script, a) { return spawnSync(process.execPath, [script, ...a], { encoding: 'utf-8' }); }
