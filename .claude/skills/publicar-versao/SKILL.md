---
name: publicar-versao
description: >-
  Publica conteudo novo do Black Sheep AIOS (skills, rules, hooks, agents) para o time inteiro, do
  arquivo ate a notificacao. Use SEMPRE que o Bernardo, dentro do repo black-sheep-aios, disser algo
  como "quero colocar essa skill", "adiciona esse hook", "coloca essa regra", "sobe/lanca uma versao
  nova", "publica isso pro time", "manda pro time", "quero que todo mundo receba isso", ou entregar
  arquivos de skill/rule/hook para distribuir. A skill coloca os arquivos no lugar certo, aconselha o
  nivel de versao (patch/minor/major) e o canal (canario `latest` vs `stable`), e conduz todo o ciclo
  git (branch -> commit -> PR -> merge -> release.js -> mover tag). NAO use para o fluxo de atualizacao
  do lado do colaborador (isso e o /bsaios-update), nem para ingestao de reuniao.
---

# Publicar versao — Black Sheep AIOS

Voce vai conduzir a publicacao de conteudo novo do harness **para o time inteiro**, do arquivo ate a
notificacao. O Bernardo **gosta de saber o que esta acontecendo, mas nao quer executar** — voce faz o
trabalho e so para nos **dois pontos de decisao** (nivel de versao e canal) e na **confirmacao final**
antes de qualquer coisa sair para fora.

O repo e a fonte da verdade: `bbrak/black-sheep-aios`. O time recebe o que esta **no `main` E apontado
pela tag `stable`**. O numero de versao (`install/manifest.json`) e o que dispara o banner de update.

## Nao-negociaveis (nunca cortar)

1. **Nunca** suba a versao ou mova tag na mao. Sempre `node install/lib/release.js <nivel>` para o bump.
2. **Nunca** faca push/PR/tag sem um "sim" explicito do Bernardo. Isso sai para fora e notifica o time.
3. **CHANGELOG obrigatorio.** Todo conteudo em `plugins/` ou `harness/` precisa de entrada em
   `## [Não lançado]` no MESMO diff. O gate de CI (`check-release.js`) bloqueia o merge sem isso.
4. **Push de tag e feito pela conta `bbrak`**; ao terminar, **volte para `brokersbrasiledu-collab`**.
5. Trabalhe sempre em **branch** a partir do `main` atualizado. Nunca commite direto no `main`.

## Onde cada artefato entra

| Artefato entregue | Destino no repo | Extra |
|---|---|---|
| Skill (plugin, todo o time) | `plugins/bsaios-core/skills/<nome>/SKILL.md` (+ arquivos de apoio) | conta em R2 do gate |
| Skill de usuario (harness) | `harness/skills/<nome>/SKILL.md` | conta em R2 |
| Regra | `harness/rules/<nome>.md` | conta em R2 |
| Agent | `harness/agents/<nome>.md` | conta em R2 |
| Hook | `harness/hooks/<arquivo>` | **+ registrar em `harness/settings.team.json`** |

Hook nao basta dropar o arquivo: registre-o no `settings.team.json` (bloco `hooks`) ou o harness nao
sabe que ele existe. Skill/rule/agent sao "so o arquivo".

## O fluxo (siga em ordem)

### Fase 0 — Pre-voo
```bash
git -C <repo> switch main && git -C <repo> pull --ff-only
git -C <repo> status --short   # tem que estar limpo
```
Se houver WIP sujo, pare e pergunte antes de continuar.

### Fase 1 — Entender o que entra
Identifique cada artefato que o Bernardo entregou e seu destino (tabela acima). Se algo estiver
ambiguo (nome da skill, se o hook e de time ou pessoal), **pergunte de forma curta** antes de colocar.
Crie a branch:
```bash
git -C <repo> switch -c feat/<descricao-curta>
```

### Fase 2 — Colocar os artefatos
- Copie cada arquivo para o destino certo.
- Para **hook**, registre no `harness/settings.team.json`.
- Valide o frontmatter da skill/agent (o repo tem `harness/hooks/validate-agent-frontmatter.py`).

### Fase 3 — Contagens do README + CHANGELOG
- Escreva a entrada em `CHANGELOG.md`, secao `## [Não lançado]`, em linguagem de gente ("Adicionada
  skill X que faz Y"; "Novo hook Z que valida W").
- Rode o gate localmente para pegar as contagens do README **antes** do CI:
  ```bash
  node <repo>/install/lib/check-release.js
  ```
  Se ele reclamar de R2 (contagens do README defasadas), ele **imprime o numero certo** — atualize no
  `README.md` o total **e** o detalhamento (ex: `53 = 49+4` vira `54 = 50+4`). R2 e correcao humana de
  proposito; os arquivos-maquina (VERSION, plugin.json...) o `release.js` cuida.
- Commit do conteudo:
  ```bash
  git -C <repo> add -A
  git -C <repo> commit -m "feat(<area>): <o que foi adicionado>"
  ```

### Fase 4 — DECISAO 1: nivel de versao (aconselhe + confirme)
Recomende segundo SemVer e confirme com o Bernardo numa frase:
- **patch** (`x.y.Z`) — so correcao de bug, sem capacidade nova.
- **minor** (`x.Y.0`) — **capacidade nova**: skill/rule/hook/agent novo. *(o caso comum)*
- **major** (`X.0.0`) — quebra algo que o time ja usava (removeu/renomeou/mudou comportamento).

Diga a versao resultante ("vai de 1.2.0 para 1.3.0, ok?") e siga com o "sim".

### Fase 5 — Cortar o release
```bash
node <repo>/install/lib/release.js <patch|minor|major>
```
Faz num comando: bump do `manifest.json` (fonte unica) + promove `[Não lançado]` -> `[X.Y.Z] — data`
+ `sync-manifest --write` (propaga versao/contagens para plugin.json, marketplace.json, VERSION) +
commit `chore(release): vX.Y.Z`. Depois, **verifique** que o gate passa:
```bash
node <repo>/install/lib/check-release.js
```
Tem que dizer `OK`. Se falhar, conserte o que ele apontar antes de seguir.

### Fase 6 — DECISAO 2: canal (aconselhe + confirme) e leve para a main
O modelo e **canario -> stable**, duas refs do mesmo repo:
- **`latest`** = canario (Bernardo + 1 voluntario testam primeiro).
- **`stable`** = time inteiro. So avanca depois do canario rodar limpo (~1 dia).

Aconselhe:
- Mudanca **substancial ou arriscada** (hook novo que roda em toda sessao, mudanca de comportamento)
  -> **canario primeiro**: mova so `latest` agora; o `stable` numa passada seguinte, apos o soak.
- Mudanca **pequena e segura** (uma skill isolada, um ajuste de texto) -> pode ir **direto pro time**
  (`latest` + `stable` juntos), se o Bernardo topar pular o soak.

Abra o PR e faca o merge (o CI roda o gate + os testes):
```bash
git -C <repo> push -u origin feat/<descricao-curta>
gh pr create --fill
# apos o CI verde e o "sim":
gh pr merge --squash --delete-branch
git -C <repo> switch main && git -C <repo> pull --ff-only
```

### Fase 7 — CONFIRMACAO FINAL + publicar (a unica parte que notifica o time)
Confirme numa frase: *"Vou publicar a vX.Y.Z pro [canario / time inteiro] movendo a tag [latest / latest+stable]. Confirma?"*

So com o "sim", mova a(s) tag(s). **A conta importa:**
```bash
gh auth switch -u bbrak
# canario:
git -C <repo> tag -f latest origin/main && git -C <repo> push -f origin latest
# time inteiro (se for direto, ou depois do soak do canario):
git -C <repo> tag -f stable origin/main && git -C <repo> push -f origin stable
gh auth switch -u brokersbrasiledu-collab   # SEMPRE volte
```

### Fase 8 — Validar e reportar
```bash
# a versao publicada tem que responder a nova versao:
node -e "require('https').get('https://raw.githubusercontent.com/bbrak/black-sheep-aios/stable/VERSION',r=>{let d='';r.on('data',c=>d+=c);r.on('end',()=>console.log('stable VERSION =',d.trim()))})"
```
Reporte ao Bernardo: versao publicada, canal, o que mudou, e que o time vera o banner na proxima sessao
(cada um roda `/bsaios-update`). Se foi so canario, lembre que o `stable` fica pendente para depois do soak.

## Rollback
Release ruim = **repontar a tag** (nao mexe em maquina de ninguem):
```bash
gh auth switch -u bbrak
git -C <repo> tag -f stable <commit-bom> && git -C <repo> push -f origin stable
gh auth switch -u brokersbrasiledu-collab
```
Do lado do colaborador, o desfazer e `/bsaios-rollback`.

## Resumo do ciclo (para explicar ao Bernardo quando ele perguntar)
branch -> colocar artefatos -> README/CHANGELOG -> `release.js <nivel>` -> PR -> merge -> mover tag
(`latest` canario, depois `stable` time). Conteudo enche o `main`; a tag `stable` abre a porta pro time.
