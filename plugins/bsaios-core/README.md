# bsaios-core — plugin vendorizado

Plugin local do Black Sheep AIOS: **53 skills + hooks (GateGuard incluso)** — 49 destiladas do
[ECC 2.0.0-rc.1](https://github.com/affaan-m/ECC) (MIT) + 4 vendorizadas do
[obra/superpowers](https://github.com/obra/superpowers) v6.1.1 (MIT): `brainstorming`,
`systematic-debugging`, `using-git-worktrees`, `finishing-a-development-branch`.
Atribuições completas em `docs/licenses.md` na raiz do repo.

> UPDATE 001: os **21 agents ECC não vivem mais aqui** — foram enrolados para o team-os
> (`SendMessage`, `memory: user`, contrato team-os) e agora são instalados em
> `~/.claude/agents/` a partir de `harness/agents/`. Motivo: agents de plugin são tier
> [consultor] no team-os; no escopo de usuário eles ficam [team-ready].

## Regra de ouro

**NUNCA instale o ECC do marketplace upstream (`affaan-m/ECC`) nesta configuração.**
O cache de plugin é efêmero: um update sobrescreveria os 4 arquivos que carregam melhorias
("gold merge") que só existem aqui:

- `skills/motion-ui/SKILL.md`
- `skills/agent-sort/SKILL.md`
- `skills/product-capability/SKILL.md`
- `skills/brand-voice/SKILL.md`

Este diretório é a fonte de verdade. Atualizações são feitas editando o repo, versionadas no git.

## Como é instalado

O instalador copia `plugins/` para `{{CLAUDE_HOME}}/plugins/bsaios-marketplace` e registra no
`settings.json`:

```json
"extraKnownMarketplaces": { "bsaios": { "source": { "source": "directory", "path": "<CLAUDE_HOME>/plugins/bsaios-marketplace" } } },
"enabledPlugins": { "bsaios-core@bsaios": true }
```

Verificação: `claude plugin list` deve mostrar `bsaios-core`.

## O que tem dentro

| pasta | conteúdo |
|---|---|
| `skills/` | 53 skills (invocáveis como `/bsaios-core:<nome>`, ex.: `/bsaios-core:strategic-compact`, `/bsaios-core:brainstorming`) |
| `hooks/` + `scripts/` | dispatchers de hooks do ECC, incluindo o GateGuard (`docs/gateguard.md`) |
| `config/`, `rules/`, `schemas/`, `contexts/` | suporte usado pelos scripts/skills |
| `.mcp.json` | **vazio de propósito** — dieta de MCP (os 6 MCPs do ECC upstream foram removidos) |

Observações:

- Os "command shims" legados do ECC (`commands/`, 79 arquivos) **não** foram vendorizados — as
  skills já se registram como slash commands (`/bsaios-core:*`).
- O observer do `continuous-learning-v2` está `enabled: false` (trava no Windows, bug #295) e os
  hooks ruidosos vêm desligados via `ECC_DISABLED_HOOKS` no settings do time.
