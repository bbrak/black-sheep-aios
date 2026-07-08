#!/usr/bin/env bash
# Black Sheep AIOS — instalador macOS
# Uso:  ./install.sh [--claude-home <dir>] [--dry-run] [--name "..."] [--role "..."] [--focus "..."]
#
# O que faz:
#   1. Checa pre-requisitos (git, node, python3, uv, claude) e ferramentas externas (rtk, graphify,
#      agent-browser). NAO instala nada sozinho: imprime o comando certo do manifest.json.
#   2. Copia o harness para ~/.claude (backup de tudo que for sobrescrito).
#   3. Copia plugins/ para ~/.claude/plugins/bsaios-marketplace (plugin vendorizado bsaios-core).
#   4. Gera ~/.claude/settings.json e ~/.claude/CLAUDE.md a partir dos templates (GateGuard ON;
#      no macOS o hook automatico do RTK fica LIGADO).
#   5. Instala PyYAML (hook validate-agent-frontmatter) — pulado no --dry-run.
#
# --dry-run: exige --claude-home, nao pergunta nada, nao instala pacote, nao roda rtk init.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

CLAUDE_HOME="$HOME/.claude"
DRY_RUN=0
NAME=""; ROLE=""; FOCUS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --claude-home) CLAUDE_HOME="$2"; shift 2 ;;
    --dry-run)     DRY_RUN=1; shift ;;
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

say ""
say "== Black Sheep AIOS — instalador macOS =="
say "   repo:        $REPO_DIR"
say "   CLAUDE_HOME: $CLAUDE_HOME $([ $DRY_RUN -eq 1 ] && echo '(DRY-RUN)')"
say ""

# ---------------------------------------------------------------- 1. pre-requisitos
say "[1/5] Pre-requisitos"
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
need "rtk"          "rtk --version"          "curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh && rtk init -g   (fail-soft: pode instalar depois)"
need "graphify"     "graphify --version"     "uv tool install graphifyy && graphify install && graphify claude install   (opcional)"
need "agent-browser" "agent-browser --version" "npm install -g agent-browser && agent-browser install && npx skills add vercel-labs/agent-browser   (opcional)"

# git e node sao obrigatorios para o proprio instalador
command -v node >/dev/null 2>&1 || { echo "ERRO: node e obrigatorio para o instalador."; exit 1; }
[ $MISSING -gt 0 ] && warn "$MISSING item(ns) ausente(s) — o instalador segue; instale-os depois (lista completa: install/manifest.json)."

# ---------------------------------------------------------------- 2. harness -> CLAUDE_HOME
say ""
say "[2/5] Harness -> $CLAUDE_HOME"
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
chmod +x "$CLAUDE_HOME/hooks/git-moment-advisor.sh" 2>/dev/null || true

# ---------------------------------------------------------------- 3. plugin vendorizado
say ""
say "[3/5] Plugin bsaios-core -> $CLAUDE_HOME/plugins/bsaios-marketplace"
MARKET="$CLAUDE_HOME/plugins/bsaios-marketplace"
if [ -e "$MARKET" ]; then mkdir -p "$BACKUP/plugins"; cp -R "$MARKET" "$BACKUP/plugins/bsaios-marketplace"; rm -rf "$MARKET"; fi
mkdir -p "$MARKET"
cp -R "$REPO_DIR/plugins/." "$MARKET/"
ok "marketplace por diretorio copiado ($(ls "$MARKET/bsaios-core/skills" | wc -l | tr -d ' ') skills no plugin; os agents vao para agents/ do CLAUDE_HOME)"

# ---------------------------------------------------------------- 4. settings + CLAUDE.md
say ""
say "[4/5] Gerando settings.json e CLAUDE.md"
if [ $DRY_RUN -eq 0 ] && [ -z "$NAME" ]; then
  read -r -p "  Seu nome: " NAME || NAME=""
  read -r -p "  Sua funcao: " ROLE || ROLE=""
  read -r -p "  Areas de foco: " FOCUS || FOCUS=""
fi
RENDER="$SCRIPT_DIR/lib/render-settings.js"
ARGS=(--claude-home "$CLAUDE_HOME" --platform mac)
[ -n "$NAME"  ] && ARGS+=(--name  "$NAME")
[ -n "$ROLE"  ] && ARGS+=(--role  "$ROLE")
[ -n "$FOCUS" ] && ARGS+=(--focus "$FOCUS")

[ -f "$CLAUDE_HOME/settings.json" ] && { mkdir -p "$BACKUP"; cp "$CLAUDE_HOME/settings.json" "$BACKUP/settings.json"; }
node "$RENDER" "$REPO_DIR/harness/settings.team.json" "$CLAUDE_HOME/settings.json" "${ARGS[@]}"
[ -f "$CLAUDE_HOME/CLAUDE.md" ] && { mkdir -p "$BACKUP"; cp "$CLAUDE_HOME/CLAUDE.md" "$BACKUP/CLAUDE.md"; }
node "$RENDER" "$REPO_DIR/harness/CLAUDE.md.template" "$CLAUDE_HOME/CLAUDE.md" "${ARGS[@]}"
ok "settings.json (GateGuard ON, hook rtk LIGADO no macOS)"
ok "CLAUDE.md"

# ---------------------------------------------------------------- 5. extras
say ""
say "[5/5] Extras"
if [ $DRY_RUN -eq 1 ]; then
  ok "dry-run: pulando PyYAML e rtk init"
else
  if python3 -c "import yaml" >/dev/null 2>&1; then ok "PyYAML ja presente"
  else
    python3 -m pip install --user --break-system-packages pyyaml >/dev/null 2>&1 \
      || python3 -m pip install --user pyyaml >/dev/null 2>&1 \
      || warn "nao consegui instalar PyYAML — o hook validate-agent-frontmatter fica inerte ate: python3 -m pip install --user pyyaml"
    python3 -c "import yaml" >/dev/null 2>&1 && ok "PyYAML instalado"
  fi
  if command -v rtk >/dev/null 2>&1; then rtk init -g >/dev/null 2>&1 && ok "rtk init -g" || warn "rtk init -g falhou (rode manualmente)"; fi
fi

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
