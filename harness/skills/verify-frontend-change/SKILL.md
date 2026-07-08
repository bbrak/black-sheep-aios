---
name: verify-frontend-change
description: Verify any UI change end-to-end before declaring it done — start the dev server, interact with the change in a real browser, check console errors, and audit Core Web Vitals. Use whenever a frontend/UI edit is about to be reported as complete.
---

# Verifying frontend changes

Never report a UI change as complete based on a successful edit alone. Verify it the way a human reviewer would.

## 1. Start the dev server and open the page

Start the project's dev server and open the edited page in the browser using the `agent-browser` CLI (default browser tool — do not use the Playwright MCP).

```
agent-browser open <url>
```

## 2. Interact with the change directly

Use `agent-browser snapshot -i` to get refs, then act on the actual control that changed (button, input, toggle, etc.):

```
agent-browser snapshot -i
agent-browser click @e1
agent-browser screenshot before.png
# perform the interaction
agent-browser screenshot after.png
```

Confirm the expected state change by comparing before/after, not just by assuming the click succeeded.

## 3. Check the browser console

Zero new errors or warnings. Inspect console output via `agent-browser` (or the chrome-devtools MCP if a deeper stack trace is needed) — do not skip this because the UI "looks right".

## 4. Audit performance with the chrome-devtools MCP

`agent-browser` does not do deep performance instrumentation — use the `chrome-devtools` MCP for this step specifically:

- Run a performance trace on the affected page.
- Check Core Web Vitals (LCP, CLS, INP) and confirm the change didn't regress them.
- If the MCP is not connected, run `claude mcp list` and add it at user scope: `claude mcp add --scope user chrome-devtools -- npx -y chrome-devtools-mcp@latest`.

## If any step fails

Fix the issue and rerun from step 1. Do not hand back partially verified work.
