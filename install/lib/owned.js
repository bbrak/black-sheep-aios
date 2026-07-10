// Black Sheep AIOS — inventario do que o harness POSSUI em <CLAUDE_HOME> (fonte unica).
// Compartilhado por bsaios-state.js (grava no install) e bsaios-update.js (prune de orfaos).
// DEVE bater exatamente com o que os instaladores copiam, senao o prune apaga o que nao devia.
// Caminhos relativos a CLAUDE_HOME, granularidade por-skill/por-agent/por-rule.
'use strict';

const fs = require('fs');
const path = require('path');

function listDirs(dir) {
  try { return fs.readdirSync(dir, { withFileTypes: true }).filter(d => d.isDirectory()).map(d => d.name); }
  catch { return []; }
}
function listFiles(dir, ext) {
  try { return fs.readdirSync(dir).filter(f => f.endsWith(ext)); }
  catch { return []; }
}

function computeOwned(repoDir) {
  const H = path.join(repoDir, 'harness');
  const out = ['RTK.md', 'statusline-command.js', 'settings.json', 'CLAUDE.md'];
  listDirs(path.join(H, 'skills')).forEach(d => out.push('skills/' + d));
  listFiles(path.join(H, 'agents'), '.md').forEach(f => out.push('agents/' + f));
  out.push('hooks/git-moment-advisor.sh', 'hooks/validate-agent-frontmatter.py', 'hooks/team');
  listFiles(path.join(H, 'rules'), '.md').forEach(f => out.push('rules/' + f));
  listFiles(path.join(H, 'commands'), '.md').forEach(f => out.push('commands/' + f));
  out.push('plugins/bsaios-marketplace');
  return out.sort();
}

module.exports = { computeOwned };
