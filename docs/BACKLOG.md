# Backlog — Black Sheep AIOS

> Registro de itens em aberto, oriundo de uma auditoria de melhoria do repositório. Documento
> vivo: atualize o campo `Status` conforme os itens avançam.

**Última atualização:** 2026-07-10

## Resumo

| ID | Item | Prioridade | Esforço | Status |
|---|---|---|---|---|
| [BSA-1](#bsa-1--sem-rede-de-segurança-automatizada-ci--testes) | Sem rede de segurança automatizada (CI/testes) | Alta | Baixo/Médio | Aberto |
| [BSA-2](#bsa-2--paridade-windowsmacos-mantida-na-mão) | Paridade Windows↔macOS mantida na mão | Alta | Médio | Aberto |
| [BSA-3](#bsa-3--drift-de-contagemversão-em-múltiplos-lugares) | Drift de contagem/versão em múltiplos lugares | Média | Baixo | Resolvido (Fase 0) |
| [BSA-4](#bsa-4--histórico-só-em-prosa-sem-changelog) | Histórico só em prosa, sem CHANGELOG | Média | Baixo | Resolvido (Fase 0) |
| [BSA-5](#bsa-5--polimentos-rápidos) | Polimentos rápidos (URL do repo, LICENSE, uninstall) | Baixa | Baixo | Aberto |

---

## BSA-1 — Sem rede de segurança automatizada (CI/testes)

**Prioridade:** Alta · **Esforço:** Baixo/Médio · **Status:** Aberto

### Por que importa

O core do produto é um instalador cross-platform (Windows + macOS) que copia dezenas de
arquivos para `~/.claude` e renderiza templates com tokens. Sem CI, qualquer quebra — um
frontmatter YAML inválido, um schema JSON desalinhado, uma divergência entre `install.sh` e
`install.ps1` — só aparece na máquina de alguém do time, depois do fato consumado (e depois do
backup já ter sido sobrescrito).

### Evidência

- Não existe diretório `.github/` no repo (confirmado: `ls -la` na raiz não lista `.github`).
- Não há nenhum arquivo de teste automatizado para o harness ou os instaladores (as únicas
  pastas com "test" no nome são skills vendorizadas do ECC —
  [`plugins/bsaios-core/skills/e2e-testing`](../plugins/bsaios-core/skills/e2e-testing) e
  [`plugins/bsaios-core/skills/react-testing`](../plugins/bsaios-core/skills/react-testing) —
  que são conteúdo do plugin, não testes do próprio repo).
- Os dois instaladores já suportam um modo dry-run pronto para ser usado em CI:
  `install/install.sh --dry-run` e `install/install.ps1 -DryRun` (ver cabeçalhos de uso em
  [`install/install.sh`](../install/install.sh) linha 3 e
  [`install/install.ps1`](../install/install.ps1) linha 2). O dry-run exige `--claude-home`/
  `-ClaudeHome`, não faz perguntas interativas e pula a instalação de pacotes (PyYAML) e o
  `rtk init`.
- O hook [`harness/hooks/validate-agent-frontmatter.py`](../harness/hooks/validate-agent-frontmatter.py)
  já sabe validar o YAML frontmatter de um agent — hoje só roda em tempo de sessão do Claude
  Code, não em CI contra os 44 arquivos de `harness/agents/*.md`.
- Há 10 JSON Schemas em [`plugins/bsaios-core/schemas/`](../plugins/bsaios-core/schemas/)
  (`ecc-install-config`, `hooks`, `install-components`, `install-modules`, `install-profiles`,
  `install-state`, `package-manager`, `plugin`, `provenance`, `state-store`) sem nada que valide
  os arquivos JSON do repo contra eles.

### Ação sugerida

- GitHub Actions com matrix `macos-latest` + `windows-latest` rodando `install.sh --dry-run` e
  `install.ps1 -DryRun` respectivamente.
- Reaproveitar `harness/hooks/validate-agent-frontmatter.py` como step de CI para validar todos
  os `harness/agents/*.md`.
- Validar os JSON de configuração do repo contra os schemas em
  `plugins/bsaios-core/schemas/`.
- `shellcheck` em todos os `.sh` (`install/install.sh`, `harness/hooks/*.sh`) e
  `PSScriptAnalyzer` em todos os `.ps1` (`install/install.ps1`).

---

## BSA-2 — Paridade Windows↔macOS mantida na mão

**Prioridade:** Alta · **Esforço:** Médio · **Status:** Aberto

### Por que importa

`install/install.sh` (macOS) e `install/install.ps1` (Windows) implementam a mesma lógica em
duas linguagens diferentes, mantidas manualmente em paralelo. Não há nada que garanta que os
dois instaladores continuam produzindo o mesmo resultado (mesmos arquivos copiados, mesmos
tokens de template resolvidos) depois de uma mudança em só um dos dois. Isso é exatamente o
tipo de divergência silenciosa que só aparece quando alguém do time reinstala no SO "errado".

### Evidência

- Os dois scripts espelham a mesma sequência de `backup_and_copy` / `BackupAndCopy` item a item
  — por exemplo, ambos copiam `harness/RTK.md`, `harness/statusline-command.js`, todo
  `harness/skills/*/`, todo `harness/agents/*.md` e os hooks
  (`install/install.sh` linhas 86-91, `install/install.ps1` linhas 80-89) — mas são arquivos
  distintos, sem teste que compare a saída dos dois.
- Ambos os instaladores dependem do mesmo renderizador de template
  [`install/lib/render-settings.js`](../install/lib/render-settings.js) para resolver os tokens
  `{{CLAUDE_HOME}}` e `{{PYTHON}}` em `harness/settings.team.json` e
  `harness/CLAUDE.md.template` — mas nada verifica que os valores finais batem entre o fluxo
  Bash e o fluxo PowerShell além da leitura manual do código.
- O README já documenta que a diferença de binário Python (`python` no Windows vs. `python3` no
  macOS) é intencional ("os arquivos gerados já vêm com o binário certo" —
  [`README.md`](../README.md) linha 76) — ou seja, já existe pelo menos uma divergência
  *esperada* que um teste de paridade precisaria saber tolerar, e nenhuma outra divergência
  documentada como esperada.

### Ação sugerida

Criar um teste de paridade (pode rodar como parte do CI do BSA-1) que execute os dois
instaladores em modo dry-run para o mesmo `--claude-home`/`-ClaudeHome` de destino e compare: a
lista de arquivos copiados (mesmos caminhos relativos), e os tokens `{{CLAUDE_HOME}}` /
`{{PYTHON}}` resolvidos por `render-settings.js` em cada saída — permitindo apenas as
divergências já documentadas como intencionais (ex.: binário Python).

---

## BSA-3 — Drift de contagem/versão em múltiplos lugares

**Prioridade:** Média · **Esforço:** Baixo · **Status:** Resolvido (Fase 0 — `install/manifest.json`
é a fonte única; `install/lib/sync-manifest.js` sincroniza `plugin.json`/`marketplace.json` e falha o
CI em drift; descrições corrigidas 49→53 skills)

### Por que importa

Números escritos à mão em múltiplos arquivos divergem da realidade assim que um deles muda e os
outros não acompanham. Isso já aconteceu: o `marketplace.json` descreve um estado anterior do
plugin que não bate com a contagem real hoje, e a versão do produto está sobreposta com a
versão de uma dependência vendorizada (ECC) de um jeito que confunde qual delas é a "versão do
Black Sheep AIOS".

### Evidência (contagens reais confirmadas nesta auditoria)

- Skills no plugin `bsaios-core`: **53** (`find plugins/bsaios-core/skills -maxdepth 1 -mindepth 1 -type d | wc -l` → 53).
- Agents em `harness/agents/`: **44** (`find harness/agents -maxdepth 1 -name "*.md" | wc -l` → 44).
- User skills em `harness/skills/`: **6**.
- Rules em `harness/rules/`: **8**.
- Todos batem com o que o [`README.md`](../README.md) (linhas 14, 15, 16) já reporta hoje — o
  README está correto.
- [`plugins/.claude-plugin/marketplace.json`](../plugins/.claude-plugin/marketplace.json) (campo
  `description` do plugin `bsaios-core`) ainda diz **"49 skills curadas (destiladas do ECC
  2.0.0-rc.1, com gold merge)... Os 21 agents ECC vivem no harness"** — desatualizado: hoje são
  53 skills (49 do ECC + 4 do Superpowers, conforme o próprio README linha 14) e os agents ECC
  enrolados são 21 de um total de 44 no harness (não "os agents ECC" isoladamente, como a frase
  sugere isoladamente).
- Versão declarada como `"1.0.0"` em dois lugares: [`install/manifest.json`](../install/manifest.json)
  linha 4 e [`plugins/.claude-plugin/marketplace.json`](../plugins/.claude-plugin/marketplace.json)
  (campo `version` do plugin `bsaios-core`).
- [`plugins/bsaios-core/VERSION.ecc`](../plugins/bsaios-core/VERSION.ecc) contém `2.0.0-rc.1` —
  essa é a versão do **ECC upstream vendorizado** (a fonte da qual as skills foram destiladas),
  não a versão do produto Black Sheep AIOS. O nome do arquivo (`VERSION.ecc`, com o sufixo)
  já deixa essa distinção razoavelmente clara, mas nada documenta explicitamente "isto não é a
  versão do produto" para quem for ler os três arquivos lado a lado.

### Ação sugerida

- Definir uma fonte única de verdade para a versão do produto (ex.: `install/manifest.json` como
  autoridade, com `marketplace.json` lendo/sincronizando dela em vez de duplicar o número).
- Escrever um script (ex. `scripts/check-counts.sh` ou similar) que gere as contagens de skills/
  agents/rules a partir do filesystem e falhe o CI (ver BSA-1) se o texto descritivo em
  `marketplace.json` ou `README.md` ficar defasado — ou, mais simples, eliminar os números
  escritos à mão em `marketplace.json` e apontar para o README como fonte da descrição.
- Adicionar uma linha explícita em `docs/licenses.md` ou no próprio `VERSION.ecc` esclarecendo
  que aquele número é a versão do ECC vendorizado, não do Black Sheep AIOS.

---

## BSA-4 — Histórico só em prosa, sem CHANGELOG

**Prioridade:** Média · **Esforço:** Baixo · **Status:** Resolvido (Fase 0 — `CHANGELOG.md` no formato
Keep a Changelog, com "UPDATE 001/002" migrados de `install/manifest.json`)

### Por que importa

O histórico do produto ("o que mudou entre versões") hoje só existe como texto solto dentro de
campos `note` de arquivos JSON de configuração — não é um formato que alguém abre para entender
"o que mudou desde a última vez que rodei o instalador". Combinado com o fato de o git ter um
único commit, não há hoje nenhum jeito estruturado de responder "o que esse update trouxe".

### Evidência

- `git log --oneline` retorna um único commit: `8b89988 Black Sheep AIOS v1 (UPDATE 002)` —
  o nome "UPDATE 002" só aparece na mensagem de commit e em notas JSON, não em um documento
  dedicado.
- [`install/manifest.json`](../install/manifest.json) linha 156 e linha 184 contêm texto livre
  mencionando "UPDATE 002" e "UPDATE 001" (ex.: *"UPDATE 001: os 21 agents ECC sairam do plugin
  - foram enrolados para o team-os... e agora vivem em harness/agents"*) — informação de
  changelog genuína, mas enterrada em um campo `note` de configuração de instalador, não em um
  arquivo dedicado a histórico.
- Não existe `CHANGELOG.md` em nenhum nível do repo (busca por `CHANGELOG*` não retornou
  resultado).
- O instalador já sabe fazer backup do que sobrescreve (`install/install.sh` linha 71:
  `BACKUP="$CLAUDE_HOME/backups/bsaios-$STAMP"`; `install/install.ps1` linha 64 equivalente),
  mas não usa esse backup para reportar diffs — o backup existe só como rede de segurança para
  restauração manual, não como insumo de um relatório de "o que mudou".

### Ação sugerida

- Criar `CHANGELOG.md` na raiz do repo no formato [Keep a Changelog](https://keepachangelog.com/),
  migrando o conteúdo já existente nas notas "UPDATE 001"/"UPDATE 002" de `install/manifest.json`
  como primeiras entradas.
- Fazer o instalador, ao final de uma reinstalação, comparar o conteúdo recém-copiado contra o
  backup mais recente em `~/.claude/backups/bsaios-*` e imprimir um resumo do que mudou desde o
  último install (arquivos adicionados/removidos/alterados).

---

## BSA-5 — Polimentos rápidos

**Prioridade:** Baixa · **Esforço:** Baixo · **Status:** Aberto

### Por que importa

Três detalhes pequenos, cada um de baixo esforço, mas que juntos afetam a primeira impressão
(onboarding) e a governança básica do repo (licença, plano de rollback).

### Evidência

**(a) Placeholder `<URL-DO-REPO>` no README apesar do remote já ser conhecido**
[`README.md`](../README.md) linhas 30 e 38 usam `git clone <URL-DO-REPO> black-sheep-aios` nos
blocos de instalação Windows e macOS, mas `git remote -v` já mostra
`origin https://github.com/bbrak/black-sheep-aios.git` configurado no repo local — o placeholder
podia ser substituído pela URL real.

**(b) Sem `LICENSE` na raiz do repo**
Não existe nenhum arquivo `LICENSE*` na raiz (`ls LICENSE*` não retorna nada). O que existe é
[`docs/licenses.md`](licenses.md) (atribuições de conteúdo vendorizado de terceiros: ECC MIT e
Superpowers MIT) e [`plugins/bsaios-core/LICENSE.ecc`](../plugins/bsaios-core/LICENSE.ecc) (texto
MIT do ECC especificamente). Nenhum dos dois cobre a licença do próprio código autoral do
Black Sheep AIOS (instaladores, hooks próprios, rules, templates) — decisão de licença/
visibilidade do repo em si ainda está em aberto.

**(c) Sem caminho de uninstall/rollback documentado**
O instalador faz backup automático do que sobrescreve
(`$CLAUDE_HOME/backups/bsaios-$STAMP` em `install/install.sh` linha 71 e equivalente em
`install/install.ps1` linha 64), mas não existe nenhum script ou seção de documentação que
explique como restaurar esse backup ou desinstalar o harness — hoje seria um processo manual
(copiar de volta os arquivos de dentro de `~/.claude/backups/bsaios-<stamp>/`).

### Ação sugerida

- (a) Trocar `<URL-DO-REPO>` por `https://github.com/bbrak/black-sheep-aios.git` no README.
- (b) Decidir a licença do código autoral do repo (e sua visibilidade — público/privado) e
  adicionar `LICENSE` na raiz, deixando `docs/licenses.md` só com as atribuições de terceiros.
- (c) Documentar (README ou `docs/`) o passo a passo de restaurar um backup de
  `~/.claude/backups/bsaios-<stamp>/`, ou criar um script `install/uninstall.sh` /
  `install/uninstall.ps1` que automatize isso.

---

## Escopo já decidido (fase 2)

O próprio [`README.md`](../README.md) (linha 7) já declara que os itens abaixo estão fora do
escopo do v1 por decisão, não por omissão — não fazem parte deste backlog de itens em aberto:

- **Curso** — conteúdo educacional sobre o harness.
- **Playbooks por função** — guias de uso específicos por papel/função dentro do time.
