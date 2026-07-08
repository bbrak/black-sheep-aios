# Failure Prevention

Mandatory checks before claiming work is complete.

## Before Saying "Done"
- [ ] Run the relevant tests/linter if they exist
- [ ] Verify the actual output matches the expected behavior (don't just assume)
- [ ] Check that no unrelated files were accidentally modified
- [ ] Confirm no credentials or secrets appear in changed files

## Known Failure Patterns (update as discovered)
- Verifying work is done without actually running it → always run, report actual output
- Claiming tests pass without executing them → execute and show output
- Editing the wrong file because of similar names → double-check path before editing
