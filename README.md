# Black Sheep AIOS

Uma "caixa de ferramentas" pronta do time para o **Claude Code** (o assistente de IA que rodamos no
computador): os mesmos atalhos, ajudantes especializados e proteções, já configurados do jeito que o
time usa. Funciona igual em **Windows e macOS**, e você **não precisa saber programar** para instalar.

---

## 🚀 Comece aqui — instalação do zero (Windows e macOS)

> **Nunca mexeu com isso? Perfeito.** Siga os passos **na ordem**, um de cada vez — cada passo diz o
> que fazer e como saber que deu certo. Você vai trabalhar dentro de **um** programa (o **VS Code**),
> e um **único comando** instala todo o resto. No fim aparece **"TUDO PRONTO"**.

> ### 🆘 Travou ou deu erro em qualquer passo? Não sofra sozinho.
> Abra o Claude (em **[claude.ai](https://claude.ai)** ou no app) e **cole o prompt do assistente de
> instalação** — ele vira um guia que resolve com você, um passo de cada vez:
>
> 👉 **[Abrir o prompt do assistente de instalação](https://github.com/bbrak/black-sheep-aios/blob/stable/assist/INSTALL-ASSIST-PROMPT.md)**
>
> No link, clique em **"Copy raw file"** (ícone de copiar), cole no Claude, e diga em qual passo travou.

### Passo 1 — Instale o VS Code (onde você vai trabalhar)

O **VS Code** é o "editor": a janela onde você organiza seus projetos e conversa com o Claude. É
gratuito, da Microsoft.

1. Abra **[code.visualstudio.com](https://code.visualstudio.com)** e clique no botão **Download**.
2. **Windows:** abra o arquivo baixado → **Avançar → Avançar → Instalar → Concluir**. Deixe marcada
   a opção *"Adicionar ao PATH"* (já vem marcada).
3. **macOS:** abra o `.zip` baixado → arraste o ícone **Visual Studio Code** para a pasta
   **Aplicativos** → abra pelo **Launchpad** (ou ⌘+espaço → digite "Visual Studio Code").

✅ **Deu certo?** O VS Code abre numa janela de boas-vindas.

<!-- 🖼️ PRINT PENDENTE: docs/assets/vscode-download.png -->

### Passo 2 — Crie sua pasta de projetos

Todo o seu trabalho vai morar **numa pasta só**, organizada por projeto. Isso evita bagunça e evita
o erro mais comum do time: **rodar comando no lugar errado** (fora de uma pasta sua, dá erro).

1. **Windows:** abra o **Explorador de Arquivos** → entre em **Documentos** → botão direito →
   **Novo → Pasta** → nomeie **`Projetos`**.
2. **macOS:** abra o **Finder** → entre em **Documentos** → **Arquivo → Nova Pasta** → nomeie
   **`Projetos`**.

> 💡 Depois, cada trabalho novo vira uma **subpasta** dentro de `Projetos`
> (ex.: `Projetos/cliente-site`). Um lugar para cada coisa.

### Passo 3 — Abra a pasta `Projetos` no VS Code

1. No VS Code: **Arquivo (File) → Abrir Pasta… (Open Folder…)**.
2. Selecione a pasta **`Projetos`** e clique em **Abrir**.
3. Se perguntar *"Você confia nos autores desta pasta?"*, clique em **"Sim, confio"**.

✅ **Deu certo?** O nome **PROJETOS** aparece na barra lateral esquerda.

### Passo 4 — Abra o terminal dentro do VS Code

O **terminal** é onde você cola comandos. No VS Code ele fica **na própria janela** — você não
precisa caçar um programa separado (essa era a maior confusão do time).

1. Menu **Terminal → Novo Terminal** — ou o atalho **Ctrl + `** (a tecla da crase, logo abaixo do Esc).
2. Abre um painel embaixo com um cursor piscando. É aí que você cola o comando do próximo passo.

> No **Windows** esse terminal já é o **PowerShell** (o certo); no **macOS** é o **zsh**. Nos dois, o
> comando do Passo 5 funciona igual.

<!-- 🖼️ PRINT PENDENTE: docs/assets/vscode-terminal.png -->

### Passo 5 — Cole o comando de instalação e aperte Enter

Cole o comando do **seu sistema** no terminal do VS Code (Passo 4) e aperte **Enter**. Ele instala
**tudo sozinho** — o VS Code (se faltar), git, node, Python, e o próprio Claude Code — e no fim avisa
**"TUDO PRONTO"**. Se algo já existe, ele pula; se você rodar de novo, não quebra nada.

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

> **⚠️ Vai aparecer `[Y/n]` algumas vezes:** perto do fim, o instalador pergunta se pode instalar as
> **ferramentas externas do time** (RTK, Graphify, agent-browser). Digite **`Y`** e aperte **Enter**
> em cada uma. Se você pular, ou se alguma falhar, não tem problema — nada quebra e o instalador segue.

> **⚠️ Ele vai perguntar seu nome, sua função e sua área de foco.** Responda com o que fizer sentido
> pra você — não existe resposta errada, é só para o assistente te chamar pelo nome e ajustar o tom
> (ex.: *Maria* · *Designer* · *design, redes sociais*). **Não dá para deixar em branco:** se apertar
> Enter sem escrever nada, ele pergunta de novo.

### Passo 6 — Quando o instalador terminar

Ele termina de um jeito **ou** do outro. Veja qual apareceu **antes de fechar o terminal**:

- ✅ **"TUDO PRONTO"** — deu certo, siga os passos abaixo.
- ⚠️ **"INSTALAÇÃO INCOMPLETA — N etapa(s) falharam"** — alguma coisa não instalou. **Não feche o
  terminal ainda:** role para cima e procure as linhas vermelhas **`[XX]`** — cada uma diz o comando
  que resolve. Na dúvida, **rode o mesmo comando do Passo 5 de novo** (ele não duplica nada), ou
  copie o terminal inteiro para o assistente de instalação (box 🆘 no topo desta página).

Apareceu **"TUDO PRONTO"**? Então:

1. **Feche o terminal do VS Code e abra um novo:** clique no ícone de **lixeira** no painel do
   terminal, depois **Terminal → Novo Terminal**. Isso faz o comando `claude` aparecer (o PATH
   recarrega). Se ainda não achar, **feche e reabra o VS Code inteiro**.
2. No terminal novo, digite **`claude`** e aperte **Enter**.
3. Dentro do Claude, rode **`/bsaios-core:ecc-guide`** para conhecer os atalhos.

Pronto — seu Claude Code ficou igual ao do resto do time. **Pode parar aqui.**

---

## ❓ Deu erro? (as dúvidas mais comuns)

Baseado nas **primeiras instalações reais do time** — se você travou em algo, provavelmente está aqui:

| Sintoma | O que é | O que fazer |
|---|---|---|
| **A senha não aparece quando eu digito** (Mac) | O terminal esconde a senha de propósito, por segurança. | Digite normalmente (mesmo sem ver nada) e aperte **Enter**. Não travou. |
| **`claude: command not found` depois de instalar** | O PATH ainda não recarregou nesta janela. | **Feche o terminal do VS Code (ícone de lixeira) e abra um novo.** Se persistir, **feche e reabra o VS Code inteiro**. |
| **Ficou 5-10 min "parado" baixando algo** (Mac) | Numa máquina nova, o Homebrew baixa as *Ferramentas do Xcode* (uma vez só). | **Não é a internet travando** — deixe rodar até o fim. |
| **Não sei onde está o terminal** | No VS Code ele fica na própria janela, num painel embaixo. | Menu **Terminal → Novo Terminal**, ou atalho **Ctrl + `** (Passo 4). |
| **Windows bloqueou o download** (SmartScreen/antivírus) | Proteção do Windows barrando um instalador. | O comando usa o **winget** e o instalador oficial da Anthropic (confiáveis). Se ainda barrar, permita o **App Installer** pela Microsoft Store. |
| **Colei e não aconteceu nada** | Provavelmente colou no lugar errado (no chat do Claude, ou dentro de um arquivo aberto). | Cole **no terminal do VS Code** (o painel de baixo, Passo 4) — clique nele antes de colar. |
| **Deu erro no meio e parou uma parte** | O instalador é **fail-soft**: avisa, dá o comando manual e **continua** — nunca deixa a máquina pela metade. | Leia o aviso amarelo `[!!]`, rode o comando manual sugerido, ou simplesmente **rode o mesmo comando de novo** (é idempotente). |
| **Apareceu "INSTALAÇÃO INCOMPLETA" no fim** | Alguma etapa falhou de verdade (rede caiu, senha errada, disco cheio). Ele avisa em vez de fingir que deu certo. | **Não feche o terminal.** Role para cima até as linhas vermelhas **`[XX]`** — cada uma traz o comando que resolve. Depois **rode o mesmo comando do Passo 5 de novo**. |
| **Ele reclamou do "Xcode Command Line Tools"** (Mac) | São as ferramentas de base da Apple (o `git` vem delas). Faltam, ou quebraram depois de uma atualização do macOS. | Rode **`xcode-select --install`**, aceite a janela que abrir, espere terminar, e rode o comando do Passo 5 de novo. |
| **`graphify: ... 'uv' não é reconhecido`** (Windows) | Faltava o `uv` (usado para instalar o Graphify). Já corrigido no instalador. | **Feche e reabra o terminal** e rode o mesmo comando de novo — agora o `uv` é instalado antes do Graphify. |

Ainda travado? Use o **assistente de instalação por IA** — o prompt está no topo desta página (no
box 🆘) e também detalhado na seção **Instalação manual (avançado)** abaixo.

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
