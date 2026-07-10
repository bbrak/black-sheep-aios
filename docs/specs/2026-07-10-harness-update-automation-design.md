# Spec — Automação de atualizações do harness (Black Sheep AIOS)

**Data:** 2026-07-10 · **Status:** Aprovado (design) → pronto para plano de implementação
**Origem:** brainstorming com o owner + workflow de 9 agentes (4 pesquisa · 4 debate · 1 síntese)
**Decisor:** Bernardo (owner, único com escrita no repo)

---

## 1. Problema

O harness é distribuído por um instalador que copia arquivos para `~/.claude` e gera
`settings.json`/`CLAUDE.md`. **Não existe história de atualização** além de "rode o instalador de
novo". Não há registro de qual versão o colaborador tem, nenhum aviso de novidade, nenhum diff, e
uma reinstalação hoje **apagaria as personalizações** do colaborador (o `settings.json` e o
`CLAUDE.md` são regenerados inteiros). Objetivo: propagar novas skills, mudanças de rules e hooks
com o **mínimo de atrito**, sem quebrar o que é pessoal.

## 2. Decisões já tomadas (contexto travado)

| Tema | Decisão |
|---|---|
| Interação do colaborador | Consegue **rodar 1 comando**. O prompt de IA de assist (`assist/`) deve cobrir o passo de update. Notificação automática = evolução futura. |
| Origem do repo | `git clone`, e a pasta **persiste** na máquina → `git pull` é viável. |
| Modelo de release | **Releases marcadas** (tag). Nada de `main` cru vazando pro time. |
| Personalização | Colaboradores **personalizam** o `~/.claude` → update **nunca** pode apagar o pessoal. |
| Arquitetura | **Híbrido faseado A→B**, refinado em **3 canais por raio de explosão**. |
| Visibilidade do repo | **Público** (já é), limpo de segredos → **sem atrito de auth** no Canal A. Escrita restrita ao owner. |

## 3. Modelo — 3 canais por raio de explosão

A regra de ouro: **automatize só o canal isolado; no que toca dados pessoais, avise e peça um "sim".**

| Canal | O que contém | Raio de explosão | Tratamento |
|---|---|---|---|
| **A — Plugin** | 53 skills + hooks do GateGuard | Baixo (sandbox, não toca nada pessoal) | **Automático** (marketplace via git) |
| **B — Arquivos de harness** | 44 agents, 8 rules, hooks soltos, statusline, RTK.md | Médio | **Semiautomático** (avisa → 1 comando) |
| **C — settings.json + CLAUDE.md** | config por-SO + identidade/dados pessoais | Alto (um merge ruim quebra todo mundo) | **Semiautomático, só merge, nunca sobrescreve** |

## 4. Fronteira time × pessoal (o coração da segurança)

- **Chaves "do time"** no `settings.json` = allowlist fixa (`env.ECC_DISABLED_HOOKS`, baseline de
  `permissions`, `hooks`, `statusLine`, `enabledPlugins`, `extraKnownMarketplaces`). Só essas o
  updater toca, via **merge 3-way**.
- **Chaves pessoais** (`model`/`theme`/`defaultMode`/`additionalDirectories`/MCPs pessoais) vivem em
  `settings.local.json` (já gitignored) — o updater **nunca** toca.
- **Identidade** (`nome`/`função`/`foco`) fica cacheada em `~/.claude/.bsaios/profile.json` no
  install, e o CLAUDE.md é **re-renderizado** dela, sem re-perguntar. O renderizador **se recusa a
  escrever** se a identidade estiver ausente ou se sobrar um placeholder `<...>`.
- **`settings.json` sempre re-renderizado na máquina de destino para o SO atual** — nunca sincronizar
  um arquivo renderizado entre SOs (Windows usa `python`; macOS `python3`; hook do RTK só no Mac).

## 5. Fases (ordem = maior corte de atrito primeiro)

### Fase 0 — Âncora de versão (PRÉ-REQUISITO) · ~0,5–1 dia
Sem isto, nada mais funciona (avisar, comparar, migrar, desfazer).
- `install/manifest.json` vira a **fonte única** da versão do produto; CI deriva as descrições/versões
  de `plugin.json`/`marketplace.json` e corrige o drift 49-vs-53 skills.
- `install.sh`/`install.ps1` gravam `~/.claude/.bsaios/version.json` `{product_version, git_sha,
  platform, installed_at}` como **último** passo bem-sucedido.
- Gravar `~/.claude/.bsaios/profile.json` `{name, role, focus}` no install (mata o bug do `<SEU NOME>`).
- Snapshot do inventário instalado em `~/.claude/.bsaios/manifest.installed.json` (permite **remover
  órfãos** depois — hoje um arquivo deletado no repo vive pra sempre na máquina).
- Criar `CHANGELOG.md` (Keep a Changelog).

**Entrega:** um harness que sabe a própria versão e identidade, com fonte única de versão e changelog.

### Fase 1 — Marketplace do plugin via git (MAIOR corte de atrito) · ~1 dia
"Dar push = publicar" as 53 skills + hooks, sem reinstalar, sem ação do usuário.
- Adicionar `.claude-plugin/marketplace.json` na **raiz do repo** apontando o plugin `bsaios-core`
  para um `source: github` (`bbrak/black-sheep-aios`); manter o marketplace de diretório até o cutover.
- Trocar em `harness/settings.team.json` o `extraKnownMarketplaces.bsaios.source` de
  `{source: directory}` para `{source: github, repo: bbrak/black-sheep-aios}` fixado numa tag
  `#stable`, com `autoUpdate: true`.
- Passo de **bootstrap** único no instalador: remove o marketplace de diretório antigo, re-adiciona o
  git, e **verifica que os hooks do GateGuard continuam vivos** depois.
- **VERIFICAR** na versão de Claude Code que o time usa que `/plugin marketplace update` realmente
  **puxa** (não só faz fetch) antes de anunciar como automático (ver §7). Fixar uma versão mínima.
- Embutir `/plugin marketplace update bsaios && /reload-plugins` como fallback confiável no futuro
  comando de update.

**Entrega:** após 1 bootstrap, avançar a tag `#stable` propaga skills+hooks pro time na próxima sessão.

### Fase 2 — Aviso: tornar a defasagem visível · ~0,5 dia
- Estender o hook de SessionStart já existente (`harness/hooks/team/session-context.js`) para comparar
  o `version.json` local com um `VERSION` buscado do raw do repo.
- Cachear em `~/.claude/.bsaios/update-check.json`, throttle diário, **só em TTY**, **fail-soft**
  (offline / sem git = silêncio, zero latência extra).
- Imprimir **uma** linha pt-BR: *"Black Sheep AIOS v1.3 disponível (você tem v1.1) — digite /bsaios-update"*.

**Entrega:** um banner não-bloqueante que transforma defasagem silenciosa em nudge acionável.

### Fase 3 — O comando único (Canais B + C) · ~2–3 dias
- Script Node **fora da sessão** (`bsaios update`) exposto como `/bsaios-update` in-session (shell-out,
  **nunca** edita arquivo direto → GateGuard não trava o updater). Wrapper `.command` (duplo-clique
  macOS) e `.cmd` chamando `powershell -ExecutionPolicy Bypass` no Windows, como caminho de recuperação.
- **Fluxo:** `git pull` de um **clone-fonte** em `~/.claude/.bsaios/repo` (nunca na árvore viva — evita
  CRLF/merge-conflict no Windows; fallback tarball via `git archive`) → imprime delta do CHANGELOG
  instalado→último → **1 sim/não** → roda migrations numeradas pendentes → **merge 3-way** do settings
  só nas chaves do time, re-renderizado por-SO → cópia só do que mudou + **prune de órfãos** →
  re-renderiza CLAUDE.md do `profile.json` → carimba a versão nova **por último**.
- **Transacional:** stage → verify (todo settings dá `JSON.parse`; todo arquivo do manifesto existe;
  todo comando de hook resolve pra um arquivo real) → swap atômico → stamp. Em qualquer falha, restaura
  o backup do início e **mantém a versão antiga**. **Idempotente:** rodar de novo = "já está atualizado".
- `install/migrations/NNNN-slug.js` — migrations ordenadas, idempotentes, uma única implementação
  cross-platform (sem duplicar `.sh`/`.ps1`); rodam só para versões acima do stamp. MINOR/aditivo com
  confirm leve; MAJOR força confirm + backup.

**Entrega:** colaborador atualiza harness+settings com 1 comando e 1 sim/não; pessoal e identidade
sobrevivem; órfãos são aposentados; meio-update é detectável e re-executável.

### Fase 4 — Trilhos de segurança · ~1–2 dias
- **Rollout em estágios:** duas refs do mesmo repo — `#latest` pra um canário (Bernardo + 1 voluntário),
  `#stable` pra todos; `#stable` só avança depois do canário rodar limpo ~1 dia. Rollback = repontar a tag.
- `/bsaios-rollback`: restaura (com confirm) o backup mais novo `~/.claude/backups/bsaios-<stamp>` +
  `version.json` anterior, **excluindo segredos** (`settings.local.json`/`.credentials.json`/`*.pem`/`*.key`),
  re-renderizado pro SO atual.
- **Rotação de backups** (manter últimos N, ex. 5) — a re-cópia do marketplace ~53-skill não pode crescer sem limite.
- Health check leve: verificar que os 3 plugins `claude-plugins-official` habilitados realmente carregam.

**Entrega:** canal canário/stable, undo em 1 comando pro colaborador, backups limitados, sinal de saúde.

## 6. Riscos-mãe e mitigações

| Risco | Mitigação |
|---|---|
| Regenerar `settings.json` cego destrói config pessoal | Nunca regenerar inteiro no update; merge só das chaves do time; pessoal em `settings.local.json`; **aborta tudo** se não der `JSON.parse`. |
| Re-run não-interativo corrompe identidade com `<SEU NOME>` | `profile.json` em cache; renderizador **recusa** escrever CLAUDE.md sem identidade / com placeholder `<...>`. |
| Auto-update nativo de plugin é bugado (fetch sem pull) | `version.json` é a fonte da verdade, não o runtime do plugin; embutir `/plugin marketplace update && /reload-plugins`; fixar versão mínima; verificar antes de anunciar auto. |
| Deleções/renames upstream nunca propagam (cópia é aditiva) | Prune por manifesto: `manifest.installed.json`; no update, deletar (com backup) `owned − novo-manifesto`, sem tocar em arquivos do usuário. |
| Hook/rule quebrada chega em todos de uma vez | Rollout em estágios: canário no `#latest`; time no `#stable` que só avança após ~1 dia limpo. Rollback = repontar ref. |
| Updater in-session trava no GateGuard | Updater é script **fora da sessão**; `/bsaios-update` só faz shell-out. |
| Armadilhas Windows (exec-policy, sem git, clone deletado, CRLF) | Wrapper `.cmd` com `-ExecutionPolicy Bypass`; render do clone-fonte (nunca da árvore viva); fallback tarball; falha com 1 linha clara se faltar git. |
| Apply não-transacional deixa árvore inconsistente | stage → verify → swap atômico → `version.json` por último; restaura backup em falha; idempotente. |
| Backups sem limite | Rotação keep-last-N + `/bsaios-rollback` com confirm. |

## 7. A VERIFICAR antes de construir (não assumir)

1. Que `source: github` + `autoUpdate: true` **realmente puxa** (avança a working tree) na versão de
   Claude Code do time — reproduzir/descartar o bug fetch-sem-merge (#49410/#44276/#26744) no build real.
2. A semântica exata de **merge do `settings.json`** entre escopos (arrays vs objetos vs escalares; e se
   `settings.local.json` tem precedência sobre o `settings.json` de usuário) — conferir na doc atual.
3. Se `/plugin marketplace update` + `/reload-plugins` aplicam na sessão **atual** ou só na **próxima**
   (muda o texto do banner "aplicado vs aplica ao reiniciar").
4. A sintaxe de fixar ref no marketplace git (`#tag` vs `#sha` vs `#branch`) e se **dois marketplaces**
   apontando pra refs diferentes do mesmo repo coexistem (pro split canário/stable).
5. Se os 3 plugins `claude-plugins-official` dependem de um marketplace built-in presente por padrão numa
   máquina nova de não-técnico.

## 8. Decisões resolvidas (owner, 2026-07-10)

| # | Decisão | Escolha |
|---|---|---|
| 1 | Shape do repo | **Repo único** — `marketplace.json` na raiz de `bbrak/black-sheep-aios`. |
| 2 | Postura do Canal B | **Avisa + comando; nada muda sozinho** (nem mudanças MINOR auto-aplicam). |
| 3 | Caminho do colaborador | **`/bsaios-update` no chat é o principal**; wrappers duplo-clique só como recuperação/emergência. |
| 4 | Contrato de versão | **Híbrido**: semver legível (`v1.3`) no `manifest.json` + `git_sha` no `version.json`. |
| 5 | Plumbing de merge | **Estender o `render-settings.js`** — sem chezmoi (YAGNI). |
| 6 | Canário | **Você + 1 voluntário, ~1 dia** na `#latest` antes de a `#stable` avançar. |
| 7 | Backups / rollback | **Manter últimos 5**; `/bsaios-rollback` desfaz o harness inteiro, exceto segredos. |
| 8 | Versão mínima de Claude Code | **Fixar após a verificação da §7** (a versão que comprovadamente puxa o plugin). |

## 9. Critérios de sucesso

- Colaborador recebe skills/hooks novos **sem fazer nada** (Canal A).
- Recebe rules/agents/settings novos com **1 comando + 1 sim/não**, sem perder nada pessoal (Canais B/C).
- Consegue **desfazer** com 1 comando.
- Owner publica com **1 ação** (avançar a tag `#stable`), e nada pela metade vaza.
- Uma reinstalação/atualização **nunca** re-pergunta identidade nem corrompe o `settings.json`.

## 10. Explicação para os colaboradores (linguagem simples)

> Imagina que todo mundo do time tem a **mesma caixa de brinquedos** (o Claude configurado do jeito
> certo). De vez em quando eu invento brinquedos novos ou conserto um quebrado.
>
> - **Uma parte chega sozinha.** Quando você abre o Claude, os brinquedos novos já estão lá — que nem
>   um app do celular que atualiza sozinho. Você não faz nada.
> - **No resto, aparece um aviso:** *"Saiu novidade! Digite /bsaios-update"*. Você digita, o Claude
>   pergunta *"quer atualizar? (sim/não)"*, você diz **sim**, e pronto. Ele troca só o que é do time e
>   **nunca mexe nas suas coisas** (seu nome, seus ajustes).
> - **Se algo sair errado**, tem um botão de desfazer: `/bsaios-rollback` volta pra como estava.
> - **Você nunca recebe coisa pela metade:** eu testo cada novidade comigo antes de liberar pro time.

---

### Apêndice — proveniência
Design derivado de um workflow multiagente (`harness-update-automation`, 9 agentes, 0 erros): 4
pesquisadores (grounding no repo · capacidades nativas do Claude Code · padrões externos de
distribuição · UX/versionamento/migração), 4 vozes de debate (automation-maximalist ·
semi-auto-pragmatist · safety-skeptic · non-technical-advocate) e 1 arquiteto de síntese.
