# Licenças e atribuições

Este repositório vendoriza (empacota cópias de) trabalho de terceiros. Registro de origem e
licença de cada peça:

## ECC — Everything Claude Code (plugin `bsaios-core`)

- **Origem:** [affaan-m/ECC](https://github.com/affaan-m/ECC), versão `2.0.0-rc.1`, de autoria de
  Affaan Mustafa ([ecc.tools](https://ecc.tools)).
- **Licença:** MIT — texto integral em [`plugins/bsaios-core/LICENSE.ecc`](../plugins/bsaios-core/LICENSE.ecc)
  (Copyright (c) 2026 Affaan Mustafa).
- **O que foi vendorizado:** 49 skills (de 249) no plugin `bsaios-core`; 21 agents (de 63) em
  `harness/agents/` (instalados em `~/.claude/agents/`); os hooks (incl. GateGuard) com seu
  runtime (`scripts/`), `config/`, `rules/`, `schemas/`, `contexts/` e um `.mcp.json` vazio.
- **Modificações locais:** poda de 200 skills e 42 agents; melhorias ("gold") de outras skills do
  ECC fundidas em 4 arquivos (`motion-ui`, `agent-sort`, `product-capability`, `brand-voice`);
  plugin renomeado para `bsaios-core`; MCP servers removidos; command shims legados não incluídos;
  os 21 agents enrolados para o team-os (`SendMessage` em tools, `memory: user`, seção "Contrato
  com team-os").
- **Por que vendorizado e não instalado do marketplace:** o cache de plugin é efêmero — qualquer
  update/reinstal do ECC upstream sobrescreveria os 4 arquivos com gold merge. **Nunca instale
  `ecc@ecc` de affaan-m/ECC nesta configuração.**

## Superpowers (4 skills no plugin `bsaios-core`)

- **Skills vendorizadas:** `brainstorming`, `systematic-debugging`, `using-git-worktrees`,
  `finishing-a-development-branch`.
- **Origem:** [obra/superpowers](https://github.com/obra/superpowers) v6.1.1
  (commit `d884ae04edebef577e82ff7c4e143debd0bbec99`) — MIT License, Copyright (c) 2025
  Jesse Vincent / Prime Radiant, Inc.
- **Modificações locais:** remoção do visual companion e de telemetria; referências a skills
  não vendorizadas substituídas por transições neutras (team-os/fluxo do time); paths
  `docs/superpowers/` → `docs/specs/`. Detalhes no rodapé de cada SKILL.md.

## agency-agents (8 agents em `harness/agents`)

- **Agents vendorizados:** `paid-social-strategist`, `email-strategist`, `tracking-specialist`,
  `aeo-foundations`, `ai-citation-strategist`, `ads-auditor`, `fpa-analyst`,
  `feedback-synthesizer`.
- **Origem:** [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents)
  (commit `75173cea526e3324f8e71084eae7581561be54c4`) — MIT License, Copyright (c) 2025
  AgentLand Contributors.
- **Modificações locais:** renomeação para kebab-case, frontmatter na convenção local
  (tools/model/memory + contrato team-os), poda de personas e metadados cosméticos.

## ponytail (inspiração para `harness/rules/lazy-senior.md`)

- A rule anti-overengineering foi **reescrita** inspirada no padrão do
  [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) (MIT) — não é cópia do
  texto upstream.

## agent-browser (skill em `harness/skills/agent-browser`)

- **Origem:** [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser) — o stub
  de skill instalado por `npx skills add vercel-labs/agent-browser`. O conteúdo real é servido
  pela CLI `agent-browser` em runtime. Consulte o repositório upstream para a licença da CLI.

## graphify (skill em `harness/skills/graphify`)

- **Origem:** gerada pela própria CLI Graphify (`uv tool install graphifyy`, comando
  `graphify claude install`). Consulte o pacote PyPI `graphifyy` para a licença da ferramenta.

## ui-ux-pro-max (skill em `harness/skills/ui-ux-pro-max`)

- **Origem confirmada:** [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)
  v2.10.2 (commit `12b486b22e67f5d887962ef8351c1ac863bfaeb9`) — MIT License, Copyright (c) 2024
  Next Level Builder. Gerada pelo caminho suportado (`npx ui-ux-pro-max-cli init --ai claude`).
- **Extensão local:** seção demarcada "Local extension — anti-slop (Black Sheep AIOS)" no
  SKILL.md (regras anti-AI-slop não cobertas upstream). Registrar a tag vendorizada a cada
  atualização futura para permitir diff.

## RTK (referenciado, não vendorizado)

- [rtk-ai/rtk](https://github.com/rtk-ai/rtk) — instalado pelos funcionários direto do upstream.
  `harness/RTK.md` é documentação interna de uso.

## Demais conteúdos

`prompt-master`, `verify-frontend-change`, `team-os`, hooks do time (`hooks/team/`),
`validate-agent-frontmatter.py`, `git-moment-advisor.sh`, `statusline-command.js`, rules,
templates, instaladores e docs: produção interna, uso interno do time.
