# Black Sheep AIOS — contexto do repo

Este repo **é** o harness do time (skills, agents, rules, hooks) + o instalador + a automação de
distribuição. O que é mergeado no `main` e apontado pela tag `stable` é o que **o time inteiro recebe**.

- **Owner:** Bernardo. Ele gosta de saber como funciona, mas **não quer executar o processo na mão** —
  o agente conduz e só para nas decisões e na confirmação de publicar.
- **Idioma:** português nas mensagens; código/config em inglês.

## Estrutura que importa

| Caminho | O que é |
|---|---|
| `plugins/bsaios-core/skills/` | skills do plugin (vão pro time via distribuição vendorizada) |
| `harness/skills/` · `harness/agents/` · `harness/rules/` · `harness/hooks/` | harness do time (escopo usuário) |
| `harness/settings.team.json` | settings do time (onde hooks são registrados) |
| `install/manifest.json` | **fonte única da versão** (`sync-manifest.js` propaga p/ VERSION, plugin.json, marketplace.json) |
| `install/lib/release.js` | corta o release: bump + promove CHANGELOG + sync + commit |
| `install/lib/check-release.js` | gate de CI (R1 changelog↔versão · R2 contagens do README · R3 conteúdo↔changelog) |
| `docs/harness-updates.md` | guia operacional de atualização (colaborador + owner) |

## Publicar conteúdo novo pro time → use a skill `publicar-versao`

Quando o Bernardo disser "quero colocar essa skill / esse hook / essa regra", "sobe uma versão", "manda
pro time" ou entregar arquivos pra distribuir, **acione a skill [`publicar-versao`](.claude/skills/publicar-versao/SKILL.md)**.
Ela conduz tudo: coloca os arquivos no lugar, aconselha nível de versão (patch/minor/major) e canal
(canário `latest` → `stable`), e faz o ciclo git (branch → commit → PR → merge → `release.js` → mover tag).

## Não-negociáveis

1. **Nunca** suba versão ou mova tag na mão — sempre `node install/lib/release.js <nível>`. Fazer manual
   já quase deixou o banner de update parado (versão não subiu → ninguém foi notificado).
2. **Nunca** faça push/PR/tag sem "sim" explícito do Bernardo — é o que notifica o time.
3. Conteúdo em `plugins/` ou `harness/` **exige** entrada no `CHANGELOG.md` `## [Não lançado]` no mesmo
   diff (o gate de CI bloqueia o merge sem isso).
4. Push de tag pela conta **`bbrak`**; ao terminar, **volte para `brokersbrasiledu-collab`**.
5. Trabalhe em branch a partir do `main` atualizado — nunca commite direto no `main`.

## Distribuição (como o time recebe)

Entrega ativa = marketplace de **diretório** (o instalador copia o plugin pra `~/.claude/plugins/`).
O colaborador vê um banner no SessionStart quando há versão nova e roda **`/bsaios-update`** (transacional,
nunca toca no pessoal). Desfazer: `/bsaios-rollback`. O banner lê a tag **`stable`** por padrão
(`latest` = canário, via `BSAIOS_UPDATE_REF=latest`). Detalhes em [`docs/harness-updates.md`](docs/harness-updates.md).
