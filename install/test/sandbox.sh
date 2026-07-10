#!/usr/bin/env bash
# Black Sheep AIOS — SANDBOX INTERATIVO (teste de colaborador no seu proprio Mac).
#
# Cria um "colega" num CLAUDE_CONFIG_DIR separado (NAO toca no seu ~/.claude real) e um "GitHub"
# local (remote file://). Voce publica uma skill nova como OWNER, abre o Claude Code como o colega,
# ve o BANNER e roda /bsaios-update DE VERDADE — tudo offline.
#
# Fluxo tipico:
#   bash install/test/sandbox.sh setup      # 1. monta o remote + instala o harness pro colega
#   bash install/test/sandbox.sh publish    # 2. como OWNER: sobe skill nova, sobe versao, avanca `stable`
#   bash install/test/sandbox.sh launch      # 3. imprime o comando pra abrir o Claude COMO o colega
#   bash install/test/sandbox.sh status      #    (opcional) versao instalada vs disponivel
#   bash install/test/sandbox.sh clean       # 4. apaga o sandbox inteiro
#
# Local do sandbox: $BSAIOS_SANDBOX (default ~/.bsaios-sandbox). Persiste entre os comandos.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SANDBOX="${BSAIOS_SANDBOX:-$HOME/.bsaios-sandbox}"
ORIGIN="$SANDBOX/origin"          # o "GitHub" (repo git local)
TEAM="$SANDBOX/teammate/.claude"  # o CLAUDE_CONFIG_DIR do colega
VERFILE="$SANDBOX/remote-VERSION" # VERSION publicado (seam do banner)

G()   { git -C "$ORIGIN" -c user.email=sandbox@test -c user.name=sandbox "$@"; }
say() { printf '%s\n' "$*"; }
die() { printf 'ERRO: %s\n' "$*" >&2; exit 1; }

need_setup() { [ -d "$TEAM/.bsaios" ] || die "sandbox nao existe. Rode primeiro: bash install/test/sandbox.sh setup"; }

cmd_setup() {
  command -v node >/dev/null 2>&1 || die "node e obrigatorio."
  say "== [1] Montando o sandbox em $SANDBOX =="
  rm -rf "$SANDBOX"; mkdir -p "$ORIGIN" "$TEAM"

  say "  - criando o 'GitHub' local (snapshot do repo = versao atual) + tags stable/latest"
  tar -C "$REPO" --exclude='./.git' --exclude='./.claude' -cf - . | tar -C "$ORIGIN" -xf -
  G init -q; G add -A; G commit -qm "sandbox base"; G tag -f stable >/dev/null; G tag -f latest >/dev/null
  G show stable:VERSION > "$VERFILE"

  say "  - instalando o harness pro colega (identidade de teste, sem prompt, sem PyYAML/rtk)"
  bash "$REPO/install/install.sh" --claude-home "$TEAM" --dry-run \
    --name "Colega Sandbox" --role "Head de IA" --focus "teste de update" >/dev/null 2>&1 \
    || die "install.sh falhou (rode sem redirecionar pra ver o motivo)."

  say "  - personalizando (model=opus) pra provar que o pessoal SOBREVIVE ao update"
  node -e "const f='$TEAM/settings.json';const j=require(f);j.model='opus';require('fs').writeFileSync(f,JSON.stringify(j,null,2))"

  say "  - primando o cache do banner (ainda sem novidade: instalado == publicado)"
  BSAIOS_VERSION_URL="$VERFILE" node "$TEAM/hooks/team/update-check.js" --refresh "$TEAM"

  say ""
  say "== Sandbox pronto. Versao instalada: $(cat "$VERFILE") =="
  say "Proximo: bash install/test/sandbox.sh publish   (sobe uma skill nova como OWNER)"
}

cmd_publish() {
  need_setup
  local cur next skill
  cur="$(node -e "console.log(require('$ORIGIN/install/manifest.json').version)")"
  next="$(node -e "const p='$cur'.split('.').map(Number);p[1]++;p[2]=0;console.log(p.join('.'))")"
  skill="sandbox-skill-$next"
  say "== [2] OWNER publica: skill '$skill' + versao $cur -> $next + avanca a tag stable =="

  local dir="$ORIGIN/plugins/bsaios-core/skills/$skill"
  mkdir -p "$dir"
  printf -- '---\nname: %s\ndescription: skill de teste do sandbox (v%s)\n---\n\nSe voce esta lendo isso, o /bsaios-update funcionou.\n' "$skill" "$next" > "$dir/SKILL.md"

  node -e "const f='$ORIGIN/install/manifest.json';const j=require(f);j.version='$next';require('fs').writeFileSync(f,JSON.stringify(j,null,2)+String.fromCharCode(10))"
  node "$ORIGIN/install/lib/sync-manifest.js" --write >/dev/null
  node -e "const fs=require('fs'),f='$ORIGIN/CHANGELOG.md';let s=fs.readFileSync(f,'utf8');const e='## ['+'$next'+'] — sandbox\n\n### Adicionado\n- Skill $skill (teste).\n\n';s=s.includes('## [Não lançado]')?s.replace('## [Não lançado]','## [Não lançado]\n\n'+e.trim()+'\n'):e+s;fs.writeFileSync(f,s)"

  G add -A; G commit -qm "feat: $skill (v$next)" >/dev/null; G tag -f stable >/dev/null; G tag -f latest >/dev/null
  G show stable:VERSION > "$VERFILE"

  say "  - atualizando o cache do banner do colega (refresh sincrono)"
  BSAIOS_VERSION_URL="$VERFILE" node "$TEAM/hooks/team/update-check.js" --refresh "$TEAM"

  say ""
  say "== Publicado v$next. O colega tem $(node -e "console.log(require('$TEAM/.bsaios/version.json').product_version)") =="
  say "Proximo: bash install/test/sandbox.sh launch   (abre o Claude como o colega e ve o banner)"
}

cmd_status() {
  need_setup
  local installed latest banner
  installed="$(node -e "console.log(require('$TEAM/.bsaios/version.json').product_version)")"
  latest="$(cat "$VERFILE" 2>/dev/null || echo '?')"
  banner="$(node -e "const {updateBannerLine}=require('$TEAM/hooks/team/update-check.js');console.log(updateBannerLine('$TEAM')||'(sem banner — atualizado)')")"
  say "== Status do sandbox =="
  say "  instalado no colega: v$installed"
  say "  publicado (stable):  v$latest"
  say "  banner na sessao:    $banner"
}

cmd_launch() {
  need_setup
  local gate=""
  [ "${1:-}" = "--no-gate" ] && gate="ECC_GATEGUARD=off "
  say "== [3] Abra o Claude Code COMO o colega =="
  say "Cole e rode ISTO num terminal (nao aqui dentro do Claude):"
  say ""
  say "  ${gate}BSAIOS_REPO_URL=\"file://$ORIGIN\" \\"
  say "  BSAIOS_VERSION_URL=\"$VERFILE\" \\"
  say "  BSAIOS_UPDATE_REF=stable \\"
  say "  CLAUDE_CONFIG_DIR=\"$TEAM\" \\"
  say "  claude"
  say ""
  say "Dentro dessa sessao:"
  say "  1. Na abertura, o BANNER deve anunciar a versao nova disponivel."
  say "  2. Rode  /bsaios-update  -> ele mostra o preview, voce responde 'sim'."
  say "  3. A skill nova chega; seu 'model=opus' continua intacto."
  say "  4. Se algo der errado:  /bsaios-rollback"
  say ""
  say "Obs: e uma sessao Claude de VERDADE, com GateGuard ON (o colega real veria igual)."
  say "     Pra um teste sem atrito, use:  bash install/test/sandbox.sh launch --no-gate"
}

cmd_clean() { rm -rf "$SANDBOX"; say "sandbox removido: $SANDBOX"; }

case "${1:-}" in
  setup)   cmd_setup ;;
  publish) cmd_publish ;;
  status)  cmd_status ;;
  launch)  shift; cmd_launch "${1:-}" ;;
  clean)   cmd_clean ;;
  *) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
