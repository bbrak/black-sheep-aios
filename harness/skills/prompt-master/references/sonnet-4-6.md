# Referência — Claude Sonnet 4.6

> Anatomia de 11 blocos adaptada ao Sonnet 4.6 + redação canônica oficial da Anthropic.
> Fontes oficiais:
> [Introducing Sonnet 4.6](https://www.anthropic.com/news/claude-sonnet-4-6) ·
> [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-4-best-practices) ·
> [Effort](https://platform.claude.com/docs/en/build-with-claude/effort)

Mesma anatomia de 11 blocos do Fable 5, recalibrada para o Sonnet 4.6 — o **workhorse** do dia
a dia. Use a redação oficial quando o objetivo do bloco for um comportamento comprovado;
adapte o template quando precisar ajustar ao caso.

## Perfil do modelo (o que muda no Sonnet 4.6)

O Sonnet 4.6 é o Sonnet mais capaz da Anthropic: melhorias em coding, computer use, raciocínio
de longo contexto, planejamento de agentes, knowledge work e design. Em testes, usuários
preferiram o Sonnet 4.6 ao Sonnet 4.5 ~70% das vezes, e ao Opus 4.5 em 59%. É o modelo certo
para a maioria do trabalho diário; reserve o Opus para o que exige o raciocínio mais profundo
(refatoração de codebase, coordenar múltiplos agentes, "acertar em cheio" é crítico). O que
mais importa ao montar o prompt:

- **Effort: `medium` é o default recomendado.** Melhor equilíbrio de velocidade, custo e
  performance para a maioria das aplicações (coding agêntico, fluxos com muita ferramenta,
  geração de código). `low` para chat/alto volume/latência; `high` para raciocínio complexo;
  `max` para capacidade máxima. **Sempre defina o effort explicitamente** para evitar latência
  inesperada.
- **Forte em qualquer effort, até com thinking off.** Bom desempenho mesmo sem extended
  thinking — ótimo para respostas rápidas e interativas.
- **Melhor instruction following e follow-through** em tarefas multi-passo; **menos false
  claims of success** e menos alucinação que o Sonnet 4.5.
- **Computer use de nível humano** em tarefas como navegar planilha complexa ou preencher
  formulário web multi-etapa.
- **Adaptive thinking** (`thinking: {type: "adaptive"}`), com effort controlando a
  profundidade; thinking manual com `budget_tokens` ainda funciona mas está deprecated.
- **Dimensione enxuto.** Por ser o modelo de trabalho rotineiro, a maioria dos prompts usa
  poucos blocos. Reserve os blocos de autonomia longa (Delegação/Evidência/Memória/Checkpoint)
  para tarefas agênticas de verdade — em pedido simples eles só incham.

---

## 1. Tarefa (Task)

**Objetivo:** dar contexto geral, público-alvo, valor do resultado e o pedido específico. O
Sonnet 4.6 rende mais quando entende a *intenção*. Seja específico — ele segue instruções
literalmente, então vago gera resultado vago.

**Template:**
```
Estou trabalhando em [OBJETIVO MAIOR] para [QUEM SE DESTINA].
Eles precisam de [O QUE O RESULTADO PERMITE REALIZAR].
Com isso em mente: [TAREFA].
```

---

## 2. Arquivos de Contexto (Context Files)

**Objetivo:** dizer quais fontes ler antes de responder. Em prompt longo (20k+ tokens),
**coloque os documentos longos no topo**, acima do pedido. Sonnet 4.6 tem janela de 200k
tokens. Para múltiplos documentos, envolva em XML.

**Template:**
```
Primeiro, leia estes arquivos completamente antes de responder:
[nome_do_arquivo.md] — [o que ele contém]

(documentos longos colados ACIMA do pedido; cada um em <document>…</document>)
```

---

## 3. Referência (Reference)

**Objetivo:** dar um exemplo concreto do resultado ideal. Sonnet 4.6 casa o estilo de exemplos
muito de perto — "show, don't tell". Inclua quando o usuário tem um "exemplo do que quer".

**Template:**
```
Aqui está uma referência do que desejo alcançar:
[upload ou cole aqui — em <example>…</example>]
```

---

## 4. Esforço (Effort — orientação ao usuário do prompt)

**Objetivo:** lembrar qual nível de `effort` casa com a tarefa. No Sonnet 4.6 o effort controla
inteligência × velocidade × custo, e o default recomendado é `medium` (não `high`).

**Guia de nível (oficial):**
- `medium` — **default recomendado**: melhor equilíbrio para a maioria (coding agêntico,
  fluxos com ferramenta, geração de código).
- `low` — alto volume / latency-sensitive (chat e usos não-coding com prioridade em rapidez).
- `high` — raciocínio complexo, quando qualidade importa mais que velocidade/custo.
- `max` — capacidade máxima, sem restrição de tokens.

> O Sonnet 4.6 vai bem mesmo com thinking off; só ligue/aumente effort quando a tarefa pedir.

---

## 5. Ação (Act)

**Objetivo:** fazer o modelo agir quando já há informação suficiente, em vez de só sugerir.
Sonnet 4.6 segue instruções literalmente: "make these changes" → mudança; "suggest…" → só
sugestão. Peça ação explicitamente.

**Redação canônica oficial (preferir):**
```
Quando você tiver informação suficiente para agir, aja. Não re-derive fatos já
estabelecidos na conversa, não re-litigue uma decisão que o usuário já tomou, nem
narre opções que você não vai seguir. Se está pesando uma escolha, dê uma recomendação,
não um levantamento exaustivo.
```

**Ação proativa por padrão (para fluxos agênticos):**
```
<default_to_action>
Por padrão, implemente as mudanças em vez de apenas sugeri-las. Se a intenção estiver
ambígua, infira a ação mais útil provável e prossiga, usando ferramentas para descobrir
detalhes faltantes em vez de adivinhar.
</default_to_action>
```

---

## 6. Escopo (Scope)

**Objetivo:** manter a solução enxuta — sem features extras, refatoração, abstração prematura
ou tratamento de erro para cenários impossíveis.

**Redação canônica oficial (para código):**
```
Não adicione features, não refatore nem introduza abstrações além do que a tarefa exige.
Um bugfix não precisa de faxina ao redor; uma operação pontual normalmente não precisa de
helper. Não projete para requisitos hipotéticos futuros: faça a coisa mais simples que
funciona bem. Não adicione tratamento de erro, fallbacks ou validação para cenários que não
podem acontecer. Confie no código interno e nas garantias do framework. Valide só nas
fronteiras (entrada do usuário, APIs externas).
```

**Variante de fronteira/diagnóstico (usuário só descreve um problema):**
```
Quando o usuário está descrevendo um problema, fazendo uma pergunta ou pensando alto em vez
de pedir uma mudança, o entregável é a sua avaliação. Reporte o que encontrou e pare. Não
aplique uma correção até ele pedir.
```

---

## 7. Delegação (Delegate)

**Objetivo:** em fluxos complexos, dividir subtarefas entre subagentes. Inclua **só** em
trabalho agêntico real com paralelismo; para o pedido rotineiro típico do Sonnet, omita.

**Redação canônica oficial:**
```
Delegue subtarefas independentes a subagentes e continue trabalhando enquanto elas rodam.
Intervenha se um subagente sair do trilho ou estiver sem contexto relevante.
```

---

## 8. Evidência (Evidence)

**Objetivo:** ancorar afirmações de progresso em resultados reais de ferramenta. O Sonnet 4.6
já faz menos false claims of success; em runs agênticas longas o bloco reforça.

**Redação canônica oficial:**
```
Antes de reportar progresso, audite cada afirmação contra um resultado de ferramenta desta
sessão. Só reporte trabalho para o qual você consegue apontar evidência; se algo ainda não
foi verificado, diga isso explicitamente. Reporte resultados com fidelidade: se testes
falharam, diga, com a saída; se um passo foi pulado, diga; quando algo está feito e
verificado, afirme isso sem rodeios.
```

---

## 9. Memória (Memory)

**Objetivo:** registrar aprendizados ao longo de tarefas longas/multi-sessão. Para o pedido
diário curto, normalmente desnecessário.

**Redação canônica oficial:**
```
Guarde uma lição por arquivo, com um resumo de uma linha no topo. Registre tanto correções
quanto abordagens confirmadas, incluindo por que importaram. Não salve o que o repositório
ou o histórico do chat já registram; atualize uma nota existente em vez de criar duplicata;
apague notas que se mostrarem erradas.
```

---

## 10. Pontos de Controle (Checkpoint)

**Objetivo:** definir onde parar para o humano. Só relevante em tarefas autônomas; omita no
pedido simples.

**Redação canônica oficial:**
```
Pause para o usuário apenas quando o trabalho realmente exigir: uma ação destrutiva ou
irreversível, uma mudança real de escopo, ou uma informação que só ele pode fornecer. Se
bater num desses casos, pergunte e encerre o turno, em vez de terminar numa promessa.
```

---

## 11. Relatório (Report)

**Objetivo:** definir o formato de entrega — começar pelo resultado, clareza acima de
concisão. Diga o que fazer (prosa fluida / formato X) em vez do que não fazer.

**Redação canônica oficial:**
```
Comece pelo resultado — o TLDR que eu pediria. Frases completas, sem cadeias de setas (A → B
→ falha), sem abreviações incomuns. Ser legível e ser conciso são coisas diferentes, e
legibilidade importa mais. Para encurtar, seja seletivo no que incluir, não comprima em
fragmentos.
```

---

# Template integrado (pronto para podar)

Por ser o modelo de trabalho rotineiro, **a maioria dos prompts de Sonnet usa só 1, 4, 5, 6 e
11**. Adicione 2/3 quando houver fontes/exemplo, e os blocos de autonomia (7–10) só em tarefa
agêntica longa de verdade. Preencha com conteúdo real.

```
# TAREFA
Estou trabalhando em [OBJETIVO MAIOR] para [QUEM SE DESTINA].
Eles precisam de [O QUE O RESULTADO PERMITE REALIZAR].
Com isso em mente: [TAREFA].

# ARQUIVOS DE CONTEXTO
Leia estes arquivos completamente antes de responder (longos no topo, em <document>…</document>):
[nome_do_arquivo.md] — [o que ele contém]

# REFERÊNCIA
Aqui está uma referência do que desejo alcançar (em <example>…</example>):
[upload ou colar aqui]

# ESFORÇO (orientação)
Trate como tarefa de nível [rotineiro → effort medium / complexo → high]. Seja específico:
instrução vaga gera resultado vago.

# AÇÃO
Quando tiver informação suficiente para agir, aja. Não re-derive o que já foi estabelecido nem
narre opções que não vai seguir. Avaliando uma escolha? Dê uma recomendação. (Se quiser
implementação, peça explicitamente: "faça estas mudanças".)

# ESCOPO
Faça a coisa mais simples que funcione bem. Sem features, refatorações ou abstrações além do
necessário. Sem tratamento de erro para cenários impossíveis. Se estou só descrevendo um
problema, o entregável é o seu diagnóstico.

# DELEGAÇÃO   (só em tarefa agêntica longa)
Delegue subtarefas independentes a subagentes e continue trabalhando. Intervenha se um
subagente sair do trilho.

# EVIDÊNCIA   (só em run agêntica longa)
Antes de reportar progresso, audite cada afirmação contra um resultado de ferramenta desta
sessão. Não verificado? Diga explicitamente. Testes falharam? Mostre a saída.

# PONTOS DE CONTROLE   (só em tarefa autônoma)
Pause apenas para: ações destrutivas/irreversíveis, mudança real de escopo, ou informação que
só eu posso dar. Caso contrário, vá do início ao fim. Nunca termine só com uma promessa.

# RELATÓRIO
Comece pelo resultado — o TLDR. Frases completas, sem cadeias de setas, sem abreviações.
Claro é melhor que apenas curto.
```
