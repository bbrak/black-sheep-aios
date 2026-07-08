# Security Rules

## Credentials
- Never include API keys, passwords, or tokens in code, commits, or chat
- Never read `.credentials.json` or `.env` files unless explicitly asked
- Credentials belong in environment variables — not in source code
- If a path contains "credential", "secret", "token", ".env" — ask before reading

## Destructive Operations — Always Confirm First
- rm -rf on any non-temp directory
- git reset --hard
- git push --force to main/master
- DROP TABLE or equivalent destructive DB queries
- Modifying CI/CD pipelines
- chmod -R broadly

## External Services
- Never send data to external URLs without confirmation
- Never post to Slack, email, GitHub, or social media without explicit instruction
