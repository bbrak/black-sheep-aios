# Changelog

Todas as mudanças notáveis do Black Sheep AIOS são documentadas aqui.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e o projeto usa
[Versionamento Semântico](https://semver.org/lang/pt-BR/). A versão do produto é definida por
[`install/manifest.json`](install/manifest.json) (fonte única); `plugin.json` e `marketplace.json`
sincronizam dela via [`install/lib/sync-manifest.js`](install/lib/sync-manifest.js).

## [Não lançado]

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
