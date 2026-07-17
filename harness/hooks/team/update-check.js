#!/usr/bin/env node
// Black Sheep AIOS — checagem de defasagem do harness (banner de update).
// Usado por session-context.js (SessionStart). Compara a versao instalada (.bsaios/version.json)
// com o VERSION do repo (raw). Cache fresco (< TTL) => leitura instantanea. Cache velho => busca
// SINCRONA e time-boxed (ate ~2,5s, no maximo 1x por TTL) para o banner refletir um release novo na
// MESMA sessao — sem comando manual. FAIL-SOFT: offline / rede lenta / sem git / CI => cache atual ou silencio.
'use strict';

const fs = require('fs');
const path = require('path');
const https = require('https');
const { execFileSync } = require('child_process');

const REF = process.env.BSAIOS_UPDATE_REF || 'stable';
// origem do VERSION; overridavel para forks/self-host e e2e (aceita um caminho local/file://)
const RAW_URL = process.env.BSAIOS_VERSION_URL || `https://raw.githubusercontent.com/bbrak/black-sheep-aios/${REF}/VERSION`;
const TTL_MS = 4 * 60 * 60 * 1000; // throttle: re-checa a cada 4h (aviso mais rapido, ainda detached/zero-latencia)
const NET_TIMEOUT_MS = 1500;        // time-box da rede

function readJson(p) { try { return JSON.parse(fs.readFileSync(p, 'utf-8')); } catch { return null; } }
function writeJsonSafe(p, o) {
  try { fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, JSON.stringify(o, null, 2) + '\n', 'utf-8'); }
  catch { /* fail-soft */ }
}

// compara versoes por segmento numerico: "1.10.0" > "1.9.0"
function isNewer(a, b) {
  const pa = String(a).replace(/^v/, '').split('.').map(n => parseInt(n, 10) || 0);
  const pb = String(b).replace(/^v/, '').split('.').map(n => parseInt(n, 10) || 0);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const x = pa[i] || 0, y = pb[i] || 0;
    if (x > y) return true;
    if (x < y) return false;
  }
  return false;
}

function fetchVersion(cb) {
  let done = false;
  const finish = v => { if (!done) { done = true; cb(v); } };
  if (!/^https?:/i.test(RAW_URL)) { // fonte local (path ou file://) — testes e forks self-hosted
    try { finish((fs.readFileSync(RAW_URL.replace(/^file:\/\//, ''), 'utf-8').trim().split('\n')[0] || '').trim() || null); }
    catch { finish(null); }
    return;
  }
  try {
    const req = https.get(RAW_URL, { timeout: NET_TIMEOUT_MS, headers: { 'User-Agent': 'bsaios-update-check' } }, res => {
      if (res.statusCode !== 200) { res.resume(); return finish(null); }
      let data = '';
      res.on('data', c => { data += c; if (data.length > 64) req.destroy(); });
      res.on('end', () => finish((data.trim().split('\n')[0] || '').trim() || null));
    });
    req.on('timeout', () => { req.destroy(); finish(null); });
    req.on('error', () => finish(null));
  } catch { finish(null); }
}

// Modo destacado: `node update-check.js --refresh <claudeHome>` — busca e reescreve o cache, sai.
if (process.argv[2] === '--refresh') {
  const claudeHome = process.argv[3];
  if (claudeHome) {
    const cachePath = path.join(claudeHome, '.bsaios', 'update-check.json');
    fetchVersion(remote => {
      const prev = readJson(cachePath) || {};
      writeJsonSafe(cachePath, {
        checked_at: new Date().toISOString(),
        ref: REF,
        latest_version: remote || prev.latest_version || null
      });
      process.exit(0);
    });
  } else {
    process.exit(0);
  }
}

// Como modulo: linha do banner (string) ou null. Quando o cache expira, busca a versao de forma
// SINCRONA e time-boxed (o banner ja reflete o release nesta sessao); caso contrario, leitura instantanea.
function updateBannerLine(claudeHome) {
  try {
    if (process.env.CI) return null;
    const stateDir = path.join(claudeHome, '.bsaios');
    const local = readJson(path.join(stateDir, 'version.json'));
    if (!local || !local.product_version) return null; // harness antigo / nao instalado => silencio

    const cachePath = path.join(stateDir, 'update-check.json');
    let cache = readJson(cachePath) || {};
    const fresh = cache.checked_at && cache.ref === REF && (Date.now() - Date.parse(cache.checked_at) < TTL_MS);

    if (!fresh) {
      // cache velho => busca SINCRONA e time-boxed (reusa o modo --refresh num filho); assim o banner
      // reflete o release na MESMA sessao, sem comando manual. Rede lenta/offline => fail-soft, usa o cache atual.
      try {
        execFileSync(process.execPath, [__filename, '--refresh', claudeHome], { timeout: NET_TIMEOUT_MS + 1000, stdio: 'ignore' });
        cache = readJson(cachePath) || cache;
      } catch { /* fail-soft: mantem o cache anterior */ }
    }

    const latest = cache.latest_version;
    if (latest && isNewer(latest, local.product_version)) {
      return `Black Sheep AIOS v${latest} disponivel (voce tem v${local.product_version}) — rode /bsaios-update (aplica ao reiniciar a sessao).`;
    }
    return null;
  } catch { return null; }
}

module.exports = { updateBannerLine, isNewer };
