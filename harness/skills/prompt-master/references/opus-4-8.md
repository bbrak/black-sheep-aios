# Referência — Claude Opus 4.8

> Anatomia de 11 blocos adaptada ao Opus 4.8 + redação canônica oficial da Anthropic.
> Fontes oficiais:
> [Prompting Claude Opus 4.8](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-4-8) ·
> [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-4-best-practices) ·
> [Effort](https://platform.claude.com/docs/en/build-with-claude/effort)

Mesma anatomia de 11 blocos do Fable 5, recalibrada para o comportamento real do Opus 4.8.
Use a redação oficial quando o objetivo do bloco for um comportamento comprovado; adapte o
template quando precisar ajustar ao caso.

## Perfil do modelo (o que muda no Opus 4.8 vs Fable 5)

O Opus 4.8 é forte em trabalho agêntico de longo horizonte, knowledge work, visão e memória.
Roda bem out-of-the-box em prompts do Opus 4.7. O que mais muda na hora de montar o prompt:

- **Instruction following MAIS literal.** Interpreta o prompt ao pé da letra, sobretudo em
  effort baixo. *Não* generaliza uma instrução de um item para outro e *não* infere pedidos
  que você não fez. → **Declare o escopo explicitamente** ("aplique a TODAS as seções, não só
  à primeira"). Este é o ajuste nº 1 ao migrar do Fable 5, que generaliza mais sozinho.
- **Verbosidade calibrada pela complexidade.** Respostas curtas em lookups simples, longas em
  análise aberta. Se o produto depende de um estilo fixo, peça-o no prompt — e prefira
  **exemplos positivos** de concisão a instruções do tipo "não faça X".
- **Favorece reasoning sobre tool calls.** Costuma render melhor, mas se você quer mais uso de
  ferramenta, **suba o effort** (`high`/`xhigh`) ou descreva explicitamente quando/como usar.
- **Spawna MENOS subagentes por padrão.** É esteerável: dê guia explícita de quando delegar.
- **Updates de progresso melhores e mais regulares** em traces longas — remova andaimes do
  tipo "resuma a cada 3 tool calls".
- **Effort é mais importante que em qualquer Opus anterior.** Respeita os níveis estritamente,
  sobretudo no low. `xhigh` para coding/agentic; `high` mínimo para tarefas intelligence-
  sensitive; `medium`/`low` só quando os evals mostram que segura a qualidade.
- **Tom mais direto e opinativo**, com pouco emoji e pouca validação-forward. Se o produto
  pede voz calorosa, peça no prompt.

---

## 1. Tarefa (Task)

**Objetivo:** dar contexto geral, público-alvo, valor do resultado e o pedido específico. O
Opus 4.8 conecta melhor a tarefa à informação certa quando entende a *intenção*.

**Template:**
```
Estou trabalhando em [OBJETIVO MAIOR] para [QUEM SE DESTINA].
Eles precisam de [O QUE O RESULTADO PERMITE REALIZAR].
Com isso em mente: [TAREFA].
```

> Dica oficial: "If you want 'above and beyond' behavior, explicitly request it." Em vez de
> "crie um dashboard", use "crie um dashboard; inclua o máximo de features e interações
> relevantes possível; vá além do básico para uma implementação completa."

---

## 2. Arquivos de Contexto (Context Files)

**Objetivo:** dizer quais fontes ler antes de responder. Em prompt longo (20k+ tokens),
**coloque os documentos longos no topo**, acima do pedido (melhora a resposta em até ~30%).
Para múltiplos documentos, envolva em XML (`<document><source>...</source>...</document>`).

**Template:**
```
Primeiro, leia estes arquivos completamente antes de responder:
[nome_do_arquivo.md] — [o que ele contém]

(documentos longos colados ACIMA do pedido; cada um em <document>…</document>)
```

> Para tarefas sobre documentos longos, peça para o modelo **citar trechos relevantes antes**
> de executar ("coloque as citações em <quotes>, depois responda") — corta o ruído.

---

## 3. Referência (Reference)

**Objetivo:** dar um exemplo concreto do resultado ideal. O Opus 4.8 presta atenção *muito
fina* aos exemplos — garanta que eles reflitam só o que você quer reforçar.

**Template:**
```
Aqui está uma referência do que desejo alcançar:
[upload ou cole aqui — em <example>…</example>]
```

---

## 4. Esforço (Effort — orientação ao usuário do prompt)

**Objetivo:** lembrar qual nível de `effort` casa com a tarefa. No Opus 4.8 o effort é o
controle primário de inteligência × custo × latência, e ele o respeita estritamente.

**Guia de nível (oficial):**
- `xhigh` — melhor para a maioria de coding/agentic.
- `high` (default) — mínimo para tarefas intelligence-sensitive.
- `medium` — cost-sensitive, troca alguma inteligência por economia.
- `low` — só tarefas curtas/escopadas e latency-sensitive.
- `max` — só problemas de fronteira; pode dar overthinking.

**Texto para colar no prompt (quando precisar manter effort baixo mas a tarefa exige rigor):**
```
Esta tarefa envolve raciocínio de múltiplos passos. Pense com cuidado no problema antes
de responder.
```

> Nota: no Opus 4.8 o thinking é off a menos que `thinking: {type: "adaptive"}` esteja
> setado. Em `xhigh`/`max`, dê um `max_tokens` grande (comece em 64k).

---

## 5. Ação (Act)

**Objetivo:** fazer o modelo agir/implementar quando já há informação suficiente, em vez de só
sugerir. Como o Opus 4.8 segue instruções literalmente, **seja explícito**: "make these
changes" rende mudança; "can you suggest…" rende só sugestão.

**Redação canônica oficial (ação proativa):**
```
<default_to_action>
Por padrão, implemente as mudanças em vez de apenas sugeri-las. Se a intenção do usuário
não estiver clara, infira a ação mais útil provável e prossiga, usando ferramentas para
descobrir detalhes faltantes em vez de adivinhar. Tente inferir se uma chamada de
ferramenta (editar/ler arquivo) é pretendida e aja de acordo.
</default_to_action>
```

**Variante conservadora (quando quiser que ele só aja sob pedido explícito):**
```
<nao_aja_antes_da_instrucao>
Não pule para implementação nem altere arquivos sem instrução clara de fazer mudanças.
Quando a intenção estiver ambígua, prefira informar, pesquisar e recomendar em vez de
agir. Só edite/implemente quando o usuário pedir explicitamente.
</nao_aja_antes_da_instrucao>
```

---

## 6. Escopo (Scope)

**Objetivo:** segurar o overengineering. Opus 4.5/4.6 tendem a criar arquivos extras,
abstrações e flexibilidade não pedida — o Opus 4.8 obedece bem a um limite explícito.

**Redação canônica oficial (anti-overengineering):**
```
Evite overengineering. Faça só o que foi pedido ou é claramente necessário. Mantenha a
solução simples e focada:
- Escopo: não adicione features, não refatore nem faça "melhorias" além do pedido. Um
  bugfix não precisa de faxina ao redor; uma feature simples não precisa de
  configurabilidade extra.
- Documentação: não adicione docstrings, comentários ou type annotations a código que você
  não mudou. Só comente onde a lógica não é autoexplicativa.
- Código defensivo: não adicione tratamento de erro, fallbacks ou validação para cenários
  impossíveis. Confie no código interno e nas garantias do framework. Valide só nas
  fronteiras (entrada do usuário, APIs externas).
- Abstrações: não crie helpers/utilitários para operações pontuais. Não projete para
  requisitos hipotéticos. A complexidade certa é o mínimo necessário para a tarefa atual.
```

**Variante de fronteira/diagnóstico (usuário só descreve um problema):**
```
Quando o usuário está descrevendo um problema, fazendo uma pergunta ou pensando alto em vez
de pedir uma mudança, o entregável é a sua avaliação. Reporte o que encontrou e pare. Não
aplique uma correção até ele pedir.
```

---

## 7. Delegação (Delegate)

**Objetivo:** controlar subagentes. O Opus 4.8 **spawna poucos por padrão** — o ajuste aqui é
o oposto do Fable 5: você normalmente precisa *incentivar* a delegação, com critério.

**Redação canônica oficial:**
```
Não dispare um subagente para trabalho que você consegue completar direto numa única
resposta (ex.: refatorar uma função que você já está vendo).
Dispare múltiplos subagentes no mesmo turno ao fazer fan-out por itens ou ao ler vários
arquivos.
```

> Se a tarefa não envolve paralelismo real nem contextos isolados, deixe este bloco de fora —
> o Opus 4.8 já tende a trabalhar direto.

---

## 8. Evidência (Evidence)

**Objetivo:** ancorar afirmações de progresso em resultados reais de ferramenta. O Opus 4.8 já
é mais honesto (≈4× menos propenso a deixar passar falhas no próprio código), mas em runs
longas o bloco ainda ajuda.

**Redação canônica oficial:**
```
Antes de reportar progresso, audite cada afirmação contra um resultado de ferramenta desta
sessão. Só reporte trabalho para o qual você consegue apontar evidência; se algo ainda não
foi verificado, diga isso explicitamente. Reporte resultados com fidelidade: se testes
falharam, diga, com a saída; se um passo foi pulado, diga; quando algo está feito e
verificado, afirme isso sem rodeios.
```

**Para code review (recuperar recall — o Opus 4.8 filtra demais se você pedir "conservador"):**
```
Reporte cada problema que encontrar, incluindo os que você considera de baixa severidade ou
sobre os quais tem incerteza. Não filtre por importância nem confiança nesta etapa — uma
etapa de verificação separada fará isso. Seu objetivo aqui é cobertura. Para cada achado,
inclua nível de confiança e severidade estimada.
```

---

## 9. Memória (Memory)

**Objetivo:** registrar aprendizados ao longo do trabalho para não repetir erros.

**Redação canônica oficial:**
```
Guarde uma lição por arquivo, com um resumo de uma linha no topo. Registre tanto correções
quanto abordagens confirmadas, incluindo por que importaram. Não salve o que o repositório
ou o histórico do chat já registram; atualize uma nota existente em vez de criar duplicata;
apague notas que se mostrarem erradas.
```

---

## 10. Pontos de Controle (Checkpoint)

**Objetivo:** dizer onde parar para o humano e garantir autonomia no resto. Sem guia, o Opus
4.8 pode tomar ações difíceis de reverter; basta declarar o critério.

**Redação canônica oficial (autonomia × segurança):**
```
Considere a reversibilidade e o impacto das suas ações. Você pode tomar ações locais e
reversíveis (editar arquivos, rodar testes), mas para ações difíceis de reverter, que
afetam sistemas compartilhados ou são destrutivas, pergunte ao usuário antes.
Exemplos que pedem confirmação:
- Destrutivas: apagar arquivos/branches, dropar tabelas, rm -rf.
- Difíceis de reverter: git push --force, git reset --hard, alterar commits publicados.
- Visíveis a terceiros: push de código, comentar em PRs/issues, enviar mensagens.
Ao encontrar obstáculos, não use ações destrutivas como atalho (ex.: --no-verify).
```

**Para pipelines autônomos (usuário não está assistindo):**
```
Você está operando de forma autônoma. O usuário não está acompanhando e não pode responder
no meio da tarefa, então perguntar "Quer que eu...?" trava o trabalho. Para ações
reversíveis que decorrem do pedido original, prossiga sem perguntar. Antes de encerrar o
turno, cheque seu último parágrafo: se for um plano, uma análise, uma pergunta ou uma
promessa ("Vou..."), faça esse trabalho agora com chamadas de ferramenta. Encerre só quando
a tarefa estiver completa ou bloqueada por algo que só o usuário fornece.
```

---

## 11. Relatório (Report)

**Objetivo:** definir o formato de entrega — começar pelo resultado, clareza acima de
concisão. Para controlar a verbosidade do Opus 4.8, **diga o que fazer** (prosa fluida) em vez
do que não fazer, e prefira exemplos positivos.

**Redação canônica oficial:**
```
Comece pelo resultado. Sua primeira frase ao terminar deve responder "o que aconteceu" ou
"o que você descobriu" — o TLDR. Detalhe de apoio e raciocínio vêm depois. Ser legível e ser
conciso são coisas diferentes, e legibilidade importa mais. Para encurtar, seja seletivo no
que incluir (corte o que não muda o que o leitor faria a seguir), não comprima em fragmentos,
abreviações, cadeias de setas (A → B → falha) ou jargão.
```

**Para reduzir verbosidade (quando o produto exige respostas enxutas):**
```
Dê respostas concisas e focadas. Corte contexto não essencial e mantenha exemplos mínimos.
```

**Para frontend/design (quebrar o house style cream/serif default):**
```
Antes de construir, proponha 4 direções visuais distintas para este brief (cada uma:
cor de fundo hex / cor de destaque hex / tipografia — uma linha de justificativa). Peça ao
usuário para escolher uma e implemente só essa.
```

---

# Template integrado (pronto para podar)

Apague os blocos que não se aplicam. Preencha com conteúdo real. Para o Opus 4.8, **declare
escopo explicitamente** (ele não generaliza sozinho) e **calibre verbosidade** no Relatório.

```
# TAREFA
Estou trabalhando em [OBJETIVO MAIOR] para [QUEM SE DESTINA].
Eles precisam de [O QUE O RESULTADO PERMITE REALIZAR].
Com isso em mente: [TAREFA].
(Se quiser "above and beyond", peça explicitamente.)

# ARQUIVOS DE CONTEXTO
Leia estes arquivos completamente antes de responder (documentos longos colados acima do
pedido, cada um em <document>…</document>):
[nome_do_arquivo.md] — [o que ele contém]

# REFERÊNCIA
Aqui está uma referência do que desejo alcançar (em <example>…</example>):
[upload ou colar aqui]

# ESCOPO/ESFORÇO (orientação)
Trate como tarefa de nível [rotineiro / difícil]. Aplique a instrução a TODAS as seções/itens,
não só à primeira. [Se manter effort baixo: "Esta tarefa envolve raciocínio de múltiplos
passos; pense com cuidado antes de responder."]

# AÇÃO
Por padrão, implemente em vez de só sugerir. Se a intenção estiver ambígua, infira a ação mais
útil e prossiga, usando ferramentas para descobrir o que falta em vez de adivinhar.

# ESCOPO
Evite overengineering. Só o que foi pedido ou é claramente necessário. Sem features,
refatorações, docstrings ou abstrações além do necessário. Sem tratamento de erro para
cenários impossíveis. Valide só nas fronteiras.

# DELEGAÇÃO
Não dispare subagente para o que dá para fazer direto numa resposta. Dispare múltiplos no
mesmo turno ao fazer fan-out por itens ou ler vários arquivos.

# EVIDÊNCIA
Antes de reportar progresso, audite cada afirmação contra um resultado de ferramenta desta
sessão. Não verificado? Diga explicitamente. Testes falharam? Mostre a saída.

# MEMÓRIA
Guarde aprendizados em [notas.md] — um por arquivo, resumo de uma linha. Atualize, não
duplique. Apague o que se provar errado.

# PONTOS DE CONTROLE
Aja em ações locais e reversíveis. Para ações destrutivas, difíceis de reverter ou visíveis a
terceiros, pergunte antes. Nunca termine só com uma promessa de entrega.

# RELATÓRIO
Comece pelo resultado — o TLDR. Frases completas, sem cadeias de setas, sem abreviações.
Claro é melhor que apenas curto. [Se precisar enxuto: "Respostas concisas e focadas; corte
contexto não essencial."]
```
