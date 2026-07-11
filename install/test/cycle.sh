#!/usr/bin/env bash
# Black Sheep AIOS — teste de regressao do ciclo install -> update -> rollback (macOS/Linux).
# Prova os nao-negociaveis: pessoal sobrevive, orfaos sao podados, transacional restaura em falha,
# idempotente. Usado pelo CI e localmente. Exit != 0 se qualquer assercao quebrar.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PV="$(node -e "console.log(require('$REPO/install/manifest.json').version)")"  # versao-alvo (nao hardcodar)
H="$(mktemp -d)"
trap 'rm -rf "$H"' EXIT
FAILS=0
assert() { if [ "$2" = "1" ]; then echo "PASS  $1"; else echo "FAIL  $1"; FAILS=$((FAILS+1)); fi; }

echo "== 1) install (dry-run) -> v$PV =="
bash "$REPO/install/install.sh" --claude-home "$H" --dry-run >/dev/null 2>&1
V=$(node -e "console.log(require('$H/.bsaios/version.json').product_version)")
assert "install carimba version.json" "$([ "$V" = "$PV" ] && echo 1 || echo 0)"
node "$REPO/install/lib/verify-harness.js" --claude-home "$H" --quiet >/dev/null && assert "verify-harness pos-install" 1 || assert "verify-harness pos-install" 0

echo "== 2) simula estado antigo + pessoal + orfao =="
node -e "const f='$H/.bsaios/version.json';const j=require(f);j.product_version='0.9.0';require('fs').writeFileSync(f,JSON.stringify(j))"
node -e "const f='$H/.bsaios/manifest.installed.json';const j=require(f);j.owned.push('agents/OLD-ORPHAN.md');require('fs').writeFileSync(f,JSON.stringify(j))"
echo x > "$H/agents/OLD-ORPHAN.md"
rm -f "$H/commands/bsaios-update.md"   # comando que o update DEVE entregar (finding: applyPayload copia commands)
node -e "const f='$H/settings.json';const j=require(f);j.model='opus';j.permissions.allow.push('Bash(pessoal:*)');require('fs').writeFileSync(f,JSON.stringify(j))"
printf '{"theme":"dark"}\n' > "$H/settings.local.json"

echo "== 3) update v0.9.0 -> v$PV =="
node "$REPO/install/lib/bsaios-update.js" --claude-home "$H" --platform mac --repo "$REPO" --no-pull --yes >/dev/null 2>&1
node -e '
const fs=require("fs"),H="'$H'";
const s=JSON.parse(fs.readFileSync(H+"/settings.json"));
const ok=(k,v)=>{console.log((v?"PASS":"FAIL")+"  "+k);if(!v)process.exitCode=1;};
ok("versao alvo", JSON.parse(fs.readFileSync(H+"/.bsaios/version.json")).product_version==="'$PV'");
ok("orfao podado", !fs.existsSync(H+"/agents/OLD-ORPHAN.md"));
ok("team hook vivo", JSON.stringify(s.hooks).includes("rtk hook claude"));
ok("pessoal model preservado", s.model==="opus");
ok("pessoal allow preservado", (s.permissions.allow||[]).includes("Bash(pessoal:*)"));
ok("settings.local intacto", fs.readFileSync(H+"/settings.local.json","utf8").includes("dark"));
ok("comando entregue no update", fs.existsSync(H+"/commands/bsaios-update.md"));
' || FAILS=$((FAILS+1))

echo "== 4) idempotencia =="
OUT=$(node "$REPO/install/lib/bsaios-update.js" --claude-home "$H" --platform mac --repo "$REPO" --no-pull --yes 2>&1)
echo "$OUT" | grep -q "Ja esta atualizado" && assert "re-run = ja atualizado" 1 || assert "re-run = ja atualizado" 0

echo "== 5) rollback -> v0.9.0 =="
node "$REPO/install/lib/bsaios-rollback.js" --claude-home "$H" --yes >/dev/null 2>&1
VR=$(node -e "console.log(require('$H/.bsaios/version.json').product_version)")
assert "rollback volta a 0.9.0" "$([ "$VR" = "0.9.0" ] && echo 1 || echo 0)"
assert "rollback restaura orfao" "$([ -f "$H/agents/OLD-ORPHAN.md" ] && echo 1 || echo 0)"

echo "== 6) settings.json corrompido => update ABORTA, mantem versao e pessoal =="
printf '{ "model": "opus", "env": { "X": "1" }, }\n' > "$H/settings.json"   # JSON invalido (virgula final)
set +e
node "$REPO/install/lib/bsaios-update.js" --claude-home "$H" --platform mac --repo "$REPO" --no-pull --yes --force >/dev/null 2>&1
set -e
VA=$(node -e "console.log(require('$H/.bsaios/version.json').product_version)")
assert "corrupt settings: versao NAO avancou (ficou 0.9.0)" "$([ "$VA" = "0.9.0" ] && echo 1 || echo 0)"
grep -q '"model": "opus"' "$H/settings.json" && assert "corrupt settings: pessoal nao apagado" 1 || assert "corrupt settings: pessoal nao apagado" 0

echo ""
if [ "$FAILS" -eq 0 ]; then echo "== ciclo OK =="; else echo "== $FAILS FALHA(S) =="; exit 1; fi
