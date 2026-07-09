# Black Sheep AIOS

## O que é isto, em uma frase

É uma "caixa de ferramentas" pronta para o Claude Code — o assistente de IA que o time usa no
computador — com tudo já configurado do jeito que o time usa no dia a dia: os mesmos atalhos,
os mesmos "ajudantes especializados" e as mesmas proteções de segurança. Você baixa, roda um
instalador, e seu Claude Code fica igual ao de todo mundo do time.

Funciona igual em **Windows e macOS**.

> Versão atual (v1): a caixa de ferramentas + a instalação + um assistente de IA que te ajuda a
> instalar. Cursos e guias por função (marketing, dev etc.) vêm numa fase futura.

## Para quem é isto

Para qualquer pessoa do time que usa (ou vai passar a usar) o Claude Code e quer ter, sem
esforço manual, o mesmo conjunto de configurações, atalhos e proteções que o resto do time já
usa. Você **não precisa saber programar** para instalar — existe inclusive um caminho assistido
por IA, explicado mais abaixo, pensado justamente para quem tem medo de terminal.

Ao final da instalação você vai ter: os mesmos atalhos de produtivos ("skills"), os mesmos
"ajudantes especializados" ("agents"), as mesmas proteções automáticas ("hooks" e "rules") e a
mesma barra de status na tela do Claude Code que o resto do time usa.

## Palavras que aparecem aqui

Este projeto usa alguns termos técnicos do Claude Code que não têm tradução direta. Aqui está o
que cada um significa, com uma analogia:

| Termo | O que significa |
|---|---|
| **Harness** | O "kit completo" — todo o conjunto de configurações, atalhos e proteções que fica instalado no seu Claude Code. Pense nele como a "caixa de ferramentas" inteira. |
| **Skill** | Um atalho/receita pronta que você aciona digitando `/nome-da-skill`. É como um "modo especializado" do assistente para uma tarefa específica (ex.: revisar um texto, montar um time de IA). |
| **Agent** | Um "ajudante especializado" que o Claude Code pode chamar para uma tarefa específica (ex.: um agent que só revisa segurança, outro que só escreve testes). |
| **Hook** | Uma "trava" ou "lembrete automático" que roda sozinho em certos momentos (ex.: antes de editar um arquivo, ou quando você repete a mesma mensagem 3 vezes). Serve para evitar erros bobos. |
| **Rule** | Uma regra de comportamento sempre ativa que o assistente segue (ex.: "nunca commite sem eu pedir"). |
| **Plugin / marketplace local** | Um pacote fechado de skills e proteções, instalado a partir de uma pasta deste próprio repositório (por isso "local" — não vem da internet, vem do que o time já revisou). |
| **MCP** | Uma "ponte" que dá ao Claude Code acesso a uma ferramenta externa (ex.: documentação atualizada, o navegador). Opcional. |
| **GateGuard** | Uma proteção que **bloqueia de propósito** a primeira ação do assistente em cada sessão/arquivo até ele confirmar que checou o contexto antes de agir. Não é um bug — é treino de disciplina contra "edições às cegas". |
| **Statusline** | A barra de informação que aparece na tela do Claude Code mostrando pasta, branch (ramo do código), modelo de IA em uso e quanto de "memória de conversa" já foi usado. |
| **Fail-soft** | Quando algo opcional não está instalado, o sistema simplesmente ignora aquela parte em silêncio, sem travar nada. Nada quebra por causa disso. |
| **SO** | Sistema Operacional — no seu caso, Windows ou macOS. |

## O que você ganha

A tabela abaixo lista o conteúdo técnico que é instalado. Ao lado de cada item, uma tradução em
linguagem simples.

| Camada | Conteúdo técnico | Em outras palavras |
|---|---|---|
| **Plugin `bsaios-core`** | 53 skills curadas: 49 destiladas do ECC (biblioteca de skills open-source, com melhorias exclusivas do time) + 4 do Superpowers (`brainstorming`, `systematic-debugging`, `using-git-worktrees`, `finishing-a-development-branch`) + GateGuard | O pacote principal de atalhos prontos para o Claude Code, incluindo a proteção GateGuard (veja o glossário) |
| **Skills de usuário (6)** | `team-os` (monta e coordena times de agents — veja a seção abaixo), `agent-browser`, `graphify`, `prompt-master`, `ui-ux-pro-max` (v2.10.2, com extensão anti-slop local), `verify-frontend-change` | Seis atalhos extras, cada um para uma tarefa específica (ex.: montar um time de IA, navegar na web, checar mudanças visuais) |
| **Agents (44)** | 21 ECC "enrolados" para o team-os (architect, code-reviewer, tdd-guide, security-reviewer…) + 15 do time `dev-*` + 8 de marketing/negócio (paid-social-strategist, email-strategist, tracking-specialist, aeo-foundations, ai-citation-strategist, ads-auditor, fpa-analyst, feedback-synthesizer) | 44 "ajudantes especializados" prontos para chamar, cobrindo desenvolvimento de software e marketing/negócio |
| **Hooks** | skill-suggester, loop-detector, session-context (Node, zero token), validate-agent-frontmatter, git-moment-advisor, GateGuard | Seis "travas/lembretes automáticos" que rodam sozinhos para evitar erros (detalhes na seção "Hooks do time" abaixo) |
| **Rules (8)** | general, coding-standards, security, python, javascript, git-workflow-coaching, failure-prevention, lazy-senior (regras contra complicar demais o código, sempre ativas) | Oito regras de comportamento que o assistente sempre segue |
| **Config** | `settings.json` gerado por sistema operacional (GateGuard ligado, permissões de edição facilitadas, lista de comandos perigosos bloqueados), `CLAUDE.md` global com seu nome/função, statusline | Os arquivos de configuração que deixam tudo pronto e com sua identidade preenchida |


## Instalação

Existem dois jeitos de instalar: **rodando os comandos você mesmo** (passo a passo abaixo) ou
**pedindo para uma IA te guiar** (seção "Instalação assistida por IA", recomendada se você tem
pouca experiência com terminal).

### Passo a passo — Windows

1. Baixe uma cópia deste repositório para o seu computador:

   ```powershell
   git clone https://github.com/bbrak/black-sheep-aios.git
   ```

   Isso cria uma pasta chamada `black-sheep-aios` com todo o conteúdo do projeto.

2. Entre na pasta que acabou de ser criada:

   ```powershell
   cd black-sheep-aios
   ```

3. Rode o instalador:

   ```powershell
   powershell -ExecutionPolicy Bypass -File install\install.ps1
   ```

   O `-ExecutionPolicy Bypass` só libera a execução deste script específico — não muda nenhuma
   configuração permanente do seu computador.

### Passo a passo — macOS

1. Baixe uma cópia deste repositório para o seu computador:

   ```bash
   git clone https://github.com/bbrak/black-sheep-aios.git
   ```

2. Entre na pasta que acabou de ser criada:

   ```bash
   cd black-sheep-aios
   ```

3. Rode o instalador:

   ```bash
   bash install/install.sh
   ```

### O que o instalador faz, na ordem

1. **Confere se as ferramentas de base estão no seu computador** (veja tabela de pré-requisitos
   abaixo). Se faltar alguma, ele imprime na tela o comando exato para instalar — o instalador
   não instala essas ferramentas de base sozinho, mas te diz exatamente o que rodar.
2. **Copia a caixa de ferramentas (harness)** para a pasta de configuração do Claude Code no seu
   computador (`~/.claude`). Se já existir algo lá, ele faz um backup antes de sobrescrever.
3. **Instala o pacote de skills `bsaios-core`** como "marketplace local" — ou seja, a partir da
   pasta deste próprio repositório, não da internet.
4. **Gera os arquivos de configuração** (`settings.json` e `CLAUDE.md`), perguntando seu nome e
   sua função para personalizar o assistente.
5. **Pergunta se você quer instalar as ferramentas externas** que ainda estiverem faltando (RTK,
   Graphify, agent-browser) — e instala o comando certo para o seu sistema operacional na hora,
   se você aceitar.

### Pré-requisitos (ferramentas de base)

Estas ferramentas precisam existir no seu computador antes de rodar o instalador. Se faltar
alguma, o próprio instalador te mostra o comando de instalação — a lista completa e oficial vive
em [`install/manifest.json`](install/manifest.json).

| Ferramenta | Para que serve aqui | Verificar se já tem |
|---|---|---|
| **Git** | Baixar o repositório e controlar versões do código; também necessário para os "hooks" em bash/python no Windows | `git --version` |
| **Node.js (LTS)** | Roda os hooks do time (skill-suggester, loop-detector, session-context), a statusline e alguns MCPs | `node --version` |
| **Python 3** | Roda o hook que valida os arquivos dos agents e a ferramenta Graphify (no Mac o comando é `python3`, no Windows é `python`) | `python --version` / `python3 --version` |
| **uv** | Forma recomendada de instalar o Graphify | `uv --version` |
| **jq** | Usado pelo team-os para descobrir agents vindos de plugins. Sem ele, essa descoberta simplesmente não acontece, sem travar nada (fail-soft) | `jq --version` |
| **Claude Code** | O próprio assistente de IA — é o programa principal em que tudo isso roda | `claude --version` |

### Ferramentas externas (opcionais, mas recomendadas)

Além dos pré-requisitos, existem três ferramentas externas que o instalador oferece instalar
automaticamente: **RTK** (economiza tokens/consumo de IA em comandos de git/npm/gh), **Graphify**
(mapa de conhecimento do código) e **agent-browser** (permite que os agents naveguem na web).

Para cada uma que estiver faltando, o instalador **pergunta `[Y/n]`** (sim ou não) e instala
sozinho, já usando o comando certo do seu sistema operacional (no Mac, por exemplo,
`brew install rtk`; no Windows, ele baixa o arquivo `.zip` da ferramenta e ajusta o PATH — a
"lista de lugares onde o sistema procura programas").

Duas opções de linha de comando úteis aqui:
- `--yes` (Windows: `-Yes`) — aceita instalar tudo sem perguntar, bom se você já sabe que quer
  tudo.
- `--skip-tools` (Windows: `-SkipTools`) — pula essa etapa inteira.

Se você recusar alguma instalação, ou ela falhar por algum motivo, nada quebra — o sistema
simplesmente segue sem aquela ferramenta (o que chamamos de "fail-soft" no glossário acima), e
você pode instalar depois manualmente.

### Instalação assistida por IA (recomendado para quem tem pouca prática com terminal)

Não quer rodar os comandos sozinho, ou já tentou e travou em algum erro? Você pode pedir para
uma IA te guiar, um passo de cada vez:

1. Abra um Claude (pode ser o Claude Desktop ou o site claude.ai).
2. Copie todo o conteúdo do arquivo
   [`assist/INSTALL-ASSIST-PROMPT.md`](assist/INSTALL-ASSIST-PROMPT.md) e cole na conversa.
3. Siga a conversa — a IA vai te dar um comando por vez, sempre pronto para copiar e colar, e
   depois de cada passo vai te dizer exatamente como conferir se deu certo antes de seguir para o
   próximo.

Esse assistente foi escrito para linguagem simples, pergunta primeiro se você é Windows ou
macOS, resolve um problema de cada vez (nunca uma lista de 10 possíveis causas ao mesmo tempo), e
nunca vai pedir para você colar senhas ou tokens no chat.

### Verificação pós-instalação

Depois de instalar, rode estes dois comandos para conferir que tudo ficou no lugar:

```bash
claude doctor        # confere a saúde geral do Claude Code
claude plugin list   # deve aparecer "bsaios-core" na lista
```

Depois, abra uma sessão nova do Claude Code. Você deve ver:
- A barra de status (statusline) no topo da tela, mostrando pasta, branch, modelo de IA e uma
  barra de quanto da "memória de conversa" já foi usada.
- Ao digitar `/bsaios-core:ecc-guide`, o assistente responde com o guia de todas as skills
  disponíveis.

Se algum desses dois pontos não aparecer, volte para a seção "Instalação assistida por IA" acima
e cole o prompt de ajuda — o arquivo já tem uma lista de problemas comuns e como resolver cada
um.

## Notas por sistema

- **RTK (a ferramenta que economiza cerca de 70% do consumo de IA em comandos de git/npm/gh):**
  - *macOS:* funciona de forma automática e transparente — todo comando que você roda passa por
    ele sem você precisar fazer nada. Se o RTK não estiver instalado, isso simplesmente não
    acontece, sem travar nada (fail-soft).
  - *Windows nativo (fora do WSL):* não existe esse modo automático. Em vez disso, o assistente
    aprende via o arquivo `CLAUDE.md` a chamar o comando `rtk <comando>` explicitamente quando
    precisar. Isso é esperado, não é um defeito.
- **Python:** no Windows o comando é `python`; no macOS é `python3`. Os arquivos que o instalador
  gera já vêm com o comando certo para o seu sistema — por isso, não copie o arquivo
  `settings.json` de um computador Windows para um Mac (ou vice-versa); sempre rode o instalador
  no sistema de destino.
- **GateGuard:** vem **ligado** por padrão. Ele bloqueia a primeira vez que o assistente tenta
  editar um arquivo, e o primeiro comando de terminal de cada sessão, até ele demonstrar que
  checou o contexto antes de agir. Isso é intencional — um treino de disciplina contra edições às
  cegas, não um bug. Se ele estiver atrapalhando demais e você quiser ajustar ou desligar
  temporariamente, veja as opções de escape em [`docs/gateguard.md`](docs/gateguard.md) (por
  exemplo, rodar `ECC_GATEGUARD=off claude` no Mac, ou `$env:ECC_GATEGUARD="off"; claude` no
  Windows, para desligar só naquela sessão).
- **"Context canary" (o assistente te chamar pelo nome):** o `CLAUDE.md` instrui o assistente a
  te chamar **pelo seu nome** (o que você preencheu durante a instalação) em toda resposta. Isso
  não é só cortesia — é um sinal de saúde: se o assistente parar de te chamar pelo nome, é sinal
  de que as instruções globais estão "saindo" da memória de conversa efetiva, e é hora de limpar
  o contexto com `/clear`.
- **Regra contra complicar demais o código ("lazy-senior"):** essa regra, sempre ativa, obriga o
  assistente a passar por uma checagem de 7 etapas antes de escrever qualquer código novo,
  perguntando primeiro "isso realmente precisa existir?" antes de criar algo. Ela mantém guardas
  de segurança e acessibilidade sempre presentes, inclui uma revisão que aponta o que pode ser
  apagado sem perda, e usa a marcação `bsheep:` no código para registrar decisões conscientes de
  simplificação (essas marcações podem ser encontradas depois com `grep -rn "bsheep:"`).

## Multiagentes? `/team-os`

**Quer que vários "ajudantes especializados" (agents) trabalhem juntos numa tarefa? Digite
`/team-os`.** É o ponto de entrada padrão do time para qualquer trabalho que envolva mais de um
agent: ele descobre quais agents estão disponíveis (do projeto, seus, de plugins, e os que já vêm
prontos), monta o time certo para a tarefa, coordena a comunicação entre eles e guarda a memória
do projeto para não repetir contexto. Já vem pronto com:

- Uma configuração especial (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) já ligada nas
  configurações geradas pelo instalador — sem ela, o team-os se recusa a começar por segurança.
- Os 21 agents citados na tabela acima como prontos para o team-os já vêm preparados para
  colaborar entre si (conseguem trocar mensagens e guardar memória). Os agents que vêm de
  plugins ou já embutidos entram como "consultores" — fazem tarefas fechadas, sem coordenar com
  outros.
- Ter o `jq` instalado (veja pré-requisitos) permite ao team-os descobrir também os agents que
  vêm de plugins. Sem ele, essa descoberta simplesmente não acontece, sem travar nada.

## Hooks do time — como se comportam

Aqui está o que cada "trava/lembrete automático" (hook) instalado realmente faz:

- **skill-suggester** — sugere a skill certa quando o assunto da sua mensagem combina com uma
  delas. A descoberta é dinâmica: uma skill nova que você instalar aparece sozinha nas sugestões,
  sem gastar processamento extra de IA para isso. Se um dia o time tiver skills demais e as
  sugestões ficarem cansativas, dá para criar o arquivo
  `~/.claude/hooks/team/suggest-allowlist.txt` listando só as skills principais, uma por linha
  (detalhes em [`harness/hooks/team/README.md`](harness/hooks/team/README.md)).
- **loop-detector** — percebe quando a mesma mensagem se repete 3 vezes seguidas e intervém, para
  evitar ficar preso num loop.
- **session-context** — assim que a sessão começa, já injeta informação sobre em que pasta você
  está, qual tecnologia o projeto usa e em qual branch (ramo de código) você está.
- **validate-agent-frontmatter** — avisa na hora se um dos arquivos de configuração de agent
  (`.claude/agents/*.md`) ficou com o cabeçalho técnico (YAML) quebrado — um tipo de erro
  silencioso que, sem esse aviso, já custou sessões inteiras de debug no time.
- **git-moment-advisor** — sugere o momento certo para fazer um commit ou um push, mas nunca age
  sozinho — só sugere, quem decide é você.
- **GateGuard** — já explicado no glossário e na seção "Notas por sistema" acima.

## MCPs (opcionais)

MCPs são "pontes" que dão ao Claude Code acesso a ferramentas externas. Neste projeto só existem
duas, e ambas são opcionais:

```bash
# Windows
claude mcp add --scope user context7 -- cmd /c npx -y @upstash/context7-mcp@latest
claude mcp add --scope user chrome-devtools -- npx -y chrome-devtools-mcp@latest

# macOS
claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp@latest
claude mcp add --scope user chrome-devtools -- npx -y chrome-devtools-mcp@latest
```

- **context7** dá acesso a documentação de bibliotecas/frameworks sempre atualizada.
- **chrome-devtools** dá acesso ao navegador para automações web.

Nenhuma ponte (MCP) que exija sua credencial pessoal faz parte deste pacote. Se um projeto
específico precisar de credenciais, elas devem viver em
`<projeto>/.claude/settings.local.json` (um arquivo que o Git ignora e nunca sobe para o
repositório) — nunca cole credenciais no chat e nunca as coloque neste repositório.

## Estrutura do repositório

```
black-sheep-aios/
├── README.md                  # este arquivo
├── install/
│   ├── manifest.json          # fonte única da verdade: pré-requisitos, comandos por SO, config do plugin
│   ├── install.ps1            # instalador para Windows
│   ├── install.sh             # instalador para macOS
│   └── lib/render-settings.js # gera as configurações certas para cada SO (usado pelos dois instaladores)
├── harness/                   # a "caixa de ferramentas" que vai para ~/.claude
│   ├── settings.team.json     # modelo de configuração (GateGuard ligado, multiagentes ligado)
│   ├── CLAUDE.md.template     # contexto global (seu nome/função são preenchidos na instalação)
│   ├── RTK.md                 # como usar o RTK (referenciado pelo CLAUDE.md)
│   ├── statusline-command.js  # a barra de status, funciona igual em Windows e Mac
│   ├── skills/ (6, incl. team-os)  agents/ (44)  hooks/  rules/ (8)
├── plugins/                   # o "marketplace local" (organizado por pasta)
│   └── bsaios-core/           # as 53 skills + GateGuard (ver README próprio dentro da pasta)
├── assist/INSTALL-ASSIST-PROMPT.md   # o prompt do assistente de instalação por IA
└── docs/
    ├── gateguard.md           # o que é o GateGuard e como ajustá-lo se precisar
    └── licenses.md            # créditos e licenças (ECC é MIT, etc.)
```

## Regras de ouro

1. **Nunca instale a versão original do "ECC" direto da internet** (pacote `affaan-m/ECC`) — isso
   sobrescreveria as melhorias exclusivas que o time já fez em cima dele. A versão que fica dentro
   deste repositório (`bsaios-core`) é a única fonte confiável.
2. **Segredos (senhas, tokens, chaves) nunca entram neste repositório nem no chat** — só
   marcadores de exemplo (placeholders).
3. **Mudou algo na caixa de ferramentas?** Edite o repositório, faça o commit, e todo mundo do
   time reinstala rodando o instalador de novo (ele faz backup automático de tudo que for
   sobrescrito, guardado em `~/.claude/backups/`).
