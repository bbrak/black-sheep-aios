#!/usr/bin/env bash
# Black Sheep AIOS — teste do bootstrap (Fase 1). Hermetico: roda em qualquer lugar (incl. CI).
#
# Prova, ZERO efeito colateral (nao toca no ~/.claude real, nao instala nada de sistema, offline):
#   A. dry-run e idempotente e nao cria nada;
#   B. cadeia via dry-run: clone (de um "GitHub" file:// local) + install.sh --dry-run escrevem o
#      harness num CLAUDE_HOME isolado (roda ate no CI, que nao tem claude);
#   C. cadeia REAL (clone do bootstrap + install.sh --skip-tools) SO quando brew/git/node/claude ja
#      existem — assim o teste nunca instala dependencia de sistema nem baixa nada (pulada no CI);
#   D. o ~/.claude real e o CWD do repo continuam intactos.
#
# Uso:  bash install/test/bootstrap-check.sh
# Sandbox descartavel em $(mktemp -d) (ou BSAIOS_BOOTSTRAP_SBX p/ inspecionar depois).
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BOOT="$REPO/install/bootstrap.sh"
SBX="${BSAIOS_BOOTSTRAP_SBX:-$(mktemp -d)}"
ORIGIN="$SBX/origin"
PASS=0; FAIL=0
ok()   { printf '  [PASS] %s\n' "$*"; PASS=$((PASS+1)); }
no()   { printf '  [FAIL] %s\n' "$*"; FAIL=$((FAIL+1)); }
skip() { printf '  [skip] %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

have node || { echo "node e obrigatorio p/ o teste."; exit 1; }

# estado do ~/.claude real antes de tudo (tem que ficar identico ao fim)
REAL="$HOME/.claude"
REALCNT="$(find "$REAL" -type f 2>/dev/null | wc -l | tr -d ' ')"
ZBEFORE="$(cksum "$HOME/.zprofile" 2>/dev/null || echo none)"

echo "== A. dry-run: idempotente + sem efeito colateral =="
A="$(bash "$BOOT" --dry-run --dir "$SBX/none" 2>&1)"
B="$(bash "$BOOT" --dry-run --dir "$SBX/none" 2>&1)"
[ "$A" = "$B" ]                        && ok "duas saidas identicas (idempotente)" || no "saidas divergiram"
[ ! -e "$SBX/none" ]                   && ok "nao criou a pasta do harness"        || no "criou $SBX/none"
echo "$A" | grep -q "TUDO PRONTO"      && ok "done-signal presente"                || no "sem done-signal"
echo "$A" | grep -q "\[1/5\] Homebrew" && ok "passos numerados (progresso visivel)"|| no "sem numeracao de passos"

# "GitHub" file:// local (snapshot do repo) usado pelas cadeias B e C
mkdir -p "$ORIGIN"
tar -C "$REPO" --exclude='./.git' --exclude='./.claude' --exclude='./node_modules' -cf - . | tar -C "$ORIGIN" -xf -
git -C "$ORIGIN" init -q
git -C "$ORIGIN" -c user.email=t@t -c user.name=t add -A
git -C "$ORIGIN" -c user.email=t@t -c user.name=t commit -qm base >/dev/null
git -C "$ORIGIN" tag -f stable >/dev/null

echo ""
echo "== B. cadeia (dry-run, hermetica): clone existente -> install.sh --dry-run isolado =="
DIRB="$SBX/harness-b"; CHB="$SBX/claude-b"
git clone -q "file://$ORIGIN" "$DIRB" 2>/dev/null
[ -d "$DIRB/.git" ] && ok "origem file:// e clonavel" || no "origem nao clonou"
( cd "$SBX" && BSAIOS_CLAUDE_HOME="$CHB" BSAIOS_UPDATE_REF=stable bash "$BOOT" --dry-run --dir "$DIRB" >/dev/null 2>&1 )
[ -f "$CHB/settings.json" ]        && ok "settings.json no CLAUDE_HOME isolado"     || no "sem settings.json"
[ -f "$CHB/CLAUDE.md" ]            && ok "CLAUDE.md no CLAUDE_HOME isolado"         || no "sem CLAUDE.md"
[ -f "$CHB/.bsaios/version.json" ] && ok "version.json (carimbo final do install)" || no "sem version.json (install abortou)"
grep -q "Dry Run" "$CHB/CLAUDE.md" 2>/dev/null && ok "identidade de teste aplicada (sem placeholder)" || no "placeholder nao resolvido"
# idempotencia: repetir nao quebra
( cd "$SBX" && BSAIOS_CLAUDE_HOME="$CHB" BSAIOS_UPDATE_REF=stable bash "$BOOT" --dry-run --dir "$DIRB" >/dev/null 2>&1 )
[ -f "$CHB/.bsaios/version.json" ] && ok "2a rodada dry-run idempotente" || no "2a rodada dry-run quebrou"

echo ""
echo "== C. cadeia REAL (so com deps presentes; instala 0 dependencias) =="
if have brew && have git && have node && have claude; then
  DIRC="$SBX/harness-c"; CHC="$SBX/claude-c"
  ( cd "$SBX" && BSAIOS_REPO_URL="file://$ORIGIN" BSAIOS_UPDATE_REF=stable BSAIOS_CLAUDE_HOME="$CHC" \
      bash "$BOOT" --dir "$DIRC" --yes --skip-tools \
      --name "Teste Bootstrap" --role "CI" --focus "parity" >/dev/null 2>&1 )
  [ -d "$DIRC/.git" ]                && ok "bootstrap clonou o harness (dir isolado)"      || no "nao clonou"
  [ -f "$CHC/.bsaios/version.json" ] && ok "install.sh escreveu o harness (carimbo final)"|| no "install nao completou"
  grep -q "Teste Bootstrap" "$CHC/CLAUDE.md" 2>/dev/null && ok "identidade real aplicada" || no "identidade nao aplicada"
  # idempotencia da cadeia real: 2a vez -> git pull + reinstala
  ( cd "$SBX" && BSAIOS_REPO_URL="file://$ORIGIN" BSAIOS_UPDATE_REF=stable BSAIOS_CLAUDE_HOME="$CHC" \
      bash "$BOOT" --dir "$DIRC" --yes --skip-tools \
      --name "Teste Bootstrap" --role "CI" --focus "parity" >/dev/null 2>&1 )
  [ -f "$CHC/.bsaios/version.json" ] && ok "2a rodada real ok (dir existente -> fetch + checkout + reinstala)" || no "2a rodada real quebrou"
  # C2. release movido (regressao do bug do fetch de tag): origin ganha arquivo + stable movido -> update pega
  echo "NOVO" > "$ORIGIN/RELEASE_MARKER.txt"
  git -C "$ORIGIN" -c user.email=t@t -c user.name=t add -A >/dev/null 2>&1
  git -C "$ORIGIN" -c user.email=t@t -c user.name=t commit -qm "release v2" >/dev/null 2>&1
  git -C "$ORIGIN" tag -f stable >/dev/null 2>&1
  ( cd "$SBX" && BSAIOS_REPO_URL="file://$ORIGIN" BSAIOS_UPDATE_REF=stable BSAIOS_CLAUDE_HOME="$CHC" \
      bash "$BOOT" --dir "$DIRC" --yes --skip-tools \
      --name "Teste Bootstrap" --role "CI" --focus "parity" >/dev/null 2>&1 )
  [ -f "$DIRC/RELEASE_MARKER.txt" ] && ok "update pega o stable movido (fetch --tags --force)" || no "update NAO pegou o stable movido (bug do fetch de tag)"
else
  skip "cadeia real pulada (brew/git/node/claude ausentes — ex.: CI). A cadeia dry-run (B) ja cobre o chaining."
fi

echo ""
echo "== E. caminho sem-flags (ARGS vazio no passo 5) nao aborta — regressao do blocker =="
if have brew && have git && have node && have claude; then
  DIRE="$SBX/harness-e"; mkdir -p "$DIRE/install"
  printf '#!/usr/bin/env bash\necho STUB_INSTALL_OK\n' > "$DIRE/install/install.sh"
  git -C "$DIRE" init -q
  git -C "$DIRE" -c user.email=t@t -c user.name=t add -A >/dev/null 2>&1
  git -C "$DIRE" -c user.email=t@t -c user.name=t commit -qm stub >/dev/null 2>&1
  # SEM flags e SEM BSAIOS_CLAUDE_HOME -> ARGS fica vazio no passo 5; roda no /bin/bash (o shell do curl|bash)
  OUTE="$( cd "$SBX" && /bin/bash "$BOOT" --dir "$DIRE" 2>&1 )"
  echo "$OUTE" | grep -q "TUDO PRONTO"     && ok "no-flag: chegou ao done-signal (ARGS vazio nao abortou)" || no "no-flag: abortou antes do done-signal (blocker do ARGS vazio)"
  echo "$OUTE" | grep -q "STUB_INSTALL_OK" && ok "no-flag: chamou o install.sh (ARGS vazio expandiu ok)"   || no "no-flag: nao chamou o install.sh"
else
  skip "check E pulado (brew/git/node/claude ausentes)"
fi

echo ""
echo "== D. sem poluicao: ~/.claude real + CWD do repo intactos =="
REALCNT2="$(find "$REAL" -type f 2>/dev/null | wc -l | tr -d ' ')"
[ "$REALCNT" = "$REALCNT2" ] && ok "~/.claude real intacto ($REALCNT arquivos antes/depois)" || no "~/.claude real mudou ($REALCNT -> $REALCNT2)"
[ ! -e "$REPO/CLAUDE.md" ] && [ ! -e "$REPO/.agents" ] && [ ! -e "$REPO/skills-lock.json" ] \
                             && ok "CWD do repo sem poluicao de ferramentas" || no "CWD do repo poluido"
ZAFTER="$(cksum "$HOME/.zprofile" 2>/dev/null || echo none)"
[ "$ZBEFORE" = "$ZAFTER" ]   && ok "~/.zprofile intacto (nenhum append_profile vazou)" || no "~/.zprofile mudou"

# cleanup (mantem o sandbox se BSAIOS_BOOTSTRAP_SBX foi passado)
[ -n "${BSAIOS_BOOTSTRAP_SBX:-}" ] || rm -rf "$SBX"

echo ""
echo "== bootstrap-check: $PASS pass, $FAIL fail =="
[ "$FAIL" -eq 0 ]
