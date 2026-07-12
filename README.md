# Black Sheep AIOS

Uma "caixa de ferramentas" pronta do time para o **Claude Code** (o assistente de IA que rodamos no
computador): os mesmos atalhos, ajudantes especializados e proteções, já configurados do jeito que o
time usa. Funciona igual em **Windows e macOS**, e você **não precisa saber programar** para instalar.

---

## 🚀 Instalar (1 comando)

> Você vai colar **um** comando num programa chamado **Terminal** (Mac) ou **PowerShell** (Windows).
> Ele instala **tudo sozinho** — inclusive as ferramentas de base (Homebrew/winget, git, node e o
> próprio Claude Code) — e no fim avisa **"TUDO PRONTO"**. Se algo já estiver instalado, ele pula; se
> você rodar de novo, não quebra nada.

### 1) Abra o terminal

**macOS — Terminal**
1. Aperte **⌘ Cmd + barra de espaço** (abre a busca do Spotlight).
2. Digite **Terminal** e aperte **Enter**.
3. Abre uma janela com um cursor piscando — é aqui que você cola o comando.

<!-- 🖼️ PRINT PENDENTE (Fase 3): docs/assets/mac-abrir-terminal.png -->

**Windows — PowerShell** (use o PowerShell, **não** o "Prompt de Comando" antigo)
1. Aperte a tecla **⊞ Windows**.
2. Digite **PowerShell**.
3. Clique em **Windows PowerShell**.

<!-- 🖼️ PRINT PENDENTE (Fase 3): docs/assets/win-abrir-powershell.png -->

### 2) Cole o comando do seu sistema e aperte Enter

**macOS:**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/bbrak/black-sheep-aios/stable/install/bootstrap.sh)"
```

**Windows (PowerShell):**
```powershell
powershell -ExecutionPolicy Bypass -Command "iwr -useb https://raw.githubusercontent.com/bbrak/black-sheep-aios/stable/install/bootstrap.ps1 | iex"
```

Durante a instalação ele vai **perguntar seu nome, sua função e sua área de foco** (para
personalizar o assistente). É só responder.

> **⚠️ macOS — a senha que vai aparecer:** numa máquina nova, o instalador precisa instalar o
> Homebrew, que **pede a senha de login do seu Mac**. Dois avisos importantes:
> - **O terminal NÃO mostra nada enquanto você digita a senha** (nem pontinhos). Isso é normal e
>   proposital — digite a senha e aperte **Enter** "às cegas".
> - Se você entra no Mac com **Touch ID (digital)** e não lembra a senha: é a **mesma** de quando o
>   Mac reinicia. Dá pra ver/redefinir em *Ajustes do Sistema → Touch ID e Senha*.
>
> No **Windows não há senha de administrador** — o winget e o Claude Code instalam no seu usuário.

### 3) Quando aparecer "TUDO PRONTO"

1. **Feche o terminal e abra um novo** (para as ferramentas entrarem no PATH — a "lista de lugares
   onde o sistema procura programas").
2. Digite **`claude`** e aperte Enter.
3. Dentro do Claude, rode **`/bsaios-core:ecc-guide`** para conhecer os atalhos.

Pronto — seu Claude Code ficou igual ao do resto do time. **Pode parar aqui.**

---

## ❓ Deu erro? (as dúvidas mais comuns)

Baseado nas **primeiras instalações reais do time** — se você travou em algo, provavelmente está aqui:

| Sintoma | O que é | O que fazer |
|---|---|---|
| **A senha não aparece quando eu digito** (Mac) | O terminal esconde a senha de propósito, por segurança. | Digite normalmente (mesmo sem ver nada) e aperte **Enter**. Não travou. |
| **`claude: command not found` depois de instalar** | O PATH ainda não recarregou nesta janela. | **Feche o terminal e abra um novo.** No Windows, se persistir, reabra o PowerShell — o instalador já ajustou o PATH. |
| **Ficou 5-10 min "parado" baixando algo** (Mac) | Numa máquina nova, o Homebrew baixa as *Ferramentas do Xcode* (uma vez só). | **Não é a internet travando** — deixe rodar até o fim. |
| **Não sei onde está o terminal** | Dentro do VS Code ele fica escondido. | Abra o **Terminal/PowerShell do sistema** (passo 1 acima), **fora** do VS Code. |
| **Windows bloqueou o download** (SmartScreen/antivírus) | Proteção do Windows barrando um instalador. | O comando usa o **winget** e o instalador oficial da Anthropic (confiáveis). Se ainda barrar, permita o **App Installer** pela Microsoft Store. |
| **Colei e não aconteceu nada** | Provavelmente colou no lugar errado (no chat do Claude, num arquivo, ou no terminal do VS Code). | Cole **no Terminal/PowerShell do sistema** (passo 1) — não em outro lugar. |
| **Deu erro no meio e parou uma parte** | O instalador é **fail-soft**: avisa, dá o comando manual e **continua** — nunca deixa a máquina pela metade. | Leia o aviso amarelo `[!!]`, rode o comando manual sugerido, ou simplesmente **rode o mesmo comando de novo** (é idempotente). |

Ainda travado? Existe um **assistente por IA** que te guia um passo de cada vez — veja *Instalação
assistida por IA* na seção **Instalação manual (avançado)** abaixo.

---

## 🔒 "Rodar um comando da internet é seguro?"

Boa pergunta — e com razão. Esse comando baixa e roda um script do nosso repositório **público**
(`bbrak/black-sheep-aios`), fixado na versão `stable`. Se você prefere **ver antes de rodar**:

**macOS:**
```bash
curl -fsSL https://raw.githubusercontent.com/bbrak/black-sheep-aios/stable/install/bootstrap.sh -o bootstrap.sh
less bootstrap.sh      # leia o que ele faz (aperte 'q' para sair)
bash bootstrap.sh      # rode quando estiver confortável
```

**Windows (PowerShell):**
```powershell
iwr -useb https://raw.githubusercontent.com/bbrak/black-sheep-aios/stable/install/bootstrap.ps1 -OutFile bootstrap.ps1
notepad bootstrap.ps1  # leia o que ele faz
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1
```

O script só instala Homebrew/winget, git, node e o Claude Code, clona este repositório e roda o
instalador do harness — nada escondido, e **nunca sobrescreve seus arquivos pessoais**.

---

<details>
<summary><b>🛠️ Instalação manual (avançado) — sem o comando único</b></summary>

Prefere rodar cada passo você mesmo (ou não confia em `curl | bash`)? O 1 comando acima só
automatiza estes passos. Você precisa ter **git, node e o Claude Code** já instalados (o bootstrap
é justamente quem resolve isso pra você).

### Passo a passo — macOS
```bash
git clone https://github.com/bbrak/black-sheep-aios.git
cd black-sheep-aios
bash install/install.sh
```

### Passo a passo — Windows
```powershell
git clone https://github.com/bbrak/black-sheep-aios.git
cd black-sheep-aios
powershell -ExecutionPolicy Bypass -File install\install.ps1
```
O `-ExecutionPolicy Bypass` só libera a execução deste script específico — não muda nenhuma
configuração permanente do computador.

### O que o instalador (`install.sh`/`.ps1`) faz, na ordem
1. **Confere as ferramentas de base** (git, node, python, uv, jq, claude). Se faltar alguma, imprime
   o comando exato — o `install` **não** instala essas de base (é o `bootstrap` que instala).
2. **Copia o harness** para `~/.claude` (backup do que for sobrescrito).
3. **Instala o pacote `bsaios-core`** como marketplace local (da pasta do repo, não da internet).
4. **Gera `settings.json` e `CLAUDE.md`**, perguntando nome/função para personalizar.
5. **Pergunta se quer instalar as ferramentas externas** faltantes (RTK, Graphify, agent-browser).

### Flags do bootstrap e do install
- `--dry-run` — só mostra o que faria, sem instalar nada (prova de idempotência).
- `--yes` / `-Yes` — aceita instalar as ferramentas externas sem perguntar.
- `--skip-tools` / `-SkipTools` — pula as ferramentas externas.
- `--dir <pasta>` (bootstrap) — onde clonar o harness (default `~/black-sheep-aios`).

### Pré-requisitos (ferramentas de base)
A lista completa e oficial vive em [`install/manifest.json`](install/manifest.json).

| Ferramenta | Para que serve | Verificar |
|---|---|---|
| **Git** | Baixar o repo e versionar; hooks em bash/python no Windows | `git --version` |
| **Node.js (LTS)** | Hooks do time, statusline, alguns MCPs | `node --version` |
| **Python 3** | Hook que valida agents e o Graphify (Mac: `python3`; Windows: `python`) | `python --version` / `python3 --version` |
| **uv** | Forma recomendada de instalar o Graphify | `uv --version` |
| **jq** | team-os usa para descobrir agents de plugins (fail-soft sem ele) | `jq --version` |
| **Claude Code** | O próprio assistente — o programa principal | `claude --version` |

### Ferramentas externas (opcionais, recomendadas)
**RTK** (economiza ~70% do consumo de IA em git/npm/gh), **Graphify** (mapa de conhecimento do
código) e **agent-browser** (agents navegam na web). Para cada uma faltante o instalador pergunta
`[Y/n]` e instala o comando certo do seu SO. Recusar ou falhar não quebra nada (fail-soft).

### Instalação assistida por IA (para quem tem pouca prática com terminal)
Travou em algum erro? Abra um Claude (Desktop ou claude.ai), copie todo o conteúdo de
[`assist/INSTALL-ASSIST-PROMPT.md`](assist/INSTALL-ASSIST-PROMPT.md) e cole na conversa. A IA te dá
um comando por vez, pronto para copiar, e depois de cada passo diz como conferir se deu certo. Ela
pergunta primeiro se você é Windows ou macOS, resolve um problema de cada vez, e **nunca** pede
para colar senhas ou tokens no chat.

</details>

<details>
<summary><b>📖 Glossário — o que cada palavra significa</b></summary>

| Termo | O que significa |
|---|---|
| **Harness** | O "kit completo" — todo o conjunto de configurações, atalhos e proteções instalado no seu Claude Code. |
| **Skill** | Um atalho/receita pronta que você aciona com `/nome-da-skill`. Um "modo especializado" para uma tarefa. |
| **Agent** | Um "ajudante especializado" que o Claude Code chama para uma tarefa (ex.: revisar segurança, escrever testes). |
| **Hook** | Uma "trava" ou "lembrete automático" que roda sozinho em certos momentos, para evitar erros bobos. |
| **Rule** | Uma regra de comportamento sempre ativa (ex.: "nunca commite sem eu pedir"). |
| **Plugin / marketplace local** | Um pacote fechado de skills e proteções, instalado a partir de uma pasta deste próprio repositório. |
| **MCP** | Uma "ponte" que dá ao Claude Code acesso a uma ferramenta externa (docs atualizadas, o navegador). Opcional. |
| **GateGuard** | Proteção que **bloqueia de propósito** a primeira ação em cada sessão/arquivo até o assistente confirmar que checou o contexto. Não é bug — é treino de disciplina. |
| **Statusline** | A barra de informação no topo do Claude Code (pasta, branch, modelo, memória de conversa usada). |
| **Fail-soft** | Quando algo opcional não está instalado, o sistema ignora aquela parte em silêncio, sem travar nada. |
| **PATH** | A "lista de lugares onde o sistema procura programas". Depois de instalar algo, às vezes é preciso reabrir o terminal para ele enxergar. |
| **SO** | Sistema Operacional — Windows ou macOS. |

</details>

<details>
<summary><b>📦 O que é instalado (conteúdo completo)</b></summary>

| Camada | Conteúdo técnico | Em outras palavras |
|---|---|---|
| **Plugin `bsaios-core`** | 53 skills curadas: 49 destiladas do ECC + 4 do Superpowers (`brainstorming`, `systematic-debugging`, `using-git-worktrees`, `finishing-a-development-branch`) + GateGuard | O pacote principal de atalhos prontos, incluindo a proteção GateGuard |
| **Skills de usuário (6)** | `team-os`, `agent-browser`, `graphify`, `prompt-master`, `ui-ux-pro-max`, `verify-frontend-change` | Seis atalhos extras, cada um para uma tarefa específica |
| **Agents (44)** | 21 ECC para o team-os + 15 do time `dev-*` + 8 de marketing/negócio | 44 "ajudantes especializados" prontos, de dev a marketing |
| **Hooks** | skill-suggester, loop-detector, session-context, validate-agent-frontmatter, git-moment-advisor, GateGuard | Seis "travas/lembretes automáticos" contra erros |
| **Rules (8)** | general, coding-standards, security, python, javascript, git-workflow-coaching, failure-prevention, lazy-senior | Oito regras de comportamento sempre ativas |
| **Config** | `settings.json` por SO (GateGuard ligado, permissões facilitadas, comandos perigosos bloqueados), `CLAUDE.md` global com seu nome/função, statusline | Os arquivos que deixam tudo pronto e com sua identidade |

</details>

<details>
<summary><b>🤖 Multiagentes (<code>/team-os</code>), hooks e notas por sistema</b></summary>

### Multiagentes? `/team-os`
Quer vários agents trabalhando juntos numa tarefa? Digite `/team-os`. Ele descobre os agents
disponíveis, monta o time certo, coordena a comunicação e guarda a memória do projeto. Já vem com
`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` ligado nas configurações geradas. Ter `jq` instalado
permite descobrir também agents de plugins (sem ele, essa descoberta não acontece — sem travar).

### Hooks do time — como se comportam
- **skill-suggester** — sugere a skill certa quando o assunto combina; descoberta dinâmica (skill
  nova aparece sozinha). Se ficarem demais, crie `~/.claude/hooks/team/suggest-allowlist.txt`.
- **loop-detector** — percebe a mesma mensagem repetida 3× e intervém.
- **session-context** — injeta pasta/tecnologia/branch no início da sessão.
- **validate-agent-frontmatter** — avisa na hora se um `.claude/agents/*.md` ficou com YAML quebrado.
- **git-moment-advisor** — sugere o momento de commit/push, mas nunca age sozinho.
- **GateGuard** — bloqueia a 1ª edição de cada arquivo e o 1º comando de cada sessão até checar o
  contexto. Intencional. Escape por sessão: `ECC_GATEGUARD=off claude` (Mac) /
  `$env:ECC_GATEGUARD="off"; claude` (Windows). Detalhes em [`docs/gateguard.md`](docs/gateguard.md).

### Notas por sistema
- **RTK:** no *macOS* opera automático e transparente (fail-soft se ausente); no *Windows nativo*
  não há esse modo automático — o assistente chama `rtk <comando>` explicitamente via `CLAUDE.md`.
- **Python:** Windows `python`, macOS `python3`. Não copie `settings.json` entre SOs — rode o
  instalador no sistema de destino.
- **Context canary:** o `CLAUDE.md` faz o assistente te chamar pelo nome em toda resposta. Se ele
  parar, é sinal de que o contexto está saturando — hora de `/clear`.
- **lazy-senior:** regra sempre ativa que obriga uma checagem anti-overengineering antes de escrever
  código, com marcação `bsheep:` para decisões conscientes de simplificação (`grep -rn "bsheep:"`).

### MCPs (opcionais)
```bash
# macOS
claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp@latest
claude mcp add --scope user chrome-devtools -- npx -y chrome-devtools-mcp@latest
# Windows
claude mcp add --scope user context7 -- cmd /c npx -y @upstash/context7-mcp@latest
claude mcp add --scope user chrome-devtools -- npx -y chrome-devtools-mcp@latest
```
**context7** = documentação sempre atualizada; **chrome-devtools** = navegador para automações.
Credenciais pessoais nunca entram neste repo nem no chat — vivem em
`<projeto>/.claude/settings.local.json` (ignorado pelo Git).

</details>

<details>
<summary><b>🔄 Atualizações, estrutura do repo e regras de ouro</b></summary>

### Atualizações
O harness sabe a própria versão. Quando sai novidade, o início da sessão mostra *"Black Sheep AIOS
vX disponível — rode /bsaios-update"*.
- **`/bsaios-update`** — mostra o que mudou, pergunta sim/não, aplica. Nunca toca no seu pessoal
  (`settings.local.json`, credenciais, `model`/`theme`); é transacional (em falha, restaura o backup).
- **`/bsaios-rollback`** — desfaz para o backup anterior (mantém os últimos 5).

Detalhes e o modelo canário→stable: [`docs/harness-updates.md`](docs/harness-updates.md).

### Verificação pós-instalação
```bash
claude doctor        # saúde geral do Claude Code
claude plugin list   # deve aparecer "bsaios-core"
```
Abra uma sessão nova: você deve ver a statusline no topo e, ao rodar `/bsaios-core:ecc-guide`, o
guia de todas as skills.

### Estrutura do repositório
```
black-sheep-aios/
├── README.md
├── install/
│   ├── bootstrap.sh / bootstrap.ps1   # 1 comando: instala base + clona + chama o install
│   ├── install.sh / install.ps1       # escreve o harness em ~/.claude
│   ├── manifest.json                  # fonte única: pré-requisitos, comandos por SO, config do plugin
│   ├── lib/render-settings.js         # gera as configs certas por SO
│   └── test/                          # sandbox.sh, bootstrap-check.sh (testes offline isolados)
├── harness/                           # a caixa de ferramentas que vai para ~/.claude
│   └── skills/ (6)  agents/ (44)  hooks/  rules/ (8)  settings.team.json  CLAUDE.md.template
├── plugins/bsaios-core/               # o marketplace local (53 skills + GateGuard)
├── assist/INSTALL-ASSIST-PROMPT.md    # o assistente de instalação por IA
└── docs/                              # gateguard.md, harness-updates.md, licenses.md, specs/
```

### Regras de ouro
1. **Nunca instale o "ECC" original da internet** (`affaan-m/ECC`) — sobrescreveria as melhorias do
   time. A versão confiável é o `bsaios-core` deste repo.
2. **Segredos nunca entram no repo nem no chat** — só placeholders.
3. **Mudou a caixa de ferramentas?** Edite o repo, faça commit, e o time reinstala (backup automático
   em `~/.claude/backups/`).

</details>
