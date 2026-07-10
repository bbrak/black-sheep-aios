#!/usr/bin/env bash
# Black Sheep AIOS — regressao do gate de frescor de docs.
# Prova que check-release.js FALHA nos 3 modos (R1 versao-sem-changelog, R2 contagem-README-errada,
# R3 conteudo-sem-changelog) e que release.js promove/versiona certo. Tudo num git repo isolado.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
W="$ROOT/work"
FAILS=0
G() { git -C "$W" -c user.email=t@t -c user.name=t "$@"; }
CR() { node "$W/install/lib/check-release.js" --base "$BASE" >/dev/null 2>&1; }  # exit 0 = passou
assert() { if [ "$2" = "1" ]; then echo "PASS  $1"; else echo "FAIL  $1"; FAILS=$((FAILS+1)); fi; }

echo "== 0) snapshot do repo como git isolado =="
mkdir -p "$W"
tar -C "$REPO" --exclude='./.git' --exclude='./.claude' -cf - . | tar -C "$W" -xf -
G init -q; G add -A; G commit -qm base
BASE="$(G rev-parse HEAD)"

echo "== 1) estado limpo => passa =="
CR && assert "estado limpo passa" 1 || assert "estado limpo passa" 0

echo "== 2) R3: modifica conteudo de skill SEM changelog => falha (contagem nao muda) =="
SK="$(find "$W/plugins/bsaios-core/skills" -name SKILL.md | head -1)"
printf '\n<!-- tweak -->\n' >> "$SK"
G add -A; G commit -qm "tweak skill sem changelog"
CR && assert "R3 conteudo-sem-changelog falha" 0 || assert "R3 conteudo-sem-changelog falha" 1
G reset --hard "$BASE" -q

echo "== 2b) R3: conteudo NAO-skill (harness/) sem changelog => falha (cobre a ampliacao do escopo) =="
printf '\n<!-- tweak -->\n' >> "$W/harness/RTK.md"
G add -A; G commit -qm "tweak harness sem changelog"
CR && assert "R3 harness-nao-skill falha" 0 || assert "R3 harness-nao-skill falha" 1
G reset --hard "$BASE" -q

echo "== 3) R1: bump de versao SEM secao no changelog => falha =="
node -e "const f='$W/install/manifest.json',fs=require('fs');const j=JSON.parse(fs.readFileSync(f));j.version='9.9.9';fs.writeFileSync(f,JSON.stringify(j,null,2)+'\n')"
G add -A; G commit -qm "bump sem changelog"
CR && assert "R1 versao-sem-changelog falha" 0 || assert "R1 versao-sem-changelog falha" 1
G reset --hard "$BASE" -q

echo "== 3b) R1: secao de versao VAZIA (stub) => falha =="
printf '# Changelog\n\n## [Não lançado]\n\n## [2.0.0] — 2026-03-03\n\n## [1.0.0] — 2026-07-07\n\n### Base\n- base\n' > "$W/CHANGELOG.md"
node -e "const f='$W/install/manifest.json',fs=require('fs');const j=JSON.parse(fs.readFileSync(f));j.version='2.0.0';fs.writeFileSync(f,JSON.stringify(j,null,2)+'\n')"
G add -A; G commit -qm "stub vazio 2.0.0"
CR && assert "R1 secao-vazia-stub falha" 0 || assert "R1 secao-vazia-stub falha" 1
G reset --hard "$BASE" -q

echo "== 4) R2: contagem do README errada => falha =="
node -e "const f='$W/README.md',fs=require('fs');fs.writeFileSync(f,fs.readFileSync(f,'utf8').replace('Agents (44)','Agents (99)'))"
G add -A; G commit -qm "readme errado"
CR && assert "R2 contagem-README falha" 0 || assert "R2 contagem-README falha" 1
G reset --hard "$BASE" -q

echo "== 5) release.js recusa [Nao lancado] vazio =="
printf '# Changelog\n\n## [Não lançado]\n\n## [1.0.0] — 2026-07-07\n\n### Base\n- base\n' > "$W/CHANGELOG.md"
node "$W/install/lib/release.js" minor --no-commit --date 2026-01-01 >/dev/null 2>&1 \
  && assert "release recusa changelog vazio" 0 || assert "release recusa changelog vazio" 1
G reset --hard "$BASE" -q

echo "== 6) release.js caminho feliz: promove + bump + propaga =="
# changelog + manifest proprios: nao depende do repo (cujo [Nao lancado] fica vazio pos-release)
printf '# Changelog\n\n## [Não lançado]\n\n### Adicionado\n- coisa nova\n\n## [1.0.0] — 2026-07-07\n\n### Base\n- base\n' > "$W/CHANGELOG.md"
node -e "const f='$W/install/manifest.json',fs=require('fs');const j=JSON.parse(fs.readFileSync(f));j.version='1.0.0';fs.writeFileSync(f,JSON.stringify(j,null,2)+'\n')"
node "$W/install/lib/release.js" minor --no-commit --date 2026-01-01 >/dev/null 2>&1
node -e "process.exit(JSON.parse(require('fs').readFileSync('$W/install/manifest.json')).version==='1.1.0'?0:1)" && assert "manifest 1.1.0" 1 || assert "manifest 1.1.0" 0
[ "$(cat "$W/VERSION")" = "1.1.0" ] && assert "VERSION 1.1.0" 1 || assert "VERSION 1.1.0" 0
node -e "process.exit(JSON.parse(require('fs').readFileSync('$W/plugins/bsaios-core/.claude-plugin/plugin.json')).version==='1.1.0'?0:1)" && assert "plugin.json 1.1.0" 1 || assert "plugin.json 1.1.0" 0
grep -q "## \[1.1.0\] — 2026-01-01" "$W/CHANGELOG.md" && assert "changelog promovido a 1.1.0" 1 || assert "changelog promovido a 1.1.0" 0
grep -q "## \[Não lançado\]" "$W/CHANGELOG.md" && assert "novo [Nao lancado] criado" 1 || assert "novo [Nao lancado] criado" 0
G add -A; G commit -qm "release 1.1.0"
CR && assert "pos-release o gate passa" 1 || assert "pos-release o gate passa" 0

echo "== 6b) release.js: [Nao lancado] vazio colado no proximo header => RECUSA (cobre #4) =="
G reset --hard "$BASE" -q
printf '# Changelog\n\n## [Não lançado]\n## [1.0.0] — 2026-07-07\n\n### Base\n- base\n' > "$W/CHANGELOG.md"
node "$W/install/lib/release.js" patch --no-commit --date 2026-02-02 >/dev/null 2>&1 \
  && assert "6b recusa unreleased-vazio-colado" 0 || assert "6b recusa unreleased-vazio-colado" 1
grep -q '1.0.1' "$W/CHANGELOG.md" && assert "6b changelog intacto (sem 1.0.1)" 0 || assert "6b changelog intacto (sem 1.0.1)" 1

echo ""
if [ "$FAILS" -eq 0 ]; then echo "== release-guard OK =="; else echo "== $FAILS FALHA(S) =="; exit 1; fi
