#!/usr/bin/env bash
# Black Sheep AIOS — bootstrap macOS (o degrau ANTERIOR ao install.sh).
#
# Comando unico (do README):
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/bbrak/black-sheep-aios/stable/install/bootstrap.sh)"
#
# Resolve o que o install.sh so SUGERE: instala Homebrew -> git/node -> Claude Code, clona o harness
# em ~/black-sheep-aios e chama install/install.sh. Zero duplicacao: toda a logica de harness fica la.
#
# Invariantes (Fase 0 §3 -> §5.3 do spec):
#   - Idempotente: cada etapa instala SO SE FALTAR; rodar 2x nao duplica nada.
#   - Fail-soft por etapa: se um item falha, avisa + da o comando manual + CONTINUA (nunca deixa a
#     maquina meio-instalada).
#   - Sem sudo escondido: o Homebrew pede a senha do Mac; o script AVISA antes e explica por que.
#   - Recarrega o PATH na mesma sessao (dor D3) e, no fim, manda reabrir o terminal.
#   - Detecta arquitetura (Apple Silicon /opt/homebrew vs Intel /usr/local).
#
# Flags:
#   --dry-run   nao instala nada; so checa e imprime o que FARIA (prova idempotencia; sem efeito colateral).
#   --dir <d>   pasta do harness (default ~/black-sheep-aios).
#   --yes         nao pergunta na instalacao de ferramentas externas (repassa --yes ao install.sh).
#   --skip-tools  nao instala ferramentas externas (rtk/graphify/agent-browser); repassa ao install.sh.
#   --name/--role/--focus  identidade (opcional; se ausente, o install.sh pergunta). Uso p/ automacao/CI.
#   -h|--help   esta ajuda.
# Env de teste: BSAIOS_REPO_URL (default repo publico), BSAIOS_UPDATE_REF (default stable),
#               BSAIOS_CLAUDE_HOME (isola o ~/.claude do install.sh; usado pelos testes).
set -uo pipefail   # sem -e de proposito: o fail-soft e explicito por etapa

# curl|bash consome o stdin com o texto do script — reconecta o terminal p/ os prompts
# (senha do Homebrew, identidade do install.sh) funcionarem. So reconecta se o /dev/tty for
# realmente abrivel (em CI/containers ele pode existir mas nao abrir).
if [ ! -t 0 ] && { : < /dev/tty; } 2>/dev/null; then exec < /dev/tty; fi

DIR="$HOME/black-sheep-aios"
DRY_RUN=0
YES=0
SKIP_TOOLS=0
NAME=""; ROLE=""; FOCUS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)    DRY_RUN=1; shift ;;
    --dir)        DIR="$2"; shift 2 ;;
    --yes|-y)     YES=1; shift ;;
    --skip-tools) SKIP_TOOLS=1; shift ;;
    --name)       NAME="$2"; shift 2 ;;
    --role)       ROLE="$2"; shift 2 ;;
    --focus)      FOCUS="$2"; shift 2 ;;
    -h|--help)    grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "flag desconhecida: $1"; exit 1 ;;
  esac
done

say()  { printf '%s\n' "$*"; }
ok()   { printf '  \033[32m[ok]\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m[!!]\033[0m %s\n' "$*"; }
info() { printf '  \033[36m[..]\033[0m %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# Apple Silicon vs Intel: onde o Homebrew mora.
if [ "$(uname -m)" = "arm64" ]; then BREW_PREFIX="/opt/homebrew"; else BREW_PREFIX="/usr/local"; fi
load_brew() { [ -x "$BREW_PREFIX/bin/brew" ] && eval "$("$BREW_PREFIX/bin/brew" shellenv)"; }
ensure_local_bin() { case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac; }

append_profile() { # <needle> <linha>  — grava no ~/.zprofile so se ainda nao existe (idempotente)
  local needle="$1" line="$2" prof="$HOME/.zprofile"
  [ -f "$prof" ] || touch "$prof"
  grep -qF "$needle" "$prof" 2>/dev/null || printf '\n%s\n' "$line" >> "$prof"
}

say ""
say "== Black Sheep AIOS — instalacao automatica (macOS) =="
say "   Instala, SO SE FALTAR: Homebrew, git, node, uv, python, jq, VS Code, Claude Code, e o harness em $DIR."
say "   Cada passo avisa antes de agir e CONTINUA mesmo se um item falhar (nada fica pela metade)."
[ $DRY_RUN -eq 1 ] && say "   (DRY-RUN: nada sera instalado — apenas mostro o que faria.)"
say ""

# ---------------------------------------------------------------- 1. Homebrew (gerenciador de pacotes)
say "[1/5] Homebrew"
if have brew || [ -x "$BREW_PREFIX/bin/brew" ]; then
  load_brew; ok "Homebrew ja instalado"
elif [ $DRY_RUN -eq 1 ]; then
  warn "Homebrew ausente (dry-run) — faria: install oficial + brew shellenv no ~/.zprofile"
else
  say ""
  say "  >> O Homebrew (gerenciador de programas do Mac) nao esta instalado. Vou instala-lo."
  say "     ATENCAO — leia antes de continuar:"
  say "     - Ele vai PEDIR A SENHA DE LOGIN DO SEU MAC (precisa de permissao de administrador)."
  say "     - O terminal NAO mostra nada enquanto voce digita a senha (nem pontinhos). E normal e"
  say "       proposital: digite a senha e aperte Enter as cegas."
  say "     - Se voce entra no Mac com Touch ID e nao lembra a senha: e a MESMA de quando o Mac reinicia."
  say "       Da pra ver/redefinir em Ajustes do Sistema > Touch ID e Senha."
  say "     - Numa maquina zerada ele baixa ~5-10 min as Ferramentas do Xcode. NAO e travamento — deixe rodar."
  say ""
  if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
    load_brew
    append_profile "$BREW_PREFIX/bin/brew shellenv" "eval \"\$($BREW_PREFIX/bin/brew shellenv)\""
    ok "Homebrew instalado (PATH carregado nesta sessao + gravado no ~/.zprofile)"
  else
    warn "Homebrew falhou (fail-soft). Instale manualmente e rode este bootstrap de novo:"
    warn '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  fi
fi

# ---------------------------------------------------------------- 2. pre-requisitos (via brew, so o que faltar)
say ""
say "[2/5] VS Code + pre-requisitos (git, node, uv, python, jq)"
brew_pkg() { # <bin> <formula>
  if have "$1"; then ok "$1 ja instalado"; return; fi
  if [ $DRY_RUN -eq 1 ]; then warn "$1 ausente (dry-run) — faria: brew install $2"; return; fi
  have brew || { warn "$1 ausente e sem brew — pulei (fail-soft). Depois: brew install $2"; return; }
  info "instalando $1 (brew install $2)..."
  if brew install "$2"; then
    load_brew; hash -r
    have "$1" && ok "$1 instalado" || warn "$1 instalou mas nao esta no PATH — reabra o terminal"
  else
    warn "$1 falhou (fail-soft) — tente: brew install $2"
  fi
}
brew_pkg git     git
brew_pkg node    node
brew_pkg uv      uv       # graphify instala via 'uv tool install'
brew_pkg python3 python   # hook validate-agent-frontmatter (PyYAML)
brew_pkg jq      jq       # team-os descobre agents de plugins (fail-soft sem ele)

# VS Code — editor onde o time trabalha (terminal integrado + Claude Code). Cask, nao formula.
if have code; then ok "VS Code ja instalado"
elif [ $DRY_RUN -eq 1 ]; then warn "VS Code ausente (dry-run) — faria: brew install --cask visual-studio-code"
else
  info "instalando VS Code..."
  if brew install --cask visual-studio-code >/dev/null 2>&1; then ok "VS Code instalado (comando 'code' disponivel)"
  else warn "VS Code falhou (fail-soft) — baixe manual: https://code.visualstudio.com"; fi
fi

# ---------------------------------------------------------------- 3. Claude Code
say ""
say "[3/5] Claude Code"
if have claude; then
  ok "Claude Code ja instalado ($(claude --version 2>/dev/null || echo '?'))"
elif [ $DRY_RUN -eq 1 ]; then
  warn "claude ausente (dry-run) — faria: curl -fsSL https://claude.ai/install.sh | bash"
else
  info "instalando o Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash || warn "instalador do Claude retornou erro (fail-soft)"
  ensure_local_bin; hash -r
  append_profile "$HOME/.local/bin" "export PATH=\"\$HOME/.local/bin:\$PATH\""
  if have claude; then
    ok "Claude Code instalado ($(claude --version 2>/dev/null || echo '?'))"
  else
    warn "claude instalou mas nao aparece no PATH nesta sessao (dor conhecida D3). Ja ajustei o PATH;"
    warn "se ainda nao achar, reabra o terminal. Manual: curl -fsSL https://claude.ai/install.sh | bash"
  fi
fi

# ---------------------------------------------------------------- 4. harness -> ~/black-sheep-aios
say ""
say "[4/5] Harness -> $DIR"
REPO_URL="${BSAIOS_REPO_URL:-https://github.com/bbrak/black-sheep-aios.git}"
REF="${BSAIOS_UPDATE_REF:-stable}"
if [ -d "$DIR/.git" ]; then
  if [ $DRY_RUN -eq 1 ]; then
    ok "harness ja existe em $DIR (dry-run: faria git fetch --tags --force + checkout $REF)"
  else
    # release = mover a tag `stable`. Precisa de --tags --force p/ atualizar a tag local ja existente;
    # nao usar `git pull` (o checkout de tag fica em detached HEAD e o pull sempre falharia).
    info "harness ja clonado — atualizando (git fetch --tags --force + checkout $REF)..."
    if git -C "$DIR" fetch --all --tags --force -q \
       && git -C "$DIR" checkout -q "$REF" 2>/dev/null; then
      ok "harness atualizado em $DIR ($REF)"
    else
      warn "atualizacao falhou (fail-soft) — sigo com o que ja esta em $DIR"
    fi
  fi
elif [ $DRY_RUN -eq 1 ]; then
  warn "harness ausente (dry-run) — faria: git clone $REPO_URL $DIR"
elif have git; then
  info "clonando o harness ($REF) em $DIR..."
  if git clone -q --branch "$REF" "$REPO_URL" "$DIR" 2>/dev/null || git clone -q "$REPO_URL" "$DIR"; then
    ok "harness clonado em $DIR"
  else
    warn "git clone falhou (fail-soft) — verifique a rede e rode o bootstrap de novo"
  fi
else
  warn "git ausente — nao da pra clonar. Instale git (passo 2) e rode o bootstrap de novo."
fi

# ---------------------------------------------------------------- 5. install.sh (escreve o harness)
say ""
say "[5/5] Instalador do harness (install.sh)"
INSTALL="$DIR/install/install.sh"
if [ $DRY_RUN -eq 1 ]; then
  if [ -n "${BSAIOS_CLAUDE_HOME:-}" ] && [ -f "$INSTALL" ]; then
    info "dry-run isolado: install.sh --dry-run --claude-home $BSAIOS_CLAUDE_HOME"
    bash "$INSTALL" --dry-run --claude-home "$BSAIOS_CLAUDE_HOME" || warn "install.sh (dry-run) reportou problema"
  else
    warn "dry-run: pularia a chamada real ao install.sh (faria: $INSTALL)"
  fi
elif [ -f "$INSTALL" ]; then
  info "rodando install.sh (resolve rtk/graphify/agent-browser e escreve o harness)..."
  ARGS=()
  [ -n "${BSAIOS_CLAUDE_HOME:-}" ] && ARGS+=(--claude-home "$BSAIOS_CLAUDE_HOME")
  [ $YES -eq 1 ] && ARGS+=(--yes)
  [ $SKIP_TOOLS -eq 1 ] && ARGS+=(--skip-tools)
  [ -n "$NAME" ]  && ARGS+=(--name  "$NAME")
  [ -n "$ROLE" ]  && ARGS+=(--role  "$ROLE")
  [ -n "$FOCUS" ] && ARGS+=(--focus "$FOCUS")
  # ${ARGS[@]+...}: no bash 3.2 do macOS, expandir um array VAZIO sob `set -u` aborta (unbound variable).
  # O comando canonico do README nao passa flags, entao ARGS fica vazio — este guard evita o abort.
  bash "$INSTALL" ${ARGS[@]+"${ARGS[@]}"} || warn "install.sh reportou problema (veja acima) — o bootstrap terminou, mas verifique"
else
  warn "nao encontrei $INSTALL — o clone do harness pode ter falhado. Rode o bootstrap de novo."
fi

# ---------------------------------------------------------------- done-signal (dor N4/N8: sem sinal de fim)
say ""
say "============================================================"
say " TUDO PRONTO — o Black Sheep AIOS esta instalado."
say "============================================================"
if [ $DRY_RUN -eq 1 ]; then
  say " (isto foi um DRY-RUN — nada foi instalado de verdade.)"
else
  say " Pode PARAR aqui — nao precisa mandar mais nenhum comando."
  say ""
  say " 1) FECHE este terminal e abra um NOVO (pra tudo entrar no PATH)."
  say " 2) No terminal novo, digite:   claude"
  say " 3) Dentro do Claude, rode:     /bsaios-core:ecc-guide"
fi
say ""
exit 0
