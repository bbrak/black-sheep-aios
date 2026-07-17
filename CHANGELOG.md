# Changelog

Todas as mudanças notáveis do Black Sheep AIOS são documentadas aqui.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e o projeto usa
[Versionamento Semântico](https://semver.org/lang/pt-BR/). A versão do produto é definida por
[`install/manifest.json`](install/manifest.json) (fonte única); `plugin.json` e `marketplace.json`
sincronizam dela via [`install/lib/sync-manifest.js`](install/lib/sync-manifest.js).

## [Não lançado]

### Corrigido
- **macOS: o PATH agora chega ao terminal do VS Code.** O instalador gravava as linhas de PATH
  (`brew shellenv` + `~/.local/bin`) só no `~/.zprofile`, que é lido por shells de **login**
  (Terminal.app). O terminal integrado do VS Code — que o README manda usar — roda um shell
  **non-login**, que lê o `~/.zshrc` e **ignora** o `.zprofile`. Resultado numa instalação real:
  tudo instalado, mas o terminal do VS Code nunca via o PATH e o `claude` dava `command not found`.
  Agora o `append_profile` grava **nos dois** (`.zprofile` e `.zshrc`), idempotente por arquivo.
  Coberto pela nova cadeia de teste **H**.
- **macOS: `~/.local/bin` é criado antes de instalar `claude`/`graphify`.** Os dois instalam ali (o
  Claude nativo e o `uv tool install`); se o diretório não existia, podiam falhar antes de criá-lo.
  `ensure_local_bin` e `ensure_session_path` agora fazem `mkdir -p` primeiro.
- **macOS: falha do instalador do Claude vira erro visível.** O `curl | bash` do Claude Code passa a
  mostrar a saída na tela e a contar como `fail()` (com o comando de retry), em vez de virar só um
  aviso amarelo fácil de perder.
- **Instalação Windows robusta ao estado da máquina.** `bootstrap.ps1`/`install.ps1` deixam de
  depender de o winget estar saudável:
  - winget é validado por **execução** (`winget --version`), não só presença; se existe mas não
    roda (típico de conta recém-criada — App Installer não registrado, erro "não é possível o
    acesso ao arquivo"), tenta **auto-reparo** (`Add-AppxPackage -RegisterByFamilyName`) antes de
    cair para scoop.
  - cada pré-requisito ganha **cadeia de fallback** winget → scoop → **instalador oficial**
    (uv via `astral.sh`, jq via binário do release, VS Code via User Setup), verificada por
    capacidade (`Get-Command`) após cada método — só desiste no fim.
  - `graphify` instala o `uv` sozinho se faltar e injeta `~/.local/bin` no PATH da sessão
    (fim do `'uv' não é reconhecido`).
  - `agent-browser` injeta o bin global do npm no PATH **antes** de `agent-browser install`
    (fim do `'agent-browser' não é reconhecido`); registro da skill sem `find-skills`.
  - PyYAML tenta `pip install --user` como fallback.
- **Instalação macOS — paridade com os fixes já aplicados no Windows.** Auditoria dos instaladores
  macOS contra as 6 classes de problema corrigidas no Windows. O PyYAML, principal suspeito, estava
  **correto**: a cadeia `--break-system-packages || --user` cobre tanto o Python do Homebrew (que é
  externally-managed por PEP 668) quanto o da Apple (que rejeita a flag mas não tem o marcador). Os
  defeitos reais eram outros:
  - **`graphify` quebrava de forma permanente** em todo Mac onde o `claude` já existia por outra via.
    `ensure_local_bin`/`append_profile` viviam dentro do ramo `else` de `if have claude`
    ([`bootstrap.sh`](install/bootstrap.sh)), então o `~/.local/bin` — destino dos bins do
    `uv tool install` — nunca entrava no PATH nem no `~/.zprofile`, e `uv tool install graphifyy &&
    graphify install` morria no segundo elo. O PATH passa a ser resolvido incondicionalmente, e o
    [`install.sh`](install/install.sh) ganhou `ensure_session_path` — paridade com o
    `Update-SessionPath` do `install.ps1`, que já fazia isso no Windows.
  - **`append_profile` não era idempotente** para o `~/.local/bin`: a agulha usava `$HOME` expandido
    enquanto a linha gravada guarda `$HOME` literal, então nunca casavam e o `~/.zprofile` ganhava
    uma linha nova a cada execução. Agora coberto por teste.
  - **"TUDO PRONTO" era incondicional** — aparecia intacto num Mac onde o Homebrew morreu e nada foi
    instalado, e o Passo 6 do README manda fechar o terminal logo em seguida, destruindo os avisos.
    Agora há um canal `fail()` separado do `warn()` informativo, o banner é gateado por ele, e o exit
    code reflete o resultado.
  - **Identidade vazia derrubava o instalador** com um erro de node no meio do passo [4/7]: bastava
    apertar Enter em "Áreas de foco", porque o `render-settings.js` recusa identidade vazia sob
    `set -e`. Agora o instalador pergunta até obter resposta e, sem terminal, falha cedo com o
    comando pronto.
  - **VS Code era reinstalado por cima de si mesmo:** o Passo 1 do README manda arrastar o app para
    Aplicativos, o que não instala o CLI `code`; o `have code` dava falso e o cask falhava por app
    existente — com o erro engolido. Agora o `.app` é detectado.
  - **Homebrew era detectado por presença, não por execução**, e sem fallback: um brew com o Xcode
    CLT quebrado passava no teste `-x` e derrubava tudo em cascata até o `ERRO: node e obrigatorio`.
    Agora há `brew_works()`, diagnóstico de CLT, e o `uv` ganhou o instalador oficial da Astral como
    fallback (paridade com o winget→scoop do Windows).
  - **Falhas silenciosas:** o cask do VS Code, o `pip` do PyYAML e os passos de pós-instalação
    engoliam o erro com `>/dev/null 2>&1`. O helper `run_logged` mantém o caminho feliz silencioso e
    mostra o fim da saída real quando algo falha.
  - **Stub do Xcode CLT era tratado como ferramenta instalada.** Num Mac zerado, `/usr/bin/git` e
    `/usr/bin/python3` existem como stubs do CLT que `command -v` acha mas que não rodam. O passo de
    pré-requisitos ganhou uma checagem de `xcode-select -p`, e o `bootstrap.sh` passou a detectar
    git/node/python por **execução** (`git --version`) em vez de presença — antes imprimia `[ok] git
    ja instalado` em verde e o clone morria dois passos depois culpando a rede.
  - [`install/manifest.json`](install/manifest.json): o comando do `agent-browser` estava defasado
    desde `fbbd968` (sem `-a claude-code -g -y` e sem a remoção do `find-skills`) — a "fonte única"
    ainda ensinava o comando que causava o EPERM.

### Adicionado
- [`bootstrap-check.sh`](install/test/bootstrap-check.sh): cadeias **F** (done-signal honesto) e **G**
  (identidade vazia falha com mensagem humana, sem vazar stack de node), mais assertivas de
  persistência e idempotência do `append_profile`. De 20 para 29 checks.
- `BSAIOS_PROFILE`: costura de teste que permite exercitar o `append_profile` de verdade sem escrever
  no `~/.zprofile` de quem roda o teste.

### Modificado
- O check de não-poluição do [`bootstrap-check.sh`](install/test/bootstrap-check.sh) passou a vigiar a
  **superfície do harness** em vez de contar arquivos do `~/.claude`: o próprio Claude Code escreve lá
  continuamente (transcripts, logs, backups rotativos), o que tornava o teste flaky justamente quando
  rodado de dentro de uma sessão do Claude.

## [1.1.0] — 2026-07-10

### Adicionado
- **Âncora de versão:** os instaladores gravam `~/.claude/.bsaios/version.json`
  `{product_version, git_sha, platform, installed_at}` como último passo bem-sucedido — o harness
  passa a saber a própria versão (base para avisar, comparar, migrar e desfazer).
- **Identidade cacheada** em `~/.claude/.bsaios/profile.json` `{name, role, focus}` — permite
  re-renderizar o `CLAUDE.md` num update sem re-perguntar. O renderizador
  ([`render-settings.js`](install/lib/render-settings.js)) agora **recusa escrever** com identidade
  ausente ou placeholder `<...>` (mata o bug do `<SEU NOME>`).
- **Inventário instalado** em `~/.claude/.bsaios/manifest.installed.json` — base para aposentar
  órfãos num update sem tocar em arquivos do usuário.
- [`install/lib/sync-manifest.js`](install/lib/sync-manifest.js): fonte única de versão + guarda de
  drift de contagem para CI (resolve BSA-3).
- **Marketplace git** na raiz ([`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json)) +
  `verify-harness.js` (health check "GateGuard vivo"). O marketplace de diretório segue como entrega
  ativa até o cutover (ver [`docs/harness-updates.md`](docs/harness-updates.md)).
- **Banner de defasagem** no SessionStart ([`update-check.js`](harness/hooks/team/update-check.js)):
  cache diário, refresh destacado (zero latência), fail-soft.
- **`/bsaios-update`** — updater transacional fora da sessão ([`bsaios-update.js`](install/lib/bsaios-update.js)):
  backup → apply → verify → em falha restaura e mantém a versão antiga; merge só das chaves do time
  (aborta se o `settings.json` não der `JSON.parse`); prune de órfãos; idempotente. Migrations
  numeradas em `install/migrations/`. Comando in-session + wrappers `.command`/`.cmd`.
- **`/bsaios-rollback`** + rotação de backups (mantém os últimos 5), excluindo segredos.
- **CI** ([`.github/workflows/harness-ci.yml`](.github/workflows/harness-ci.yml)) + teste de regressão
  do ciclo install→update→rollback ([`install/test/cycle.sh`](install/test/cycle.sh)) — cobre BSA-1.
- **Frescor de docs automático:** [`release.js`](install/lib/release.js) (release de 1 comando: bump +
  promove o CHANGELOG + propaga versão/contagem + commit) e o gate [`check-release.js`](install/lib/check-release.js)
  no CI — bloqueia o merge se a versão subir sem seção no CHANGELOG, se as contagens do README mentirem,
  ou se conteúdo do harness mudar sem registro no CHANGELOG. Regressão em
  [`install/test/release-guard.sh`](install/test/release-guard.sh).

### Corrigido
- Descrições de `plugin.json` e `marketplace.json`: **49 → 53 skills**; a frase dos "21 agents ECC"
  agora esclarece o total de **44 agents** no harness (resolve BSA-3).

## [1.0.0] — 2026-07-07

Primeira versão marcada do Black Sheep AIOS. Consolida "UPDATE 001" e "UPDATE 002", que antes só
existiam em campos `note` de `install/manifest.json` e na mensagem de commit.

### Adicionado (UPDATE 002)
- 4 skills vendorizadas do Superpowers v6.1.1 no plugin `bsaios-core`: `brainstorming`,
  `systematic-debugging`, `using-git-worktrees`, `finishing-a-development-branch` (total: **53 skills**).
- 8 agents de marketing/negócio em `harness/agents/`: `paid-social-strategist`, `email-strategist`,
  `tracking-specialist`, `aeo-foundations`, `ai-citation-strategist`, `ads-auditor`, `fpa-analyst`,
  `feedback-synthesizer` (total: **44 agents**).

### Mudado (UPDATE 001)
- Os 21 agents ECC saíram do plugin e foram **enrolados para o team-os** (SendMessage, memory:user);
  agora vivem em `harness/agents/` (escopo usuário), instalados em `~/.claude/agents/`.

### Base
- Harness cross-platform (Windows + macOS): plugin `bsaios-core` (53 skills + GateGuard), 6 user
  skills, 44 agents, 8 rules, hooks do time, statusline Node, `settings.json`/`CLAUDE.md` gerados
  por SO. `VERSION.ecc` = `2.0.0-rc.1` é a versão do **ECC vendorizado** (origem das skills), não a
  versão do produto.
