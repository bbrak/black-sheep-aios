#!/usr/bin/env bash
# list-teammates.sh — enumera todos os agentes disponíveis dos 4 escopos
# Output: tabela tab-separated: nome<TAB>description<TAB>scope
# Precedência de nome: project > user > plugin. Built-ins sempre listados.
# Scopes: project | user | plugin:{nome} | builtin

SEEN=" "

extract_field() {
  local file="$1"
  local field="$2"
  awk -v field="$field" '
    BEGIN { in_fm = 0; found = 0 }
    /^---$/ {
      if (in_fm == 0) { in_fm = 1; next }
      else { exit }
    }
    in_fm && $0 ~ "^" field ":" {
      sub("^" field ":[[:space:]]*", "")
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      print
      found = 1
      exit
    }
  ' "$file"
}

emit_dir() {
  local dir="$1"
  local scope="$2"
  [ -d "$dir" ] || return 0
  for f in "$dir"/*.md; do
    [ -f "$f" ] || continue
    case "$f" in *.tmpl) continue ;; esac
    name=$(extract_field "$f" "name")
    [ -z "$name" ] && name=$(basename "$f" .md)
    desc=$(extract_field "$f" "description")
    case "$SEEN" in *" $name "*) continue ;; esac
    SEEN="$SEEN$name "
    printf "%s\t%s\t%s\n" "$name" "$desc" "$scope"
  done
}

# 1. Project scope (prioridade máxima)
emit_dir ".claude/agents" "project"

# 2. User scope
emit_dir "$HOME/.claude/agents" "user"

# 3. Plugin scope — só plugins habilitados em settings.json
#    enabledPlugins: {"{plugin}@{marketplace}": true} → cache/{marketplace}/{plugin}/{version}/agents/
#    Nome de spawn é namespaced: {plugin}:{agent} (subagent_type exige o namespace)
SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ] && command -v jq >/dev/null 2>&1; then
  jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$SETTINGS" 2>/dev/null | tr -d '\r' |
  while IFS= read -r entry; do
    plugin="${entry%@*}"
    marketplace="${entry#*@}"
    for vdir in "$HOME/.claude/plugins/cache/$marketplace/$plugin"/*/; do
      [ -d "${vdir}agents" ] || continue
      for f in "${vdir}agents"/*.md; do
        [ -f "$f" ] || continue
        case "$f" in *.tmpl) continue ;; esac
        name=$(extract_field "$f" "name")
        [ -z "$name" ] && name=$(basename "$f" .md)
        desc=$(extract_field "$f" "description")
        printf "%s\t%s\t%s\n" "${plugin}:${name}" "$desc" "plugin:${plugin}"
      done
    done
  done
fi

# 4. Built-ins do harness (sempre disponíveis, all-tools, SendMessage OK)
printf "general-purpose\tAgente genérico para pesquisa, buscas e tarefas multi-step\tbuiltin\n"
printf "Explore\tBusca read-only em larga escala no codebase (não edita)\tbuiltin\n"
printf "Plan\tArquiteto de planos de implementação (não edita)\tbuiltin\n"
