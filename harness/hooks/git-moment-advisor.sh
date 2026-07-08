#!/usr/bin/env bash
# git-moment-advisor — suggests the right moment for git actions. Read-only, never acts.
# Runs on the Stop event. Silent unless a real trigger fires. Emits at most 2 nudges.

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

branch=$(git branch --show-current 2>/dev/null || echo "")
dirty=$(git status --porcelain 2>/dev/null | grep -c '' || echo 0)
msgs=()

# Trigger 3 — editing directly on a protected branch (highest priority)
case "$branch" in
  main|master|develop)
    [ "$dirty" -gt 0 ] && msgs+=("⚠️ Editando direto na '$branch' — crie uma feature branch antes de seguir (git switch -c feature/...).")
    ;;
esac

# Trigger 4 — commits not pushed
if git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
  ahead=$(git rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
  [ "$ahead" -gt 0 ] && msgs+=("🚀 $ahead commit(s) não pushado(s) — git push quando a unidade estiver coerente.")
fi

# Trigger 1 — many uncommitted files
[ "$dirty" -ge 15 ] && msgs+=("📦 $dirty arquivos sem commit — bom momento para commitar em unidades temáticas.")

# Trigger 2 — dirty tree and last commit is old (> 2h heuristic)
if [ "$dirty" -gt 0 ]; then
  last_epoch=$(git log -1 --format=%ct 2>/dev/null || echo "")
  now_epoch=$(date +%s 2>/dev/null || echo "")
  if [ -n "$last_epoch" ] && [ -n "$now_epoch" ]; then
    age=$(( now_epoch - last_epoch ))
    [ "$age" -gt 7200 ] && msgs+=("⏳ Trabalho não commitado acumulando (último commit há $(( age / 3600 ))h) — considere um commit de checkpoint.")
  fi
fi

# Trigger 5 — feature/fix branch pushed without an open PR (network; cached 5 min, tolerant)
if command -v gh >/dev/null 2>&1 && [ -n "$branch" ]; then
  case "$branch" in
    feature/*|fix/*)
      if git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
        cache_dir="${TMPDIR:-/tmp}"
        safe_branch=$(printf '%s' "$branch" | tr '/' '_')
        cache_file="$cache_dir/git-advisor-pr-${safe_branch}.cache"
        pr=""
        if [ -f "$cache_file" ]; then
          cached_at=$(head -1 "$cache_file" 2>/dev/null || echo 0)
          now_epoch=$(date +%s 2>/dev/null || echo 0)
          if [ $(( now_epoch - cached_at )) -lt 300 ]; then
            pr=$(tail -1 "$cache_file" 2>/dev/null || echo "")
          fi
        fi
        if [ -z "$pr" ]; then
          pr=$(gh pr list --head "$branch" --json number --jq 'length' 2>/dev/null || echo "")
          if [ -n "$pr" ]; then
            { date +%s 2>/dev/null || echo 0; printf '%s\n' "$pr"; } > "$cache_file" 2>/dev/null || true
          fi
        fi
        [ "$pr" = "0" ] && msgs+=("🔀 Branch '$branch' pushado sem PR — gh pr create quando quiser revisão/merge.")
      fi
      ;;
  esac
fi

# Emit at most 2 (order above already prioritizes: protected branch > push > volume > age > PR)
if [ "${#msgs[@]}" -gt 0 ]; then
  printf '\n— git advisor —\n'
  for m in "${msgs[@]:0:2}"; do printf '%s\n' "$m"; done
fi

exit 0
