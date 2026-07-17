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

# Falha REAL (a instalacao ficou incompleta), em oposicao ao warn, que e aviso ou degradacao aceitavel.
# O done-signal la embaixo le este contador: sem ele, "TUDO PRONTO" mente numa maquina onde nada foi
# instalado.
FAILED=0
fail() { FAILED=$((FAILED+1)); printf '  \033[31m[XX]\033[0m %s\n' "$*"; }

# Instalador que falha mudo vira "nao consegui" sem diagnostico. Caminho feliz silencioso; na falha,
# mostra o fim da saida real.
run_logged() { # <label> <cmd>
  local label="$1" cmd="$2" log="" rc=0
  log="$(mktemp -t bsaios)" || { bash -c "$cmd"; return $?; }
  bash -c "$cmd" >"$log" 2>&1 || rc=$?
  if [ "$rc" -ne 0 ]; then
    warn "$label falhou (exit $rc) — ultimas linhas:"
    tail -8 "$log" | sed 's/^/      /'
  fi
  rm -f "$log"
  return "$rc"
}

# Apple Silicon vs Intel: onde o Homebrew mora.
if [ "$(uname -m)" = "arm64" ]; then BREW_PREFIX="/opt/homebrew"; else BREW_PREFIX="/usr/local"; fi
load_brew() { [ -x "$BREW_PREFIX/bin/brew" ] && eval "$("$BREW_PREFIX/bin/brew" shellenv)"; }
# Cria o dir alem de po-lo no PATH: e onde o claude nativo e o 'uv tool install' (graphify) escrevem,
# e se ele nao existe esses instaladores podem falhar antes de cria-lo.
ensure_local_bin() {
  mkdir -p "$HOME/.local/bin" 2>/dev/null || true
  case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
}

# Presenca != funcionamento: um brew cujo Xcode CLT sumiu (comum apos upgrade do macOS) continua
# existindo como arquivo executavel e passa num teste -x, mas morre em toda invocacao.
brew_works() {
  if [ -x "$BREW_PREFIX/bin/brew" ] && "$BREW_PREFIX/bin/brew" --version >/dev/null 2>&1; then return 0; fi
  if have brew && brew --version >/dev/null 2>&1; then return 0; fi
  return 1
}

# Grava nos rc dos DOIS tipos de shell interativo, idempotente por arquivo:
#   - ~/.zprofile  → shell de LOGIN (Terminal.app abre assim)
#   - ~/.zshrc     → shell INTERATIVO (o terminal do VS Code e non-login e le SO o .zshrc)
# O terminal do VS Code — que o README manda usar — nao le o .zprofile. Gravar so nele fazia o PATH
# nunca carregar ali: a pessoa via 'claude: command not found' mesmo com tudo instalado. Um login
# shell le os dois; o brew shellenv rodar 2x e inofensivo (idempotente).
# BSAIOS_PROFILE: costura de teste — aponta para um unico arquivo no sandbox e nao toca os rc reais.
append_profile() { # <needle> <linha>
  local needle="$1" line="$2" f targets
  if [ -n "${BSAIOS_PROFILE:-}" ]; then targets="$BSAIOS_PROFILE"; else targets="$HOME/.zprofile $HOME/.zshrc"; fi
  for f in $targets; do
    [ -f "$f" ] || touch "$f"
    grep -qF "$needle" "$f" 2>/dev/null || printf '\n%s\n' "$line" >> "$f"
  done
}

# A agulha tem de casar com a linha GRAVADA, ou o append deixa de ser idempotente. A linha guarda
# "$HOME" LITERAL (melhor que cravar o caminho absoluto no perfil de quem instala), entao a agulha
# tambem precisa ser literal: com "$HOME" expandido ela procurava "/Users/<voce>/.local/bin" numa
# linha que diz "$HOME/.local/bin", nunca casava, e o perfil ganhava uma linha nova A CADA execucao.
# (A do brew nao sofre disso: $BREW_PREFIX expande nos DOIS lados.)
LOCAL_BIN_NEEDLE='$HOME/.local/bin'
LOCAL_BIN_LINE='export PATH="$HOME/.local/bin:$PATH"'

say ""
say "== Black Sheep AIOS — instalacao automatica (macOS) =="
say "   Instala, SO SE FALTAR: Homebrew, git, node, uv, python, jq, VS Code, Claude Code, e o harness em $DIR."
say "   Cada passo avisa antes de agir e CONTINUA mesmo se um item falhar (nada fica pela metade)."
[ $DRY_RUN -eq 1 ] && say "   (DRY-RUN: nada sera instalado — apenas mostro o que faria.)"
say ""

# ---------------------------------------------------------------- 1. Homebrew (gerenciador de pacotes)
say "[1/5] Homebrew"
if brew_works; then
  load_brew; hash -r; ok "Homebrew ja instalado"
elif [ -x "$BREW_PREFIX/bin/brew" ] || have brew; then
  # Existe mas nao executa. Quase sempre e o Xcode CLT ausente/quebrado (tipico depois de um upgrade
  # do macOS). Sem este ramo, os brew_pkg abaixo falhariam um a um sem nunca dizer a causa.
  fail "o Homebrew existe em $BREW_PREFIX mas NAO executa — quase sempre e o Xcode Command Line Tools."
  warn "  Rode:  xcode-select --install    e depois este instalador de novo."
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
    load_brew; hash -r
    append_profile "$BREW_PREFIX/bin/brew shellenv" "eval \"\$($BREW_PREFIX/bin/brew shellenv)\""
    ok "Homebrew instalado (PATH carregado nesta sessao + gravado no ~/.zprofile)"
  else
    fail "Homebrew falhou — sem ele, git/node/uv/python/jq nao serao instalados."
    warn "  Instale manualmente e rode este bootstrap de novo:"
    warn '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  fi
fi

# ---------------------------------------------------------------- 2. pre-requisitos (via brew, so o que faltar)
say ""
say "[2/5] VS Code + pre-requisitos (git, node, uv, python, jq)"
brew_pkg() { # <bin> <formula>
  # Executa, nao so localiza: num Mac zerado /usr/bin/git e /usr/bin/python3 sao stubs do Xcode CLT
  # que 'have' encontra mas que nao rodam. Confiar em 'have' aqui imprimia "[ok] git ja instalado"
  # em verde e derrubava o clone dois passos depois — a mesma tese que brew_works() ja aplica ao brew.
  if "$1" --version >/dev/null 2>&1; then ok "$1 ja instalado"; return; fi
  if [ $DRY_RUN -eq 1 ]; then warn "$1 ausente (dry-run) — faria: brew install $2"; return; fi
  brew_works || { fail "$1 ausente e sem Homebrew funcionando. Depois: brew install $2"; return; }
  info "instalando $1 (brew install $2) — pode levar alguns minutos; o progresso aparece abaixo."
  # Streaming ao vivo (nao run_logged): um 'brew install node' puxa dezenas de MB e ficaria minutos
  # mudo se a saida fosse so capturada — a leiga leria isso como travamento. O 'tee' mostra o brew na
  # tela E guarda um log p/ o diagnostico de falha; pipefail (set no topo) preserva o exit do brew.
  local blog; blog="$(mktemp -t bsaios)" || blog=""
  if [ -n "$blog" ] && brew install "$2" 2>&1 | tee "$blog"; then
    load_brew; hash -r
    have "$1" && ok "$1 instalado" || warn "$1 instalou mas nao esta no PATH — reabra o terminal"
  elif [ -z "$blog" ] && brew install "$2"; then
    load_brew; hash -r
    have "$1" && ok "$1 instalado" || warn "$1 instalou mas nao esta no PATH — reabra o terminal"
  else
    fail "$1 falhou — tente manualmente: brew install $2"
  fi
  [ -n "$blog" ] && rm -f "$blog"
}
brew_pkg git     git
brew_pkg node    node
brew_pkg uv      uv       # graphify instala via 'uv tool install'
brew_pkg python3 python   # hook validate-agent-frontmatter (PyYAML)
brew_pkg jq      jq       # team-os descobre agents de plugins (fail-soft sem ele)

# O uv tem instalador proprio da Astral. Sem este fallback, um brew ausente/quebrado leva o graphify
# junto — e o graphify e a unica das tres ferramentas externas que nao tem outro caminho.
# Paridade com o Windows, onde o uv tem dois caminhos (winget e scoop) — ver bootstrap.ps1:100.
if ! have uv && [ $DRY_RUN -eq 0 ]; then
  info "uv ausente — tentando o instalador oficial (astral.sh)..."
  if run_logged "uv (astral.sh)" "curl -LsSf https://astral.sh/uv/install.sh | sh"; then
    ensure_local_bin; hash -r
    append_profile "$LOCAL_BIN_NEEDLE" "$LOCAL_BIN_LINE"
  fi
  have uv && ok "uv instalado (astral.sh)" || warn "uv indisponivel — o graphify sera pulado (o resto funciona)"
fi

# VS Code — editor onde o time trabalha (terminal integrado + Claude Code). Cask, nao formula.
# Arrastar o app para /Applications (o que o Passo 1 do README manda fazer) NAO instala o comando
# 'code' no PATH. Sem checar o .app, o cask abaixo tenta instalar por cima de um app existente e
# falha — logo depois da pessoa ter instalado o VS Code com sucesso. Detecte o app, nao so o CLI.
VSCODE_APP="/Applications/Visual Studio Code.app"
if have code; then ok "VS Code ja instalado"
elif [ -d "$VSCODE_APP" ]; then
  ok "VS Code ja instalado (app em /Applications)"
  info "o comando 'code' nao esta no PATH, mas isso e opcional — voce ja trabalha dentro do VS Code."
elif [ $DRY_RUN -eq 1 ]; then warn "VS Code ausente (dry-run) — faria: brew install --cask visual-studio-code"
else
  info "instalando VS Code..."
  if run_logged "VS Code" "brew install --cask visual-studio-code"; then ok "VS Code instalado"
  else warn "VS Code falhou (fail-soft) — baixe manual: https://code.visualstudio.com"; fi
fi

# ---------------------------------------------------------------- 3. Claude Code
say ""
say "[3/5] Claude Code"
# INCONDICIONAL, de proposito: ~/.local/bin e onde caem TANTO o claude nativo QUANTO os bins do
# 'uv tool install' (o graphify). Quando isto vivia so no ramo "instalei o claude agora", uma maquina
# que ja tinha o claude por outra via nunca ganhava o PATH — e o graphify quebrava depois, no
# install.sh, de forma permanente (nem o ~/.zprofile era corrigido). Ambos os helpers sao idempotentes.
ensure_local_bin; hash -r
[ $DRY_RUN -eq 0 ] && append_profile "$LOCAL_BIN_NEEDLE" "$LOCAL_BIN_LINE"
if have claude; then
  ok "Claude Code ja instalado ($(claude --version 2>/dev/null || echo '?'))"
elif [ $DRY_RUN -eq 1 ]; then
  warn "claude ausente (dry-run) — faria: curl -fsSL https://claude.ai/install.sh | bash"
else
  info "instalando o Claude Code... (o download aparece abaixo)"
  # Deixa a saida do instalador do Claude VISIVEL (nao engole): se falhar, o motivo fica na tela.
  # pipefail (set no topo) faz o exit do curl OU do bash derrubar o if — sem mascarar erro de rede.
  if curl -fsSL https://claude.ai/install.sh | bash; then :; else
    fail "o instalador do Claude Code falhou (veja o erro acima; costuma ser rede)."
    warn "  Tente de novo, manual: curl -fsSL https://claude.ai/install.sh | bash"
  fi
  ensure_local_bin; hash -r
  if have claude; then
    ok "Claude Code instalado ($(claude --version 2>/dev/null || echo '?'))"
  else
    fail "o Claude Code nao aparece no PATH nesta sessao (dor conhecida D3). Ja ajustei o PATH;"
    warn "  se ainda nao achar, reabra o terminal. Manual: curl -fsSL https://claude.ai/install.sh | bash"
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
elif git --version >/dev/null 2>&1; then
  info "clonando o harness ($REF) em $DIR..."
  if git clone -q --branch "$REF" "$REPO_URL" "$DIR" 2>/dev/null || run_logged "git clone" "git clone -q '$REPO_URL' '$DIR'"; then
    ok "harness clonado em $DIR"
  else
    fail "git clone falhou — veja o erro acima (rede, ou Xcode CLT ausente: xcode-select --install). Rode de novo."
  fi
else
  fail "git ausente — nao da pra clonar. Instale o git (passo 2) e rode o bootstrap de novo."
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
  bash "$INSTALL" ${ARGS[@]+"${ARGS[@]}"} || fail "install.sh reportou problema (veja acima)."
else
  fail "nao encontrei $INSTALL — o clone do harness pode ter falhado. Rode o bootstrap de novo."
fi

# ---------------------------------------------------------------- done-signal (dor N4/N8: sem sinal de fim)
# O done-signal le o contador de falhas: dizer "TUDO PRONTO" numa maquina onde o Homebrew morreu e
# nada foi instalado e pior que nao dizer nada — manda a pessoa embora achando que deu certo.
say ""
if [ "$FAILED" -gt 0 ]; then
  say "============================================================"
  say " INSTALACAO INCOMPLETA — $FAILED etapa(s) falharam."
  say "============================================================"
  say " Reveja as linhas [XX] em vermelho acima: cada uma diz o comando pra resolver."
  say " Depois de resolver, rode este mesmo comando de novo (ele nao duplica nada)."
  say ""
  say " Travou? Cole o prompt do assistente de instalacao num Claude (claude.ai):"
  say " https://github.com/bbrak/black-sheep-aios/blob/stable/assist/INSTALL-ASSIST-PROMPT.md"
  say ""
  exit 1
fi
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
