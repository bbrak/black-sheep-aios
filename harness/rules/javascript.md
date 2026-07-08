---
paths: ["**/*.js", "**/*.ts", "**/*.tsx", "**/*.jsx", "**/*.mjs"]
---

# JavaScript / TypeScript Rules

## Preferences
- TypeScript over plain JS for new files when the project uses TS
- Prefer `interface` over `type` for object shapes
- Use `const` by default, `let` only when reassignment is needed, never `var`
- Async/await over raw Promises for readability
- No `any` type — use `unknown` and narrow if needed

## Frameworks
- Follow existing patterns in the codebase before introducing new ones
- Check if a utility already exists before creating a new one

## Testing
- Unit tests go next to source files when that's the project convention
- Integration tests belong in a dedicated `tests/` or `__tests__/` folder
