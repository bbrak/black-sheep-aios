# Spec — Onboarding amigável: bootstrap de 1 comando + README do zero (Black Sheep AIOS)

**Data:** 2026-07-10 · **Status:** Fases 1-2 implementadas e testadas (bootstrap.sh 20/20 no teste isolado + review adversarial aplicado; bootstrap.ps1 em paridade, **pendente gate de máquina Windows real**; README reescrito). Falta: prints + teste com colaborador real (Fase 3) e **publicar** (mover a tag `stable`) para o comando ficar vivo. Ver §7.1.
**Origem:** pedido do owner (colaboradores sem prática de terminal travando na instalação)
**Decisor:** Bernardo (owner, único com escrita no repo)

---

## 1. Problema

A instalação atual assume que o colaborador **já tem Homebrew, git, node e o Claude Code** na máquina.
Quem nunca usou terminal não passa da primeira tela: não sabe abrir o Terminal, não sabe o que é
Homebrew, colava comandos que assumiam ferramentas ausentes, e o README (334 linhas) afoga o iniciante
em vez de guiá-lo. O resultado: os primeiros colaboradores **desistem ou pedem ajuda 1-a-1** — não
escala.

O objetivo: sair de **"Mac/PC zerado"** até **"harness instalado e Claude aberto"** com o **mínimo de
atrito** — idealmente **um único paste** — e um README que começa do absoluto zero.

## 2. Decisões já tomadas (contexto travado)

| Tema | Decisão |
|---|---|
| Ambição | **Bootstrap de 1 comando** (macOS: `curl \| bash`; Windows: 1 linha PowerShell) que instala as dependências ausentes (Homebrew/winget → git/node → Claude Code) e então roda o instalador do harness. **+ README reescrito do zero.** Sem app gráfico/instalador empacotado por enquanto. |
| Entrega desta sessão | **Um spec aprovado.** A implementação é de uma sessão futura (via `/goal`, como foi o update automation). O owner revisa antes de qualquer código. |
| Paridade de SO | **Windows + macOS iguais** desde o início (regra do harness: nunca privilegiar um SO). |
| Fonte da verdade | O bootstrap **reaproveita** `install/install.sh` / `install/install.ps1` (que já detectam faltantes e têm `ext_tool`/`Invoke-ExtTool`). O bootstrap só resolve o degrau **anterior**: instalar o gerenciador de pacotes + o Claude, que hoje o instalador só *sugere*. |
| Não-destrutivo | Vale a mesma regra do update: **idempotente e fail-soft**; rodar de novo não quebra nada; nunca sobrescreve o pessoal. |

## 3. Evidências dos colaboradores — dores REAIS (Fase 0 concluída)

> **Fonte:** reunião de **instalação ao vivo de 09/07** — 5 colaboradores de marketing instalando Claude
> Code + harness pela primeira vez (~3h15). É a única fonte com dores de instalação; as 4 reuniões
> secundárias (07/02, 07/06, 07/06-R2, 06/25) são onboarding de negócio/cultura e não têm dor de setup.
> Cada dor está ancorada em **citação verbatim + linha** da transcrição bruta
> (`00_inbox/processados/Reuniao_implementacao_IA_09-07.md`), extraída por 6 leitores paralelos e
> **verificada adversarialmente** (5 de 20 citações tinham o falante trocado — corrigidas em §3.2; a
> substância de todas se confirmou).

### 3.1 Hipóteses D1–D9 — veredito

| # | Veredito | Enquadramento real | SO | Freq. | Grav. | Evidência (linha) |
|---|---|---|---|---|---|---|
| D1 | 🔁 reenquadrada | Não é "não sei abrir o Terminal.app" — é **o terminal escondido dentro do VS Code**; travou antes do passo 1 e o facilitador socorreu 3-4 pessoas | ambos | 3+ | alta | Eduardo "para abrir o terminal no VS Code" (1284); João A. "eu não consigo abrir o terminal assim" (1307), "auxiliei umas três, quatro pessoas… eu mesmo travei" (1305) |
| D2 | ✅ confirmada | Gerenciador de pacotes ausente e **não declarado como pré-requisito** (brew no Mac, equivalente no Windows); trava logo no início | ambos | 3 | alta | João A. "Ele não tem o home brew para instalar" (1623); Eduardo "o Rome Bri não tava instalado. Absurdo" (2850); João M. "tinha que instalar o Home Brew do Windows… esqueci o nome" (2972) |
| D3 | ✅ confirmada (**crítica**) | Pós-install `claude` não reconhecido — **PATH não recarrega na mesma sessão** (Mac: reabrir terminal; Windows: editar variáveis de ambiente na mão, mesmo após todo o passo a passo) | ambos | 3 | crítica | João M. "fez todo o passo a passo do Cloud, ele não tá reconhecendo" (2979); Eduardo "Fecha e abre ele que ele vai atualizar" (1826); João M. "system properties environment" (2783) |
| D4 | ⬜ sem evidência | Ninguém bateu no Gatekeeper de `.command` — o vetor é `curl \| bash`, não arquivo clicável. Guardar só se algum entregável virar clicável | macOS | 0 | baixa | — |
| D5 | ⬜ sem evidência | Erro nomeado de ExecutionPolicy não apareceu; o Windows quebrou por PATH/shell/SmartScreen. **Mesmo assim** o install.ps1 deve rodar com `-ExecutionPolicy Bypass` no processo (próxima pedra) | Windows | 0 | média (latente) | — |
| D6 | ✅ confirmada | **Colou no lugar errado** (chat do Claude/IDE em vez do terminal) e URL colada sem o "h" do `https` | ambos | 2 | média | Bernardo→Mateus "você tá em chat do cloud" (2378); João M. "faltou o H" (3068) |
| D7 | ✅ já corrigido | Placeholder `<SEU NOME>` — sem evidência de ter travado ninguém; manter como teste de regressão (não reintroduzir no template gerado) | ambos | 0 | baixa | (refuse-on-placeholder) |
| D8 | ⬜ sem evidência | Não há máquina corporativa sem admin (são pessoais). O que **parece** isso é o caso Touch-ID/senha (ver N6), que é bloqueio de acesso, não de privilégio | ambos | 0 | baixa | — |
| D9 | 🔁 reenquadrada | Não é "README longo" — é **ambiguidade Mac×Windows + múltiplas opções sem 'comece aqui'** (rodou PowerShell no Mac; viu "3ª opção de baixar o arquivo" e travou) | ambos | 2 | média | Eduardo "será que eu tava no lugar errado" (1757); Vitor "terceira opção do repositório… baixar o arquivo" (1960) |

### 3.2 Dores NOVAS (não estavam em D1–D9) — as mais graves estão aqui

| # | Dor | SO | Freq. | Grav. | Resolver em | Evidência (linha) |
|---|---|---|---|---|---|---|
| N1 | **Senha sudo sem eco** — o terminal não mostra o que se digita → todos acham que "bugou" | macOS | **4** | **crítica** | runtime | Eduardo "meu bugou nessa parte de colocar a senha" (1661), "Não consigo digitar" (1668); Mateus "eu também buguei nessa hora" (1687); Vitor "aqui não tá nem digitando nada" (2101) |
| N2 | **Windows nunca foi testado** — causa-raiz macro; um SO inteiro sem caminho funcional | Windows | 3 | **crítica** | runtime + gate | Bernardo "não cheguei a testar, testei no Mac ontem" (3410); João M. "cada terminal tem que ser uma linguagem" (2668); João A. "Windows… coisas de permissão" (4377) |
| N3 | **Pré-requisitos pipocando um a um** (uv/jq/rtk/git/node/python) quebram o fluxo | macOS | 3 | alta | runtime | Bernardo "deu uma coisa faltando… Pré-requisitos" (1799); Vitor "tá faltando JQ?" (2032); João A. "instalar git node python" (4354) |
| N4 | **Instalação parcial silenciosa** — acha que instalou mas não; itens faltando sem verificação | macOS | 3 | alta | runtime | Mateus "na minha cabeça eu já tinha instalado, mas pelo jeito não" (1483); Eduardo "não baixou o V" (2728); Vitor "só apareceu um que não foi instalado" (3553) |
| N5 | **git dispara Xcode CLT** (~10 min) no meio, sem aviso — parece travamento | macOS | 1 | alta | runtime | Bernardo (sobre a máquina do Mateus) "é isso que ele tá baixando, mas 10 minutos é meio bizarro" (1497) |
| N6 | **Touch-ID sem senha** — loga por digital e não sabe a senha que o sudo exige | macOS | 1 | crítica | runtime | Vitor "eu entro com a digital" (2072), "não lembro de cabeça, velho" (2133) |
| N7 | **Regra do harness bloqueia Vercel** — o passo agent-browser trava numa trava do próprio instalador | macOS | 1 | alta | runtime + escopo | Mateus "encontrou uma trava… regra que não é para usar plugins do Versel… travou" (3292) |
| N8 | **Sem sinal de "terminou"** — o agente sempre sugere um próximo passo; ninguém sabe quando parar | macOS | 3 | média | runtime + README | Mateus "ela sempre sugere um próximo passo e é isso que eu fico na dúvida" (3526); Eduardo "abriu aqui. Não abriu ou não?" (1428) |
| N9 | **Pasta no lugar errado** (Downloads/pasta de teste) em vez do home | ambos | 3 | média | runtime + README | João M. "salva dentro da pasta teste que eu criei em downloads" (4100); Eduardo "rodei git clone dentro da pasta do meu projeto" (1557); Vitor "qual pasta… dentro do usuário?" (4125) |
| N10 | **Progresso opaco** — nem o facilitador sabia o que a instalação estava fazendo | macOS | 1 | média | runtime | João A. "Eu não sei o que tá acontecendo… por que começou as instalações" (1490) |
| N11 | **Download bloqueado no Windows** (SmartScreen/antivírus) — precisou colar a URL no navegador | Windows | 1 | média | runtime + README | João A.→João M. "deve ter alguma proteção… copia essa URL no navegador" (3066) |
| N12 | **Modos de permissão confundem** (shift+tab/bypass, às vezes nem aparecem) | ambos | 3 | média | README | João A. "Clica de novo. Não tá aparecendo" (3801); João M. "Que que é bypass?" (3374) |
| N13 | **Confusão de conta no login** do claude | macOS | 1 | média-baixa | README | Mateus "eu sempre confundo" (2243) |
| N14 | **Internet caindo / MacBook travando** — ambiental, fora do instalador (mas reforça idempotência/resumível) | ambos | 4 | baixa | fora de escopo | Vitor "Caiu… travou tudo a internet" (1958); Eduardo "travou tudo… aos trancos e barrancos" (3499) |

> **Correções de atribuição (transparência):** a verificação adversarial pegou 5 citações com o **falante
> trocado** — D2 (era João A., não Mateus), D6 (era Bernardo, não Mateus), N3 (era Bernardo, não Eduardo),
> N5 (era Bernardo narrando a máquina do Mateus), N11 (era João A. guiando o João M.). O **texto verbatim
> e a linha estão certos**; só o "quem falou" foi corrigido. A substância de todas se manteve.

### 3.3 Ranking por gravidade × frequência (o que priorizar)

1. **N2** Windows nunca testado (crítica, causa-raiz macro) · 2. **N1** senha sudo sem eco (crítica, 4
pessoas) · 3. **D3** PATH pós-install (crítica, ambos SO) · 4. **D2** gerenciador ausente (alta, início do
fluxo) · 5. **D1** terminal escondido no VS Code (alta, antes do passo 1) · 6. **N3** pré-requisitos um a
um · 7. **N4** install parcial silencioso · 8. **N5** Xcode CLT · 9. **N6** Touch-ID/senha · 10. **N7**
harness bloqueia Vercel · depois D6, D9, N9, N8, N10, N11, N13, N12; ambientais/sem-evidência ao fim
(N14, D4, D5, D8, D7).

**Leitura-chave:** os piores blockers (N1, N2, D3, D2, N3, N4, N5) **aconteceram AO VIVO durante a
execução** — precisam de **mensagens inline no próprio bootstrap**, não no README. O README resolve o que
é contexto/orientação (D1, D9, N8, N9, N12, N13). Isso reordena as fases — ver §7.

## 4. Jornada-alvo (zero → produtivo)

O norte de UX. Cada passo tem que ser **impossível de errar**.

```
macOS                                   Windows
─────                                   ───────
1. Abrir o Terminal                     1. Abrir o PowerShell
   (README: onde fica + print)             (README: onde fica + print)
2. Colar 1 linha e Enter                2. Colar 1 linha e Enter
   └─ bootstrap.sh:                        └─ bootstrap.ps1:
      • instala Homebrew (se faltar)          • instala winget/scoop (se faltar)
      • brew install git node                 • instala git, node
      • instala Claude Code                   • instala Claude Code
      • git clone do harness                  • git clone do harness
      • roda install.sh                       • roda install.ps1
      • pergunta nome/função/foco             • pergunta nome/função/foco
3. Pronto: "abra o Claude e rode        3. idem
   /bsaios-core:ecc-guide"
```

Um paste = tudo. O bootstrap é **conversacional e fail-soft**: a cada dependência ausente, diz o que
vai fazer, faz, verifica, e se falhar dá a instrução manual — nunca aborta no meio deixando a máquina
num estado quebrado.

## 5. Componente 1 — Bootstrap de 1 comando

### 5.1 macOS — `install/bootstrap.sh`
Servido em `https://raw.githubusercontent.com/bbrak/black-sheep-aios/stable/install/bootstrap.sh`.
Comando único no README:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/bbrak/black-sheep-aios/stable/install/bootstrap.sh)"
```
Fluxo (cada etapa idempotente + fail-soft, reusando o padrão `ext_tool` do install.sh):
1. Detecta arquitetura (Apple Silicon `/opt/homebrew` vs Intel `/usr/local`) e ajusta o PATH do brew.
2. **Xcode Command Line Tools** (`xcode-select --install`) se faltar `git` — pré-requisito do brew.
3. **Homebrew** se faltar (`/bin/bash -c "$(curl ... install.sh)"` oficial) + `brew shellenv` no perfil.
4. `brew install git node` (só o que faltar).
5. **Claude Code** (`curl -fsSL https://claude.ai/install.sh | bash`), verifica `claude --version`.
6. `git clone` do repo (ou `git pull` se a pasta já existe) para `~/black-sheep-aios`.
7. Chama `install/install.sh` (que resolve rtk/graphify/agent-browser opcionais e escreve o harness).
8. Mensagem final: como abrir o Claude + próximo comando.

### 5.2 Windows — `install/bootstrap.ps1`
Comando único no README (o `-ExecutionPolicy Bypass` só vale para este processo):
```powershell
powershell -ExecutionPolicy Bypass -Command "iwr -useb https://raw.githubusercontent.com/bbrak/black-sheep-aios/stable/install/bootstrap.ps1 | iex"
```
Fluxo:
1. Garante **winget** (App Installer; se ausente, instrui a Microsoft Store) — fallback **scoop**.
2. `winget install` de git, node (`Git.Git`, `OpenJS.NodeJS.LTS`).
3. **Claude Code** (`irm https://claude.ai/install.ps1 | iex`), verifica.
4. `git clone`/`pull` para `~\black-sheep-aios`.
5. Chama `install\install.ps1`.
6. Mensagem final idem.

### 5.3 Invariantes do bootstrap (não-negociáveis)
- **Idempotente:** rodar 2x não duplica nada; tudo é "instala só se faltar".
- **Fail-soft por etapa:** falhou uma dependência → avisa, dá o comando manual, e **continua** o que dá.
- **Sem `sudo` escondido:** se precisar de admin (brew/winget), **pede explicitamente** e explica por quê.
- **PATH na mesma sessão:** após instalar, recarrega o PATH pro passo seguinte enxergar o binário (a
  dor D3). Ao final, avisa "reabra o terminal" para o efeito permanente.
- **Reaproveita, não duplica:** toda lógica de harness fica no `install.sh`/`.ps1`; o bootstrap só cuida
  do degrau das dependências de base. Zero cópia de lógica.

## 6. Componente 2 — README do zero

Reescrita com a regra: **um iniciante total chega ao fim sem perguntar nada a ninguém.**

- **Topo = 1 caminho feliz, 1 comando por SO** (o bootstrap), com o resto recolhido/adiado.
- **"Antes de começar"**: como abrir o Terminal (macOS) / PowerShell (Windows), com print. (dor D1)
- **Prints em cada passo** (capturas de tela reais — pendência de assets; ver §8).
- **"Deu erro?"**: um FAQ curto mapeando as dores confirmadas na §3 → solução (D4 Gatekeeper, D5
  ExecutionPolicy, D3 PATH, D8 máquina corporativa).
- **Caminho manual** (o passo-a-passo atual) vira **seção avançada recolhida**, para quem quer entender
  ou não confia em `curl | bash`.
- **Encolher o corpo:** as 334 linhas atuais migram o material de referência (estrutura do repo, hooks,
  MCPs, team-os) para depois do "você já está pronto", ou para `docs/`.

### 6.1 Segurança do `curl | bash` (endereçar de frente no README)
`curl | bash` assusta (e com razão). Mitigações no próprio README:
- Mostrar a **URL exata** (repo público, pinada na tag `stable`).
- Oferecer o **modo inspecionar-antes**: `curl -fsSL <url> -o bootstrap.sh` → abrir/ler → `bash bootstrap.sh`.
- (Opcional) publicar **checksum** do bootstrap por release.

## 7. Fases de implementação — REORDENADAS pela evidência (§3) · ✅ APROVADA pelo owner (2026-07-10)

> A ordem original (1=bootstrap macOS, 2=bootstrap Windows **em série**, 3=README, 4=prints) **reproduz a
> causa-raiz macro N2**: Windows como fase-seguinte/afterthought foi exatamente o que deixou o João Miguel
> travado do início ao fim. Por isso macOS e Windows deixam de ser fases em série e viram **uma única fase
> de bootstrap com paridade obrigatória**. E como os piores blockers aconteceram ao vivo (§3.3), a Fase 1
> embute as correções como **mensagens inline**, não como texto de README.

| Fase | Escopo | Entrega | Ataca (§3) |
|---|---|---|---|
| **1 — Bootstrap com paridade de SO** | `install/bootstrap.sh` **e** `bootstrap.ps1` na mesma fase; só fecha quando os DOIS passam em teste real. Mensagens inline: senha sudo sem eco (N1), Touch-ID/senha (N6), recarregar PATH (D3), pré-requisitos em batelada (N3/D2), Xcode CLT com aviso (N5), verificação final + done-signal (N4/N8), progresso visível (N10), guardas Windows (D5/N11). | 1 comando instala tudo nos dois SO — idempotente e fail-soft. | N1,N2,N3,N4,N5,N6,D2,D3 |
| **2 — README de fluxo único** | Auto-detecção de SO (nunca mostra o caminho do outro SO); "comece aqui" único; onde fica o terminal (print) e onde colar; onde salvar a pasta; FAQ de erros; segurança do `curl \| bash`. | README que um iniciante segue sozinho. | D1,D6,D9,N8,N9,N12,N13 |
| **3 — Prints + teste de usabilidade real** | Capturas dos pontos visuais (terminal no VS Code, login/conta, modos de permissão) + **cobaia: 1 colaborador que ainda não instalou** (gate de validação). | Onboarding validado por alguém de fora. | valida tudo |

**Gate de paridade (não-negociável):** teste numa **máquina Windows real** é condição de release —
"nunca testado" (N2) é gravidade crítica. macOS segue como implementação de referência (mais evidência +
caminho já testado), mas Windows alcança paridade **dentro da Fase 1**, antes de mover a tag `stable`.

### 7.1 Progresso (2026-07-10)

- **Fase 1 — Bootstrap.** `install/bootstrap.sh` (macOS) escrito e testado: `install/test/bootstrap-check.sh`
  roda **20/20 isolado** (dry-run idempotente; cadeia clone→install num `CLAUDE_HOME` isolado; caso
  no-flag/`ARGS` vazio; caso da tag `stable` movida; `~/.claude` e `~/.zprofile` intactos; sem poluição de
  CWD). `install/bootstrap.ps1` (Windows) em **paridade estrutural** (mesmos 5 passos, mesmo done-signal,
  mesmas flags, guarda de ExecutionPolicy, aviso de UAC) — **pendente o gate de máquina Windows real**
  (não há PowerShell neste ambiente para executá-lo). Uma **review adversarial** (workflow de 6 agentes)
  pegou e corrigiu 3 defeitos sérios: (a) *blocker* — `ARGS` vazio abortava no bash 3.2 do macOS no
  comando canônico sem flags (`${ARGS[@]+…}`); (b) update por tag — `git fetch --all --tags --force` +
  checkout, sem `git pull` (que falhava em detached HEAD e não pegava a `stable` movida); (c) `bootstrap.ps1`
  — try/catch do PowerShell não pega exit code do git → agora checa `$LASTEXITCODE`.
- **Fase 2 — README.** Reescrito: topo = 1 comando por SO + "como abrir o terminal" + done-signal claro;
  FAQ **"Deu erro?"** ancorado nas dores reais (N1 senha sem eco, D3 PATH, N5 Xcode CLT, D1 terminal
  escondido, N11 SmartScreen, D6 lugar errado); seção de **segurança do `curl|bash`** (modo
  inspecionar-antes + URL pinada). Referência longa recolhida em `<details>`. Prints marcados como
  pendentes (Fase 3).
- **Falta.** (1) **Fase 3** — prints reais (macOS + Windows zerados) + teste de usabilidade com **1
  colaborador que ainda não instalou**. (2) Ligar `bootstrap-check.sh` no CI (`harness-ci.yml`) e um smoke
  `bootstrap.ps1 -DryRun` no runner `windows-latest`. (3) **Publicar** (conta gh `bbrak` → push → mover a
  tag `stable`) para o comando do README ficar vivo via `raw.githubusercontent.com`.

## 8. Riscos & questões abertas (para o owner)

- **Assets de print:** quem produz as capturas de tela? (Precisa de 1 Mac + 1 Windows "zerados".)
- **`curl | bash` na cultura do time:** aceitável, ou o time prefere baixar-e-rodar? (define o destaque no README)
- **Máquinas corporativas (D8):** algum colaborador tem PC gerenciado sem admin? Isso limita brew/winget
  e talvez exija um caminho alternativo (ex.: node/claude portáteis).
- **Teste real:** dá pra recrutar **1 colaborador que ainda não instalou** para ser o cobaia da Fase 4?
  É o melhor sinal de que o onboarding funciona.
- **Instalador gráfico (futuro):** fica fora deste spec por custo (signing/notarização). Reavaliar só se o
  bootstrap não bastar.

### 8.1 Decisões da Fase 0 (moldam a Fase 1)

> **Resolvido com o owner em 2026-07-10:** reordenação §7 aprovada (paridade de SO, 3 fases);
> **agent-browser/Vercel adiado** para passo pós-onboarding (item 4); **teste em máquina Windows real é
> gate de release** (item 5). Defaults aceitos por omissão: **winget+scoop** (item 1), **Xcode CLT
> proativo com aviso** (item 2), mensagem inline de "senha = login do Mac" (item 3), **forçar**
> `~/black-sheep-aios` (item 6).

1. **Gerenciador de pacotes no Windows:** confirmar **winget** (primary) + **scoop** (fallback)? Ninguém
   documentou; o time só sabia que "precisava de um Homebrew do Windows" sem nome (N2).
2. **Xcode CLT (N5):** instalar proativamente (aceitando os ~10 min) **com barra/aviso claro**, ou detectar
   e perguntar? Trade-off: bloqueio longo previsível × surpresa no meio.
3. **Touch-ID/senha sudo (N6):** mensagem inline explicando que é a **senha de login do Mac** (não a
   digital) + como resetar, ou um caminho que evite `sudo`? (No Apple Silicon o brew exige `sudo` uma vez.)
4. **agent-browser/Vercel (N7):** **adiar** para um passo pós-onboarding (onboarding mais enxuto) ou
   **manter** no install inicial com **allowlist da Vercel Labs** no harness? Hoje ele bate numa regra do
   próprio harness e travou o Mateus.
5. **Gate de teste Windows (N2):** o owner compromete uma **máquina Windows real** de teste no cronograma?
   "Depois na PC da namorada" não é gate suficiente para uma falha de gravidade crítica.
6. **Realocação da pasta (N9):** o bootstrap **força** `~/black-sheep-aios` (move se estiver no lugar
   errado) ou aceita qualquer local e se auto-referencia? Local errado quebrou passos seguintes.

---

**Próximo passo:** owner cola/aponta os **docs de dores** → preencho a §3 com dados reais, reordeno as
fases, e marco o spec como **Aprovado** para a sessão de implementação (`/goal`).
