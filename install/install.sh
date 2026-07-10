#!/usr/bin/env bash
# Black Sheep AIOS — instalador macOS
# Uso:  ./install.sh [--claude-home <dir>] [--dry-run] [--yes] [--skip-tools] [--name "..."] [--role "..."] [--focus "..."]
#
# O que faz:
#   1. Checa pre-requisitos (git, node, python3, uv, jq, claude). NAO os instala: imprime o
#      comando certo do manifest.json (instalacao de linguagem/runtime fica a cargo do usuario).
#   2. Copia o harness para ~/.claude (backup de tudo que for sobrescrito).
#   3. Copia plugins/ para ~/.claude/plugins/bsaios-marketplace (plugin vendorizado bsaios-core).
#   4. Gera ~/.claude/settings.json e ~/.claude/CLAUDE.md a partir dos templates (GateGuard ON;
#      no macOS o hook automatico do RTK fica LIGADO). Se ja existirem, faz MERGE nao-destrutivo:
#      settings.json = deep-merge (preserva permissoes/MCPs/statusline do usuario); CLAUDE.md =
#      bloco gerenciado (so o bloco BSAIOS e trocado; sua identidade e customizacoes ficam intactas).
#   5. Ferramentas externas (rtk, graphify, agent-browser): para cada uma AUSENTE, PERGUNTA e
#      instala o comando do SO (fail-soft se recusar/falhar). rtk: brew install rtk (+ rtk init -g).
#   6. Instala PyYAML (hook validate-agent-frontmatter) — pulado no --dry-run.
#   7. Grava ~/.claude/.bsaios/{version,profile,manifest.installed}.json (ancora de versao +
#      identidade cacheada + inventario para prune) — ULTIMO passo bem-sucedido.
#
# --dry-run:    exige --claude-home, nao pergunta nada, nao instala pacote, nao roda rtk init
#               (usa uma identidade de teste para o render nao recusar por placeholder).
# --yes:        aceita automaticamente a instalacao das ferramentas externas (nao interativo).
# --skip-tools: nao instala ferramentas externas (so avisa quais faltam).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

CLAUDE_HOME="$HOME/.claude"
DRY_RUN=0
ASSUME_YES=""
SKIP_TOOLS=0
NAME=""; ROLE=""; FOCUS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --claude-home) CLAUDE_HOME="$2"; shift 2 ;;
    --dry-run)     DRY_RUN=1; shift ;;
    --yes|-y)      ASSUME_YES=1; shift ;;
    --skip-tools)  SKIP_TOOLS=1; shift ;;
    --name)        NAME="$2"; shift 2 ;;
    --role)        ROLE="$2"; shift 2 ;;
    --focus)       FOCUS="$2"; shift 2 ;;
    -h|--help)     grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "flag desconhecida: $1"; exit 1 ;;
  esac
done

say()  { printf '%s\n' "$*"; }
ok()   { printf '  \033[32m[ok]\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m[!!]\033[0m %s\n' "$*"; }

# ext_tool <id> <check-cmd> <install-cmd> [post-install-cmd]
# Instala uma ferramenta externa AUSENTE: pergunta (a menos que --yes), instala, verifica e roda o post.
# Fail-soft em qualquer ponto: avisa e segue, nunca aborta o instalador.
ext_tool() {
  local id="$1" check="$2" inst="$3" post="${4:-}"
  if bash -c "$check" >/dev/null 2>&1; then ok "$id (ja instalado)"; return; fi
  if [ "$SKIP_TOOLS" -eq 1 ]; then warn "$id ausente (--skip-tools) — instale depois: $inst"; return; fi
  if [ "$DRY_RUN" -eq 1 ]; then warn "$id ausente (dry-run: nao instala) — comando: $inst"; return; fi
  local ans=""
  if [ -n "$ASSUME_YES" ]; then ans="y"
  elif [ -t 0 ]; then read -r -p "  $id ausente. Instalar agora com '$inst'? [Y/n] " ans || ans="n"
  else warn "$id ausente (sem terminal p/ perguntar; use --yes) — instale depois: $inst"; return; fi
  case "${ans:-y}" in [nN]*) warn "$id pulado (fail-soft) — instale depois: $inst"; return ;; esac
  say "  instalando $id..."
  if bash -c "$inst"; then
    if bash -c "$check" >/dev/null 2>&1; then
      ok "$id instalado"
      [ -n "$post" ] && { bash -c "$post" >/dev/null 2>&1 && ok "$post" || warn "'$post' falhou (rode manualmente)"; }
    else
      warn "$id: instalou mas '$check' ainda falha — verifique o PATH (ex.: ~/.local/bin) e reabra o terminal"
    fi
  else
    warn "$id: instalacao falhou (fail-soft) — tente manualmente: $inst"
  fi
}

say ""
say "== Black Sheep AIOS — instalador macOS =="
say "   repo:        $REPO_DIR"
say "   CLAUDE_HOME: $CLAUDE_HOME $([ $DRY_RUN -eq 1 ] && echo '(DRY-RUN)')"
say ""

# ---------------------------------------------------------------- 1. pre-requisitos
say "[1/7] Pre-requisitos"
MISSING=0
need() { # need <id> <cmd de teste> <como instalar>
  if bash -c "$2" >/dev/null 2>&1; then ok "$1"
  else warn "$1 AUSENTE — instale com: $3"; MISSING=$((MISSING+1)); fi
}
need "git"          "git --version"          "xcode-select --install"
need "node"         "node --version"         "brew install node"
need "python3"      "python3 --version"      "brew install python"
need "uv"           "uv --version"           "brew install uv"
need "jq"           "jq --version"           "brew install jq   (recomendado: team-os usa p/ descobrir agents de plugin)"
need "claude"       "claude --version"       "curl -fsSL https://claude.ai/install.sh | bash"

# git e node sao obrigatorios para o proprio instalador
command -v node >/dev/null 2>&1 || { echo "ERRO: node e obrigatorio para o instalador."; exit 1; }
[ $MISSING -gt 0 ] && warn "$MISSING item(ns) ausente(s) — o instalador segue; instale-os depois (lista completa: install/manifest.json)."

# ---------------------------------------------------------------- 2. harness -> CLAUDE_HOME
say ""
say "[2/7] Harness -> $CLAUDE_HOME"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$CLAUDE_HOME/backups/bsaios-$STAMP"
mkdir -p "$CLAUDE_HOME"

backup_and_copy() { # <origem> <destino relativo a CLAUDE_HOME>
  local src="$1" rel="$2" dest="$CLAUDE_HOME/$2"
  if [ -e "$dest" ]; then
    mkdir -p "$BACKUP/$(dirname "$rel")"
    cp -R "$dest" "$BACKUP/$rel"
    rm -rf "$dest"   # evita aninhamento (cp -R dir sobre dir existente cria dest/dir)
  fi
  mkdir -p "$(dirname "$dest")"
  cp -R "$src" "$dest"
  ok "$rel"
}

backup_and_copy "$REPO_DIR/harness/RTK.md"                 "RTK.md"
backup_and_copy "$REPO_DIR/harness/statusline-command.js"  "statusline-command.js"
for d in "$REPO_DIR/harness/skills/"*/;  do backup_and_copy "$d" "skills/$(basename "$d")";  done
mkdir -p "$CLAUDE_HOME/agents"
for f in "$REPO_DIR/harness/agents/"*.md; do backup_and_copy "$f" "agents/$(basename "$f")"; done
backup_and_copy "$REPO_DIR/harness/hooks/git-moment-advisor.sh"        "hooks/git-moment-advisor.sh"
backup_and_copy "$REPO_DIR/harness/hooks/validate-agent-frontmatter.py" "hooks/validate-agent-frontmatter.py"
backup_and_copy "$REPO_DIR/harness/hooks/team"             "hooks/team"
for f in "$REPO_DIR/harness/rules/"*.md; do backup_and_copy "$f" "rules/$(basename "$f")"; done
for f in "$REPO_DIR/harness/commands/"*.md; do backup_and_copy "$f" "commands/$(basename "$f")"; done
chmod +x "$CLAUDE_HOME/hooks/git-moment-advisor.sh" 2>/dev/null || true

# updater fora da sessao (bundle estavel) + wrappers de recuperacao -> ~/.claude/.bsaios/
mkdir -p "$CLAUDE_HOME/.bsaios/updater"
rm -rf "$CLAUDE_HOME/.bsaios/updater/lib" "$CLAUDE_HOME/.bsaios/updater/migrations"
cp -R "$REPO_DIR/install/lib"        "$CLAUDE_HOME/.bsaios/updater/lib"
cp -R "$REPO_DIR/install/migrations" "$CLAUDE_HOME/.bsaios/updater/migrations"
cp    "$REPO_DIR/install/manifest.json" "$CLAUDE_HOME/.bsaios/updater/manifest.json"
cp    "$REPO_DIR/harness/wrappers/"* "$CLAUDE_HOME/.bsaios/" 2>/dev/null || true
chmod +x "$CLAUDE_HOME/.bsaios/"*.command 2>/dev/null || true
ok "updater + wrappers (.bsaios/updater; /bsaios-update no chat)"

# ---------------------------------------------------------------- 3. plugin vendorizado
say ""
say "[3/7] Plugin bsaios-core -> $CLAUDE_HOME/plugins/bsaios-marketplace"
MARKET="$CLAUDE_HOME/plugins/bsaios-marketplace"
if [ -e "$MARKET" ]; then mkdir -p "$BACKUP/plugins"; cp -R "$MARKET" "$BACKUP/plugins/bsaios-marketplace"; rm -rf "$MARKET"; fi
mkdir -p "$MARKET"
cp -R "$REPO_DIR/plugins/." "$MARKET/"
ok "marketplace por diretorio copiado ($(ls "$MARKET/bsaios-core/skills" | wc -l | tr -d ' ') skills no plugin; os agents vao para agents/ do CLAUDE_HOME)"

# ---------------------------------------------------------------- 4. settings + CLAUDE.md
say ""
say "[4/7] Gerando settings.json e CLAUDE.md"
if [ $DRY_RUN -eq 1 ] && [ -z "$NAME" ]; then NAME="Dry Run"; ROLE="CI"; FOCUS="parity-check"; fi
if [ $DRY_RUN -eq 0 ] && [ -z "$NAME" ]; then
  read -r -p "  Seu nome: " NAME || NAME=""
  read -r -p "  Sua funcao: " ROLE || ROLE=""
  read -r -p "  Areas de foco: " FOCUS || FOCUS=""
fi
RENDER="$SCRIPT_DIR/lib/render-settings.js"
ARGS=(--claude-home "$CLAUDE_HOME" --platform mac --profile "$CLAUDE_HOME/.bsaios/profile.json")
[ -n "$NAME"  ] && ARGS+=(--name  "$NAME")
[ -n "$ROLE"  ] && ARGS+=(--role  "$ROLE")
[ -n "$FOCUS" ] && ARGS+=(--focus "$FOCUS")

[ -f "$CLAUDE_HOME/settings.json" ] && { mkdir -p "$BACKUP"; cp "$CLAUDE_HOME/settings.json" "$BACKUP/settings.json"; }
node "$RENDER" "$REPO_DIR/harness/settings.team.json" "$CLAUDE_HOME/settings.json" "${ARGS[@]}"
[ -f "$CLAUDE_HOME/CLAUDE.md" ] && { mkdir -p "$BACKUP"; cp "$CLAUDE_HOME/CLAUDE.md" "$BACKUP/CLAUDE.md"; }
node "$RENDER" "$REPO_DIR/harness/CLAUDE.md.template" "$CLAUDE_HOME/CLAUDE.md" "${ARGS[@]}"
ok "settings.json (GateGuard ON, hook rtk LIGADO no macOS; merge nao-destrutivo se ja existia)"
ok "CLAUDE.md (bloco gerenciado; identidade e customizacoes do usuario preservadas)"

# ---------------------------------------------------------------- 5. ferramentas externas
say ""
say "[5/7] Ferramentas externas (rtk, graphify, agent-browser)"
# rtk no macOS: metodo oficial recomendado e o Homebrew; cai para o instalador curl|sh se nao houver brew.
ext_tool "rtk" "rtk --version" \
  "brew install rtk || curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh" \
  "rtk init -g"
ext_tool "graphify" "graphify --version" \
  "uv tool install graphifyy && graphify install && graphify claude install"
ext_tool "agent-browser" "agent-browser --version" \
  "npm install -g agent-browser && agent-browser install && npx skills add vercel-labs/agent-browser"

# ---------------------------------------------------------------- 6. extras
say ""
say "[6/7] Extras"
if [ $DRY_RUN -eq 1 ]; then
  ok "dry-run: pulando PyYAML"
else
  if python3 -c "import yaml" >/dev/null 2>&1; then ok "PyYAML ja presente"
  else
    python3 -m pip install --user --break-system-packages pyyaml >/dev/null 2>&1 \
      || python3 -m pip install --user pyyaml >/dev/null 2>&1 \
      || warn "nao consegui instalar PyYAML — o hook validate-agent-frontmatter fica inerte ate: python3 -m pip install --user pyyaml"
    python3 -c "import yaml" >/dev/null 2>&1 && ok "PyYAML instalado"
  fi
fi

# ---------------------------------------------------------------- 7. estado (.bsaios) — ULTIMO passo
say ""
say "[7/7] Estado -> $CLAUDE_HOME/.bsaios"
STATE_ARGS=(--claude-home "$CLAUDE_HOME" --platform mac --repo "$REPO_DIR" --manifest "$REPO_DIR/install/manifest.json")
[ -n "$NAME" ]  && STATE_ARGS+=(--name  "$NAME")
[ -n "$ROLE" ]  && STATE_ARGS+=(--role  "$ROLE")
[ -n "$FOCUS" ] && STATE_ARGS+=(--focus "$FOCUS")
node "$SCRIPT_DIR/lib/bsaios-state.js" "${STATE_ARGS[@]}"
ok "version.json + profile.json + manifest.installed.json (carimbo por ultimo)"
node "$SCRIPT_DIR/lib/verify-harness.js" --claude-home "$CLAUDE_HOME" || warn "health check reportou problemas (veja acima) — o install foi concluido, mas verifique"

say ""
say "== Pronto =="
say "Backup do que foi sobrescrito: $BACKUP (se existia algo)"
say "Proximos passos:"
say "  1. claude doctor                  # saude do Claude Code"
say "  2. claude plugin list             # deve listar bsaios-core"
say "  3. abra uma sessao e rode /bsaios-core:ecc-guide para conhecer as skills"
say "MCPs opcionais (dieta de MCP — so se precisar):"
say "  claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp@latest"
say "  claude mcp add --scope user chrome-devtools -- npx -y chrome-devtools-mcp@latest"
exit 0
