#!/usr/bin/env bash
# Black Sheep AIOS — teste END-TO-END do fluxo de colaborador:
#   owner sobe uma skill nova -> a tag `stable` avanca -> o colaborador recebe o BANNER ->
#   roda /bsaios-update (git clone/pull REAL de um "GitHub" local) -> a skill nova chega.
# Usa um remote git local (file://) e os seams BSAIOS_REPO_URL / BSAIOS_VERSION_URL. Nada de rede.
# Exit != 0 se qualquer etapa falhar.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
ORIGIN="$ROOT/origin"        # o "GitHub" (repo git local)
TEAM="$ROOT/teammate/.claude" # o ~/.claude de um colaborador
FAILS=0
G() { git -C "$ORIGIN" -c user.email=e2e@test -c user.name=e2e "$@"; }
assert() { if [ "$2" = "1" ]; then echo "PASS  $1"; else echo "FAIL  $1"; FAILS=$((FAILS+1)); fi; }

echo "== 0) monta o remote (snapshot do repo atual = v1.0.0) + tags stable/latest =="
mkdir -p "$ORIGIN"
tar -C "$REPO" --exclude='./.git' --exclude='./.claude' -cf - . | tar -C "$ORIGIN" -xf -
G init -q; G add -A; G commit -qm "base v1.0.0"; G tag -f stable >/dev/null; G tag -f latest >/dev/null

echo "== 1) colaborador instala v1.0.0 =="
mkdir -p "$TEAM"
bash "$REPO/install/install.sh" --claude-home "$TEAM" --dry-run >/dev/null 2>&1
node -e "const j=require('$TEAM/.bsaios/version.json'); process.exit(j.product_version==='1.0.0'?0:1)" && assert "instalado v1.0.0" 1 || assert "instalado v1.0.0" 0
# personaliza (tem que sobreviver ao update)
node -e "const f='$TEAM/settings.json';const j=require(f);j.model='opus';require('fs').writeFileSync(f,JSON.stringify(j,null,2))"

echo "== 2) OWNER publica: skill nova + bump v1.1.0 + sync + tag stable avanca =="
SKILL="$ORIGIN/plugins/bsaios-core/skills/e2e-demo-skill"
mkdir -p "$SKILL"
printf -- '---\nname: e2e-demo-skill\ndescription: skill de teste e2e\n---\n\nDemo.\n' > "$SKILL/SKILL.md"
node -e "const f='$ORIGIN/install/manifest.json';const j=require(f);j.version='1.1.0';require('fs').writeFileSync(f,JSON.stringify(j,null,2)+String.fromCharCode(10))"
node "$ORIGIN/install/lib/sync-manifest.js" --write >/dev/null
# entrada de CHANGELOG para o delta
node -e "const fs=require('fs'),f='$ORIGIN/CHANGELOG.md';const s=fs.readFileSync(f,'utf8').replace('## [Não lançado]','## [1.1.0] — 2026-07-11\n\n### Adicionado\n- Skill e2e-demo-skill (teste).\n\n## [Não lançado]');fs.writeFileSync(f,s)"
G add -A; G commit -qm "feat: e2e-demo-skill (v1.1.0)"; G tag -f stable >/dev/null
echo "  stable agora aponta v1.1.0 com a skill nova"

echo "== 3) COLABORADOR recebe o BANNER (VERSION do stable via seam local) =="
G show stable:VERSION > "$ROOT/remote-VERSION"
# a sessao anterior ja teria populado o cache (refresh destacado); aqui fazemos o refresh sincrono:
BSAIOS_VERSION_URL="$ROOT/remote-VERSION" node "$TEAM/hooks/team/update-check.js" --refresh "$TEAM"
# simula a sessao REAL do colaborador: sem CI (o banner e silenciado sob CI por design, veja update-check.js).
BANNER=$(env -u CI CLAUDE_PROJECT_DIR="$ROOT" node "$TEAM/hooks/team/session-context.js" </dev/null)
echo "$BANNER" | grep -q "v1.1.0 disponivel" && assert "banner anuncia v1.1.0" 1 || assert "banner anuncia v1.1.0" 0

echo "== 4) COLABORADOR roda /bsaios-update (git clone/pull REAL do remote local) =="
BSAIOS_REPO_URL="file://$ORIGIN" node "$TEAM/.bsaios/updater/lib/bsaios-update.js" \
  --claude-home "$TEAM" --platform mac --ref stable --yes 2>&1 | grep -E "update v|Atualizado|orfao|ERRO" | head

echo "== 5) ASSERTS: skill nova chegou, versao carimbada, pessoal intacto =="
node -e '
const fs=require("fs"),T="'$TEAM'";
const A=(k,v)=>{console.log((v?"PASS":"FAIL")+"  "+k);if(!v)process.exitCode=1;};
A("skill nova entregue", fs.existsSync(T+"/plugins/bsaios-marketplace/bsaios-core/skills/e2e-demo-skill/SKILL.md"));
A("versao carimbada 1.1.0", require(T+"/.bsaios/version.json").product_version==="1.1.0");
A("pessoal (model) preservado", require(T+"/settings.json").model==="opus");
A("clone-fonte do remote existe", fs.existsSync(T+"/.bsaios/repo/.git"));
' || FAILS=$((FAILS+1))

echo "== 6) idempotencia: segundo /bsaios-update = ja atualizado =="
BSAIOS_REPO_URL="file://$ORIGIN" node "$TEAM/.bsaios/updater/lib/bsaios-update.js" \
  --claude-home "$TEAM" --platform mac --ref stable --yes 2>&1 | grep -q "Ja esta atualizado" \
  && assert "re-run = ja atualizado" 1 || assert "re-run = ja atualizado" 0

echo ""
if [ "$FAILS" -eq 0 ]; then echo "== E2E OK — publicar skill -> banner -> 1 comando -> entregue =="; else echo "== $FAILS FALHA(S) =="; exit 1; fi
