#!/usr/bin/env bash
# Black Sheep AIOS — REGRESSAO do bug do fetch de tag movida no /bsaios-update.
#
# O bug (real, visto em producao 17/07/2026): publicar = mover a tag `stable`/`latest` A FORCA.
# O clone-fonte do updater (~/.claude/.bsaios/repo) ja tinha a tag local. Sem `git fetch --force`,
# o fetch REJEITA a tag movida ("would clobber existing tag"), sai != 0, o updater cai no fallback
# e da checkout na tag VELHA -> falso "ja atualizado" -> o colaborador NUNCA recebe o release.
#
# Gatilho determinístico: o clone criado rastreando UM ref (ex.: latest, via canário) e depois um
# update por OUTRO ref (stable, o default) — o fallback nao recupera. Este teste reproduz isso
# dirigindo o UPDATER REAL contra um "GitHub" local (file://). FALHA no codigo sem --force.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
ORIGIN="$ROOT/origin"
FAILS=0
G() { git -C "$ORIGIN" -c user.email=e2e@test -c user.name=e2e "$@"; }
assert() { if [ "$2" = "1" ]; then echo "PASS  $1"; else echo "FAIL  $1"; FAILS=$((FAILS+1)); fi; }

echo "== 0) remote local + tags stable/latest =="
mkdir -p "$ORIGIN"
tar -C "$REPO" --exclude='./.git' --exclude='./.claude' -cf - . | tar -C "$ORIGIN" -xf -
G init -q; G add -A; G commit -qm base >/dev/null; G tag -f stable >/dev/null; G tag -f latest >/dev/null
BASE_V="$(node -e "console.log(require('$ORIGIN/install/manifest.json').version)")"
NEXT_V="$(node -e "const p='$BASE_V'.split('.').map(Number);p[2]++;console.log(p.join('.'))")"

# publica um novo release: bump + skill nova + move stable/latest (a forca)
publish() {
  local v="$1"
  local sk="$ORIGIN/plugins/bsaios-core/skills/reg-skill-$v"
  mkdir -p "$sk"; printf -- '---\nname: reg-skill-%s\ndescription: regressao\n---\n\nx\n' "$v" > "$sk/SKILL.md"
  node -e "const f='$ORIGIN/install/manifest.json';const j=require(f);j.version='$v';require('fs').writeFileSync(f,JSON.stringify(j,null,2)+String.fromCharCode(10))"
  node "$ORIGIN/install/lib/sync-manifest.js" --write >/dev/null
  node -e "const fs=require('fs'),f='$ORIGIN/CHANGELOG.md';const s=fs.readFileSync(f,'utf8').replace('## [Não lançado]','## [Não lançado]\n\n## [$v] — reg\n\n### Corrigido\n- reg.');fs.writeFileSync(f,s)"
  G add -A; G commit -qm "v$v" >/dev/null; G tag -f stable >/dev/null; G tag -f latest >/dev/null
}
# roda /bsaios-update no ref dado; ecoa a versao instalada
update_to() { # <team_dir> <ref>
  BSAIOS_REPO_URL="file://$ORIGIN" node "$1/.bsaios/updater/lib/bsaios-update.js" \
    --claude-home "$1" --platform mac --ref "$2" --yes >/dev/null 2>&1 || true
  node -e "console.log(require('$1/.bsaios/version.json').product_version)" 2>/dev/null
}

echo "== 1) CASO DO BUG: clone criado via 'latest', release move stable, update via 'stable' (default) =="
T1="$ROOT/t1/.claude"; mkdir -p "$T1"
bash "$REPO/install/install.sh" --claude-home "$T1" --dry-run >/dev/null 2>&1
update_to "$T1" latest >/dev/null              # clone-fonte passa a rastrear latest
publish "$NEXT_V"                              # owner publica e move stable/latest a forca
GOT1="$(update_to "$T1" stable)"               # update via stable (default) sobre clone existente
[ "$GOT1" = "$NEXT_V" ] \
  && assert "clone-latest recebe stable movido (v$NEXT_V) — sem falso 'ja atualizado'" 1 \
  || assert "clone-latest TRAVOU no update (esperava v$NEXT_V, veio v$GOT1) [bug do fetch de tag]" 0
[ -f "$T1/plugins/bsaios-marketplace/bsaios-core/skills/reg-skill-$NEXT_V/SKILL.md" ] \
  && assert "skill do release entregue" 1 || assert "skill do release entregue" 0

echo "== 2) CAMINHO COMUM: clone via 'stable', outro release move stable, update via 'stable' =="
NEXT2_V="$(node -e "const p='$NEXT_V'.split('.').map(Number);p[2]++;console.log(p.join('.'))")"
T2="$ROOT/t2/.claude"; mkdir -p "$T2"
bash "$REPO/install/install.sh" --claude-home "$T2" --dry-run >/dev/null 2>&1
update_to "$T2" stable >/dev/null              # clone rastreando stable, ja em v$NEXT_V
publish "$NEXT2_V"                             # mais um release
GOT2="$(update_to "$T2" stable)"
[ "$GOT2" = "$NEXT2_V" ] \
  && assert "clone-stable recebe stable movido (v$NEXT2_V)" 1 \
  || assert "clone-stable TRAVOU (esperava v$NEXT2_V, veio v$GOT2)" 0

echo ""
if [ "$FAILS" -eq 0 ]; then echo "== REGRESSAO OK — tag movida chega ao colaborador em ambos os casos =="; else echo "== $FAILS FALHA(S) =="; exit 1; fi
