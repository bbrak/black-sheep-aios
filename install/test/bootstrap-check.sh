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

# estado do ~/.claude real antes de tudo (tem que ficar identico ao fim).
# Vigiamos a ASSINATURA UNICA DO INSTALADOR, nao um find no ~/.claude inteiro: o proprio Claude Code
# escreve la o tempo todo (transcripts, logs, .DS_Store, cache de plugin, skills novas), o que deixava
# um fingerprint por paths flaky justamente quando o teste roda de dentro de uma sessao viva. O sinal
# limpo de vazamento e este: o install.sh cria 'backups/bsaios-<timestamp>' SO quando escreve num
# CLAUDE_HOME real. Se a isolacao (BSAIOS_CLAUDE_HOME) vazasse, esse diretorio apareceria aqui. Nada
# mais no ~/.claude cria esse padrao — os backups de sessao sao '.claude.json.backup.*', outro nome.
REAL="$HOME/.claude"
installer_leak_sig() { ls -d "$REAL"/backups/bsaios-* 2>/dev/null | sort; }
REAL_LEAK_BEFORE="$(installer_leak_sig)"
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
# BSAIOS_PROFILE redireciona o append_profile p/ o sandbox: o passo 3 do bootstrap agora grava o
# ~/.local/bin no perfil SEMPRE (nao so quando acabou de instalar o claude), e sem esta costura o
# teste escreveria no ~/.zprofile de quem roda — exatamente o que o check D proibe.
PROF="$SBX/zprofile"
if have brew && have git && have node && have uv && have python3 && have jq && have code && have claude; then
  DIRC="$SBX/harness-c"; CHC="$SBX/claude-c"
  ( cd "$SBX" && BSAIOS_REPO_URL="file://$ORIGIN" BSAIOS_UPDATE_REF=stable BSAIOS_CLAUDE_HOME="$CHC" \
      BSAIOS_PROFILE="$PROF" bash "$BOOT" --dir "$DIRC" --yes --skip-tools \
      --name "Teste Bootstrap" --role "CI" --focus "parity" >/dev/null 2>&1 )
  [ -d "$DIRC/.git" ]                && ok "bootstrap clonou o harness (dir isolado)"      || no "nao clonou"
  [ -f "$CHC/.bsaios/version.json" ] && ok "install.sh escreveu o harness (carimbo final)"|| no "install nao completou"
  grep -q "Teste Bootstrap" "$CHC/CLAUDE.md" 2>/dev/null && ok "identidade real aplicada" || no "identidade nao aplicada"
  # C3. o ~/.local/bin e persistido MESMO com o claude ja instalado (regressao do graphify quebrado:
  # isto vivia dentro do ramo "else" de 'if have claude' e nunca rodava nessas maquinas).
  grep -qF '.local/bin' "$PROF" 2>/dev/null && ok "append_profile gravou ~/.local/bin (mesmo com claude ja instalado)" || no "~/.local/bin NAO persistido — graphify quebraria"
  # idempotencia da cadeia real: 2a vez -> git pull + reinstala
  ( cd "$SBX" && BSAIOS_REPO_URL="file://$ORIGIN" BSAIOS_UPDATE_REF=stable BSAIOS_CLAUDE_HOME="$CHC" \
      BSAIOS_PROFILE="$PROF" bash "$BOOT" --dir "$DIRC" --yes --skip-tools \
      --name "Teste Bootstrap" --role "CI" --focus "parity" >/dev/null 2>&1 )
  [ -f "$CHC/.bsaios/version.json" ] && ok "2a rodada real ok (dir existente -> fetch + checkout + reinstala)" || no "2a rodada real quebrou"
  [ "$(grep -cF '.local/bin' "$PROF" 2>/dev/null | tr -d ' ')" = "1" ] && ok "append_profile idempotente (1 linha apos 2 rodadas)" || no "append_profile duplicou a linha"
  # C2. release movido (regressao do bug do fetch de tag): origin ganha arquivo + stable movido -> update pega
  echo "NOVO" > "$ORIGIN/RELEASE_MARKER.txt"
  git -C "$ORIGIN" -c user.email=t@t -c user.name=t add -A >/dev/null 2>&1
  git -C "$ORIGIN" -c user.email=t@t -c user.name=t commit -qm "release v2" >/dev/null 2>&1
  git -C "$ORIGIN" tag -f stable >/dev/null 2>&1
  ( cd "$SBX" && BSAIOS_REPO_URL="file://$ORIGIN" BSAIOS_UPDATE_REF=stable BSAIOS_CLAUDE_HOME="$CHC" \
      BSAIOS_PROFILE="$PROF" bash "$BOOT" --dir "$DIRC" --yes --skip-tools \
      --name "Teste Bootstrap" --role "CI" --focus "parity" >/dev/null 2>&1 )
  [ -f "$DIRC/RELEASE_MARKER.txt" ] && ok "update pega o stable movido (fetch --tags --force)" || no "update NAO pegou o stable movido (bug do fetch de tag)"
else
  skip "cadeia real pulada (algum pre-req do passo 2 ausente: brew/git/node/uv/python/jq/code/claude — ex.: CI). A cadeia dry-run (B) ja cobre o chaining."
fi

echo ""
echo "== H. PATH vai para .zprofile E .zshrc (terminal do VS Code e non-login, le so o .zshrc) =="
# Exercita o append_profile REAL (sem BSAIOS_PROFILE) com HOME isolado: prova que o PATH e gravado
# NOS DOIS rc. Sem o .zshrc, o terminal do VS Code (non-login) nunca carrega o PATH e o 'claude' some.
if have brew && have git && have node && have uv && have python3 && have jq && have code && have claude; then
  FH="$SBX/fakehome"; mkdir -p "$FH"; DIRH="$SBX/harness-h"; CHH="$SBX/claude-h"
  ( cd "$SBX" && HOME="$FH" BSAIOS_REPO_URL="file://$ORIGIN" BSAIOS_UPDATE_REF=stable BSAIOS_CLAUDE_HOME="$CHH" \
      bash "$BOOT" --dir "$DIRH" --yes --skip-tools --name X --role Y --focus Z >/dev/null 2>&1 )
  grep -qF '.local/bin' "$FH/.zprofile" 2>/dev/null && ok ".zprofile recebeu o PATH (shell de login)"     || no ".zprofile NAO recebeu o PATH"
  grep -qF '.local/bin' "$FH/.zshrc"    2>/dev/null && ok ".zshrc recebeu o PATH (terminal do VS Code)"   || no ".zshrc NAO recebeu o PATH — VS Code nao veria o claude"
else
  skip "check H pulado (algum pre-req do passo 2 ausente)"
fi

echo ""
echo "== F. done-signal honesto: se uma etapa falha, NAO diz 'TUDO PRONTO' =="
# Caminho de falha REAL alcancavel sem instalar nada: um harness clonado mas sem install/install.sh.
# Antes, o bootstrap avisava e AINDA ASSIM imprimia "TUDO PRONTO" + exit 0 — mandando a pessoa embora
# achando que deu certo numa maquina onde o harness nunca foi escrito.
if have brew && have git && have node && have uv && have python3 && have jq && have code && have claude; then
  DIRF="$SBX/harness-f"; mkdir -p "$DIRF"
  printf 'stub\n' > "$DIRF/README.md"
  git -C "$DIRF" init -q
  git -C "$DIRF" -c user.email=t@t -c user.name=t add -A >/dev/null 2>&1
  git -C "$DIRF" -c user.email=t@t -c user.name=t commit -qm stub >/dev/null 2>&1
  OUTF="$( cd "$SBX" && BSAIOS_PROFILE="$PROF" /bin/bash "$BOOT" --dir "$DIRF" 2>&1 )"; RCF=$?
  echo "$OUTF" | grep -q "INSTALACAO INCOMPLETA" && ok "falha sinalizada ('INSTALACAO INCOMPLETA')"  || no "falha NAO sinalizada"
  echo "$OUTF" | grep -q "TUDO PRONTO"           && no "MENTIU: disse 'TUDO PRONTO' apos falhar"     || ok "nao disse 'TUDO PRONTO' (done-signal honesto)"
  [ "$RCF" -ne 0 ]                               && ok "exit code != 0 na falha (RCF=$RCF)"          || no "exit 0 mesmo tendo falhado"
else
  skip "check F pulado (algum pre-req do passo 2 ausente)"
fi

echo ""
echo "== E. caminho sem-flags (ARGS vazio no passo 5) nao aborta — regressao do blocker =="
if have brew && have git && have node && have uv && have python3 && have jq && have code && have claude; then
  DIRE="$SBX/harness-e"; mkdir -p "$DIRE/install"
  printf '#!/usr/bin/env bash\necho STUB_INSTALL_OK\n' > "$DIRE/install/install.sh"
  git -C "$DIRE" init -q
  git -C "$DIRE" -c user.email=t@t -c user.name=t add -A >/dev/null 2>&1
  git -C "$DIRE" -c user.email=t@t -c user.name=t commit -qm stub >/dev/null 2>&1
  # SEM flags e SEM BSAIOS_CLAUDE_HOME -> ARGS fica vazio no passo 5; roda no /bin/bash (o shell do curl|bash).
  # BSAIOS_PROFILE nao e flag: nao entra no ARGS, entao a regressao continua sendo exercitada como antes.
  OUTE="$( cd "$SBX" && BSAIOS_PROFILE="$PROF" /bin/bash "$BOOT" --dir "$DIRE" 2>&1 )"
  echo "$OUTE" | grep -q "TUDO PRONTO"     && ok "no-flag: chegou ao done-signal (ARGS vazio nao abortou)" || no "no-flag: abortou antes do done-signal (blocker do ARGS vazio)"
  echo "$OUTE" | grep -q "STUB_INSTALL_OK" && ok "no-flag: chamou o install.sh (ARGS vazio expandiu ok)"   || no "no-flag: nao chamou o install.sh"
else
  skip "check E pulado (algum pre-req do passo 2 ausente: brew/git/node/uv/python/jq/code/claude)"
fi

echo ""
echo "== G. identidade vazia falha com mensagem humana, nao com stack de node =="
# Sem terminal p/ perguntar, NAME/ROLE/FOCUS ficam vazios. O render-settings RECUSA identidade vazia
# (lib/render-settings.js:65-70) e, sob 'set -e', o install.sh morria com um erro de node no meio do
# passo [4/7]. Este e o caminho que uma pessoa leiga mais encontra: apertar Enter em "Areas de foco".
CHG="$SBX/claude-g"
OUTG="$( bash "$REPO/install/install.sh" --claude-home "$CHG" --skip-tools </dev/null 2>&1 )"; RCG=$?
[ "$RCG" -ne 0 ]                                  && ok "install.sh falha (exit $RCG) em vez de escrever identidade quebrada" || no "aceitou identidade vazia"
echo "$OUTG" | grep -q "identidade incompleta"    && ok "diz 'identidade incompleta' + o comando pronto"                      || no "sem mensagem humana"
echo "$OUTG" | grep -q "recuso escrever"          && no "vazou o erro cru do render-settings p/ o usuario"                    || ok "nao vazou erro tecnico do node"
[ ! -f "$CHG/CLAUDE.md" ]                         && ok "nao escreveu CLAUDE.md com identidade quebrada"                      || no "escreveu CLAUDE.md mesmo sem identidade"

echo ""
echo "== D. sem poluicao: ~/.claude real + CWD do repo intactos =="
REAL_LEAK_AFTER="$(installer_leak_sig)"
[ "$REAL_LEAK_BEFORE" = "$REAL_LEAK_AFTER" ] && ok "~/.claude real intacto (nenhum backup do instalador vazou da isolacao)" || no "o instalador VAZOU p/ o ~/.claude real (novo backups/bsaios-*)"
[ ! -e "$REPO/CLAUDE.md" ] && [ ! -e "$REPO/.agents" ] && [ ! -e "$REPO/skills-lock.json" ] \
                             && ok "CWD do repo sem poluicao de ferramentas" || no "CWD do repo poluido"
ZAFTER="$(cksum "$HOME/.zprofile" 2>/dev/null || echo none)"
[ "$ZBEFORE" = "$ZAFTER" ]   && ok "~/.zprofile intacto (nenhum append_profile vazou)" || no "~/.zprofile mudou"

# cleanup (mantem o sandbox se BSAIOS_BOOTSTRAP_SBX foi passado)
[ -n "${BSAIOS_BOOTSTRAP_SBX:-}" ] || rm -rf "$SBX"

echo ""
echo "== bootstrap-check: $PASS pass, $FAIL fail =="
[ "$FAIL" -eq 0 ]
