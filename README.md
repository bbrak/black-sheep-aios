# Black Sheep AIOS

Harness de IA do time — um ambiente de **Claude Code** curado, instalável e replicável.
Você clona, roda um instalador e termina com o mesmo conjunto de skills, agents, hooks e rules
que o setup de referência usa todo dia. Cross-platform: **Windows e macOS**.

> v1 = harness + instalação + assistente de IA para o setup. Curso e playbooks por função são a
> fase 2.

## O que você ganha

| camada | conteúdo |
|---|---|
| **Plugin `bsaios-core`** | 53 skills curadas: 49 destiladas do ECC (com melhorias exclusivas) + 4 do Superpowers (`brainstorming`, `systematic-debugging`, `using-git-worktrees`, `finishing-a-development-branch`) + GateGuard |
| **Skills de usuário (6)** | `team-os` (multiagentes — veja abaixo), `agent-browser`, `graphify`, `prompt-master`, `ui-ux-pro-max` (v2.10.2, com extensão anti-slop local), `verify-frontend-change` |
| **Agents (44)** | 21 ECC enrolados p/ team-os (architect, code-reviewer, tdd-guide, security-reviewer…) + 15 do time `dev-*` + 8 de marketing/negócio (paid-social-strategist, email-strategist, tracking-specialist, aeo-foundations, ai-citation-strategist, ads-auditor, fpa-analyst, feedback-synthesizer) |
| **Hooks** | skill-suggester, loop-detector, session-context (Node, zero token), validate-agent-frontmatter, git-moment-advisor, GateGuard |
| **Rules (8)** | general, coding-standards, security, python, javascript, git-workflow-coaching, failure-prevention, lazy-senior (escada anti-overengineering YAGNI, always-on) |
| **Config** | `settings.json` gerado por SO (GateGuard ON, permissões `acceptEdits`, deny-list de comandos destrutivos), `CLAUDE.md` global com seu nome/função, statusline |

O que **não** tem (de propósito): plugin Vercel, MCPs pessoais com credencial, observer de
continuous-learning (trava no Windows), summarizer/cost-tracker do ECC (ruído). Dieta de MCP:
só `context7` e `chrome-devtools`, opcionais.

## Instalação

### Windows

```powershell
git clone <URL-DO-REPO> black-sheep-aios
cd black-sheep-aios
powershell -ExecutionPolicy Bypass -File install\install.ps1
```

### macOS

```bash
git clone <URL-DO-REPO> black-sheep-aios
cd black-sheep-aios
bash install/install.sh
```

O instalador: checa pré-requisitos (imprime o comando de instalação de cada um que faltar),
copia o harness para `~/.claude` (com backup do que existia), instala o plugin `bsaios-core`
como marketplace local, gera `settings.json` + `CLAUDE.md` perguntando seu nome/função, e por
fim **pergunta se quer instalar as ferramentas externas** que faltarem (RTK, Graphify,
agent-browser) — instalando o comando certo do seu SO na hora.

Pré-requisitos (Git, Node LTS, Python 3, uv, jq, Claude Code): o instalador **não** os instala
sozinho — imprime o comando por SO (lista completa em
[`install/manifest.json`](install/manifest.json)).

Ferramentas externas (RTK, Graphify, agent-browser): para cada uma ausente o instalador
**pergunta `[Y/n]` e instala** por SO (no Mac, `brew install rtk`; no Windows, baixa o `.zip`
do release do RTK e ajusta o PATH). Flags: `--yes`/`-Yes` aceita tudo sem perguntar (bom para
setup não-interativo); `--skip-tools`/`-SkipTools` pula essa etapa. Se você recusar ou a
instalação falhar, segue em fail-soft — dá pra instalar depois.

### Instalação assistida por IA

Não quer fazer sozinho? Abra o Claude (Desktop ou claude.ai), cole o conteúdo de
[`assist/INSTALL-ASSIST-PROMPT.md`](assist/INSTALL-ASSIST-PROMPT.md) e siga a conversa.
A IA te guia passo a passo, um comando por vez, com verificação em cada etapa.

### Verificação pós-instalação

```bash
claude doctor        # saúde do Claude Code
claude plugin list   # deve listar bsaios-core
```

Abra uma sessão do Claude Code: a statusline (pasta + branch + modelo + barra de contexto) deve
aparecer, e `/bsaios-core:ecc-guide` responde com o guia das skills.

## Notas por sistema

- **RTK (economia de ~70% de tokens em git/npm/gh):**
  - *macOS:* o hook automático fica ligado — todo comando Bash passa pelo `rtk` de forma
    transparente (fail-soft se não estiver instalado).
  - *Windows nativo:* não existe hook automático — o modo é via `@RTK.md` no `CLAUDE.md` global
    (o agente aprende a chamar `rtk <cmd>` explicitamente). Isso é normal, não é defeito.
- **Python:** no Windows o binário é `python`; no macOS é `python3`. Os arquivos gerados já vêm
  com o binário certo — não copie `settings.json` de um SO para o outro; rode o instalador.
- **GateGuard:** vem **ligado**. Ele bloqueia a primeira escrita por arquivo e o primeiro Bash da
  sessão até o agente verificar contexto — é treino de disciplina, não bug. Escape hatches e
  tuning: [`docs/gateguard.md`](docs/gateguard.md).
- **Context canary:** o CLAUDE.md instrui o agente a te chamar **pelo seu nome** (o que você
  preencheu no install) em toda resposta. Quando ele parar de usar seu nome, as instruções
  globais estão saindo do contexto efetivo — hora de `/clear`.
- **Anti-overengineering:** a rule `lazy-senior` (always-on) impõe a escada YAGNI de 7 degraus
  antes de qualquer código novo, com guardas invioláveis de segurança/a11y, review com
  delete-list e a convenção `bsheep:` para débito deliberado (colete com `grep -rn "bsheep:"`).

## Multiagentes? `/team-os`

**Quer usar multiagentes? `/team-os`.** É a entrada padrão do time para qualquer trabalho
multi-agente: descobre os agents disponíveis (projeto + usuário + plugins + built-ins), monta o
squad, coordena via SendMessage e mantém a memória do projeto. Já vem pronto:

- O env `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` vem ligado no settings gerado (o preflight do
  team-os bloqueia sem ele).
- Os 21 agents ECC instalados em `~/.claude/agents/` são o pool **[team-ready]** (enrolados:
  SendMessage + memória). Agents de plugin e built-ins entram como **[consultor]** (tarefas
  autocontidas).
- `jq` no PATH habilita a descoberta de agents de plugin (sem ele, degrada em silêncio).

## Hooks do time — como se comportam

`skill-suggester` lembra a skill certa quando o assunto da mensagem casa (descoberta dinâmica:
skill nova instalada aparece sozinha; zero IA, zero token). Se um dia o conjunto de skills
crescer muito e o suggester ficar ruidoso, crie `~/.claude/hooks/team/suggest-allowlist.txt`
listando as skills-carro-chefe (uma por linha) — detalhes em
[`harness/hooks/team/README.md`](harness/hooks/team/README.md). `loop-detector` intervém quando a
mesma mensagem se repete 3×. `session-context` injeta pasta/stack/branch no início da sessão.
`validate-agent-frontmatter` avisa na hora se um `.claude/agents/*.md` ficou com YAML quebrado
(uma falha silenciosa que já custou sessões de debug). `git-moment-advisor` sugere o momento de
commitar/pushar — nunca age sozinho.

## MCPs (opcionais)

```bash
# Windows
claude mcp add --scope user context7 -- cmd /c npx -y @upstash/context7-mcp@latest
claude mcp add --scope user chrome-devtools -- npx -y chrome-devtools-mcp@latest

# macOS
claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp@latest
claude mcp add --scope user chrome-devtools -- npx -y chrome-devtools-mcp@latest
```

Nada de MCP com credencial pessoal no harness. Credenciais de projeto vivem em
`<projeto>/.claude/settings.local.json` (gitignored), nunca no chat e nunca neste repo.

## Estrutura do repo

```
black-sheep-aios/
├── README.md                  # este arquivo
├── install/
│   ├── manifest.json          # FONTE ÚNICA: prereqs, comandos Win+Mac, wiring do plugin
│   ├── install.ps1            # instalador Windows
│   ├── install.sh             # instalador macOS
│   └── lib/render-settings.js # renderiza settings/CLAUDE.md por SO (usado pelos dois)
├── harness/                   # payload que vai para ~/.claude
│   ├── settings.team.json     # template ({{CLAUDE_HOME}}, {{PYTHON}}; GateGuard ON; Agent Teams ON)
│   ├── CLAUDE.md.template     # contexto global (nome/função preenchidos no install)
│   ├── RTK.md                 # modo de uso do RTK (referenciado pelo CLAUDE.md)
│   ├── statusline-command.js  # statusline Node cross-platform
│   ├── skills/ (6, incl. team-os)  agents/ (44)  hooks/  rules/ (8)
├── plugins/                   # marketplace local (por diretório)
│   └── bsaios-core/           # 53 skills + GateGuard (vendorizado — ver README lá)
├── assist/INSTALL-ASSIST-PROMPT.md
└── docs/
    ├── gateguard.md           # o que é + escape hatches
    └── licenses.md            # atribuições (ECC MIT etc.)
```

## Regras de ouro

1. **Nunca instale o ECC do marketplace upstream** (`affaan-m/ECC`) — sobrescreveria as melhorias
   exclusivas do `bsaios-core`. O plugin local é a fonte de verdade.
2. **Segredos nunca entram neste repo** nem no chat — placeholders somente.
3. Mudou algo no harness? Edite **o repo**, commite, e todo mundo reinstala com o installer
   (ele faz backup do que sobrescreve em `~/.claude/backups/`).
