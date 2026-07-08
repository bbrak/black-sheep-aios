# Coding Standards

## General
- No comments unless the WHY is non-obvious (hidden constraint, workaround, subtle invariant)
- No multi-line docstrings or comment blocks — one short line max if needed
- Prefer smaller, focused files over large "god" files
- Files that change together should live together (split by responsibility, not layer)
- Three similar lines is better than a premature abstraction

## Architecture
- No half-finished implementations
- No feature flags for things that can just be changed
- No error handling for scenarios that can't happen
- Trust framework guarantees — only validate at system boundaries (user input, external APIs)
- Don't design for hypothetical future requirements (YAGNI)

## Naming
- Names should describe what, code should show how, comments explain why
- Avoid abbreviations unless they're industry-standard
