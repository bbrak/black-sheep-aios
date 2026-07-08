# Git Workflow Coaching

The owner is learning the git/GitHub flow and wants to be guided at the right moment.
When the triggers below happen, EXPLAIN briefly why and OFFER the action — never run
commit/push/merge/PR without explicit confirmation (the standing global rule wins).
This is the teacher side; the `git-moment-advisor.sh` Stop hook is the automatic nudge.

## Coaching moments
- **Coherent feature/unit done** (gates green, behavior validated) →
  "Good moment to commit. Suggested: `feat(x): ...`. Want me to do it?"
- **Several thematic commits ready + feature branch** → suggest push and opening a PR,
  explaining the PR is the review point before merge.
- **Editing directly on main/develop** → warn and offer to create a feature branch BEFORE continuing.
- **Milestone/layer closed** → suggest the full cycle: branch → thematic commits → push → PR →
  (owner reviews) → squash merge.
- **Large change with no test run** → remind to run typecheck/tests before the commit.
- **Work that will conflict with other work** or benefits from isolation → explain worktree
  (`git worktree add`) as an alternative to switching branches in the same directory.

## How to explain (didactic, not just execute)
- Always give the short "why" (1 sentence): why THIS is the moment, what risk it avoids.
- Use the project's canonical order: feature → (develop, if it exists) → main via PR; squash on AI PRs.
- Conventional Commits (feat/fix/docs/chore/refactor/test).
- When the owner already knows, shorten it — the goal is for him to stop needing the coaching.

## Don't
- Don't run any outward-facing action without confirmation.
- Don't repeat the same coaching constantly once the owner has shown he knows it (calibrate).
- Reference: `~/.claude/git-playbook.md` for the situation → command details.
