# General Rules

## Task Behavior
- Never commit unless the user explicitly says "commit" or "faça o commit"
- Never push to remote unless explicitly asked
- Never amend published commits — create new ones
- Confirm before any destructive operation (delete files, reset --hard, drop tables)
- One task in_progress at a time when using TodoWrite

## Responses
- Concise — one clear sentence beats a vague paragraph
- State results directly, don't narrate internal reasoning
- No filler phrases ("Certainly!", "Great question!", "Of course!")
- End-of-turn summary: one or two sentences max
- Use markdown links for file references: [filename.ts](path/to/file.ts)

## Code Approach
- Prefer editing existing files over creating new ones
- Don't add features beyond what was explicitly asked
- No emojis in code or files unless asked
- No backwards-compatibility hacks for removed code

## GitHub
- `gh repo create` uses the gh **active** account, not the folder you are in. Before running it:
  - Check the active account: `gh auth status`
  - If wrong, pass `--owner <account>` explicitly, or switch first: `gh auth switch -u <account>`
- Always confirm with the user before creating a public repo or pushing to a new remote.
