# Atualizações do harness — guia operacional

Como o Black Sheep AIOS se atualiza no time, o que é automático, o que precisa de 1 comando, e como
o owner publica. Design completo em [`docs/specs/2026-07-10-harness-update-automation-design.md`](specs/2026-07-10-harness-update-automation-design.md).

**Versão mínima de Claude Code: `>= 2.1.206`** (a versão em que o comportamento foi verificado — ver
"§7 na vida real" abaixo).

## Para o colaborador (o dia a dia)

- **Skills/hooks do plugin** chegam pela distribuição vendorizada — você **não faz nada** além de
  atualizar quando avisado.
- Quando sai novidade, o SessionStart mostra **uma linha**:
  *"Black Sheep AIOS vX disponível (você tem vY) — rode /bsaios-update"*.
- **`/bsaios-update`** (no chat) é o caminho principal: mostra o que mudou, pergunta **sim/não**, e
  aplica. Nunca toca no seu pessoal (`settings.local.json`, credenciais, `model`/`theme`). Aplica na
  **próxima sessão** (rode `/reload-plugins` ou reinicie).
- Deu ruim? **`/bsaios-rollback`** desfaz para o backup anterior (seus segredos nunca são tocados).
- Recuperação sem o chat: duplo-clique em `~/.claude/.bsaios/bsaios-update.command` (macOS) ou
  `bsaios-update.cmd` (Windows).

## O que vive em `~/.claude/.bsaios/`

| Arquivo | Papel |
|---|---|
| `version.json` | `{product_version, git_sha, platform, installed_at}` — a âncora de versão. |
| `profile.json` | `{name, role, focus}` — identidade cacheada; re-renderiza o CLAUDE.md sem re-perguntar. |
| `manifest.installed.json` | inventário do que o harness possui (base do prune de órfãos). |
| `update-check.json` | cache do banner de defasagem (throttle diário, fail-soft). |
| `repo/` | clone-fonte que o updater dá `git pull` (nunca a árvore viva). |
| `updater/` | cópia estável do updater (roda fora da sessão; não bate no GateGuard). |
| `*.command` / `*.cmd` | wrappers duplo-clique de recuperação. |

## Para o owner (publicar)

O modelo é **canário → stable**, duas refs do **mesmo** repo:

- **`bsaios-latest`** aponta para a ref `latest` (canário: você + 1 voluntário).
- **`bsaios`** aponta para a ref `stable` (todo o time). `stable` só avança depois do canário rodar
  limpo ~1 dia. **Rollback de um release ruim = repontar a tag** (não precisa mexer em máquina).

Publicar uma versão:

1. Suba a mudança no repo e rode `node install/lib/sync-manifest.js --write` (sincroniza versão +
   contagens em `plugin.json`/`marketplace.json`/`VERSION`). Faça o bump de `install/manifest.json`.
2. Atualize o `CHANGELOG.md` (seção nova). Commit.
3. Aponte a tag `latest` para o commit (canário recebe).
4. Depois do canário limpo, aponte `stable` para o mesmo commit (o time recebe; o banner acende).

## Cutover para o marketplace git (ação do owner, **pendente**)

Hoje a entrega ativa é o **marketplace de diretório** (o instalador copia o plugin para
`~/.claude/plugins/bsaios-marketplace`). A infra do marketplace **git** já está pronta
([`.claude-plugin/marketplace.json`](../.claude-plugin/marketplace.json) na raiz). O cutover é **1 ação
do owner** e ainda **não** foi feito, de propósito:

1. Criar e empurrar as tags `stable` e `latest` no repo (elas ainda não existem — sem elas, apontar o
   `settings.json` para o git quebraria a sessão de todo mundo).
2. Trocar em `harness/settings.team.json` o `extraKnownMarketplaces` para o formato de **duas refs
   nomeadas** (o `#ref` só funciona na CLI; no `settings.json` é um campo `ref` separado — verificado
   no 2.1.206):

   ```json
   "extraKnownMarketplaces": {
     "bsaios":        { "source": { "source": "github", "repo": "bbrak/black-sheep-aios", "ref": "stable" } },
     "bsaios-latest": { "source": { "source": "github", "repo": "bbrak/black-sheep-aios", "ref": "latest" } }
   }
   ```

3. No próximo install, o marketplace git registra. **Não** use `claude plugin marketplace add` para o
   segundo ref — a CLI deriva o nome do repo e **sobrescreve** o primeiro; só o `settings.json` deixa
   dois refs coexistirem.

## §7 na vida real (Claude Code 2.1.206) — o que foi verificado

- **`plugin marketplace update` só busca metadados, não faz merge do conteúdo** (bug fetch-sem-merge,
  issues #49410/#44276/#26744). Por isso o Canal A **não é anunciado como "automático"**: a fonte da
  verdade é o `version.json` + o comando de update, **não** o runtime do plugin. Reavaliar quando a
  Anthropic corrigir.
- **Merge de settings**: arrays concatenam+dedupe, objetos deep-merge, `local > user`. Nosso updater
  faz merge **só das chaves do time** e o `settings.local.json` (pessoal) sempre vence no runtime.
- **Aplicar update**: `/reload-plugins` tenta aplicar na hora, mas o confiável é **reiniciar a sessão**
  (por isso o banner diz "aplica ao reiniciar").
- **Marketplace oficial**: numa máquina nova, o instalador precisa registrar
  `anthropics/claude-plugins-official` explicitamente (não vem por padrão antes do 1º launch interativo).

## Segurança do update (não-negociáveis)

- **Transacional**: backup → apply → verify → em falha restaura o backup e **mantém a versão antiga**;
  o `version.json` é carimbado **por último**. **Idempotente**: rodar de novo = "já está atualizado".
- **Merge-only no settings**: só as chaves do time; pessoal em `settings.local.json`, nunca sobrescrito.
- **Identidade via `profile.json`**: o renderizador **recusa** escrever o CLAUDE.md com placeholder `<...>`.
- **Prune de órfãos**: `owned_antigo − owned_novo`, sempre com backup, sem tocar em arquivos do usuário.
- **Backups**: mantém os últimos 5 (rotação automática). `/bsaios-rollback` desfaz tudo, exceto segredos.
