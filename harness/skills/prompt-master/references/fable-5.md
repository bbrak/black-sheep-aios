# Referência — Claude Fable 5 (e Mythos 5)

> Anatomia de 11 blocos + redação canônica oficial da Anthropic para o Fable 5.
> Fonte oficial: [Prompting Claude Fable 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5).

Este arquivo tem duas partes:

1. **A biblioteca de blocos** — cada um dos 11 blocos, com objetivo, template e a redação
   canônica oficial recomendada pela Anthropic para o Fable 5 (quando existe). Use a versão
   oficial quando quiser o efeito comprovado; use o template quando precisar adaptar.
2. **O template integrado** — o esqueleto completo, pronto para podar conforme a complexidade.

## Perfil do modelo (o que muda no Fable 5)

O Fable 5 é o modelo de fronteira da Anthropic: feito para problemas longos, ambíguos e
end-to-end que levariam horas, dias ou semanas para um humano. Pontos que afetam o prompt:

- **Effort é o controle primário.** `high` é o default; `xhigh` para o mais exigente;
  `medium`/`low` para rotina (ainda assim costumam superar `xhigh` de modelos anteriores).
- **Turnos longos por padrão.** Requests difíceis podem rodar muitos minutos; runs autônomos,
  horas. Isso reforça os blocos de Ação, Evidência e Pontos de Controle.
- **Forte instruction following.** Uma instrução breve substitui enumerar caso a caso.
- **Delegação confiável.** Dispara e sustenta subagentes paralelos melhor que modelos
  anteriores; prefira comunicação assíncrona.
- **Memória.** Vai especialmente bem quando pode gravar lições e consultá-las depois.
- **`reasoning_extraction` refusal.** NÃO instrua o modelo a ecoar/transcrever seu próprio
  raciocínio como texto de resposta — isso pode disparar recusa e fallback para o Opus 4.8.

Por que existe a versão oficial: a Anthropic publicou frases específicas, testadas em
produção, que produzem comportamentos confiáveis no Fable 5 (agir em vez de superplanejar,
não refatorar sem pedir, não fabricar status, parar só onde precisa). Prefira essas frases
quando o objetivo do bloco for um desses comportamentos.

---

## 1. Tarefa (Task)

**Objetivo:** dar o contexto geral, o público-alvo, o valor do resultado e o pedido
específico. O Fable 5 rende mais quando entende a *intenção*, não só a instrução.

**Template:**
```
Estou trabalhando em [OBJETIVO MAIOR] para [QUEM SE DESTINA].
Eles precisam de [O QUE O RESULTADO PERMITE REALIZAR].
Com isso em mente: [TAREFA].
```

---

## 2. Arquivos de Contexto (Context Files)

**Objetivo:** dizer quais documentos/fontes o modelo deve ler antes de responder. Inclua só
quando houver fontes reais.

**Template:**
```
Primeiro, leia estes arquivos completamente antes de responder:
[nome_do_arquivo.md] — [o que ele contém]
[nome_do_arquivo.md] — [o que ele contém]
```

---

## 3. Referência (Reference)

**Objetivo:** dar um exemplo concreto do resultado ideal — um padrão visual, estrutural ou de
estilo a seguir. Inclua quando o usuário tem um "exemplo do que quer".

**Template:**
```
Aqui está uma referência do que desejo alcançar:
[Faça o upload do arquivo de referência ou cole-o aqui]
```

---

## 4. Esforço (Effort)

**Objetivo:** calibrar quanto empenho/raciocínio o modelo aplica. No Fable 5, o "effort" é o
controle principal entre inteligência, latência e custo. `high` é o default; suba para `xhigh`
no mais exigente, desça para `medium`/`low` em rotina.

**Template:**
```
Este é um problema [rotineiro / difícil / o mais difícil ainda não resolvido].
Não se subestime — dimensione o esforço como se estivesse no topo da sua capacidade
de entrega.
```

---

## 5. Ação (Act)

**Objetivo:** mandar o modelo agir quando já tem informação suficiente, em vez de
superplanejar. Um dos comportamentos mais importantes de domar no Fable 5.

**Redação canônica oficial (preferir):**
```
Quando você tiver informação suficiente para agir, aja. Não re-derive fatos já
estabelecidos na conversa, não re-litigue uma decisão que o usuário já tomou, nem
narre em mensagens ao usuário opções que você não vai seguir. Se está pesando uma
escolha, dê uma recomendação, não um levantamento exaustivo. Isso não se aplica aos
blocos de raciocínio (thinking).
```

---

## 6. Escopo (Scope)

**Objetivo:** manter a solução enxuta — sem features extras, refatoração, abstração prematura
ou tratamento de erro para cenários impossíveis. Em effort alto, o Fable 5 tende a "arrumar a
casa" sem pedir; este bloco segura isso.

**Redação canônica oficial (para código, preferir):**
```
Não adicione features, não refatore nem introduza abstrações além do que a tarefa
exige. Um bugfix não precisa de faxina ao redor; uma operação pontual normalmente não
precisa de helper. Não projete para requisitos hipotéticos futuros: faça a coisa mais
simples que funciona bem. Evite abstração prematura e implementações pela metade. Não
adicione tratamento de erro, fallbacks ou validação para cenários que não podem
acontecer. Confie no código interno e nas garantias do framework. Valide só nas
fronteiras do sistema (entrada do usuário, APIs externas). Não use feature flags nem
gambiarras de retrocompatibilidade quando dá simplesmente para mudar o código.
```

**Variante de fronteira/diagnóstico (quando o usuário só descreve um problema):**
```
Quando o usuário está descrevendo um problema, fazendo uma pergunta ou pensando alto
em vez de pedir uma mudança, o entregável é a sua avaliação. Reporte o que encontrou e
pare. Não aplique uma correção até ele pedir. Antes de rodar um comando que muda o
estado do sistema (restart, delete, edição de config), cheque se a evidência sustenta
exatamente essa ação.
```

---

## 7. Delegação (Delegate)

**Objetivo:** em fluxos complexos, dividir subtarefas entre subagentes e manter verificação
contínua. O Fable 5 dispara subagentes paralelos com mais facilidade; prefira comunicação
assíncrona a bloquear esperando cada subagente.

**Redação canônica oficial:**
```
Delegue subtarefas independentes a subagentes e continue trabalhando enquanto elas
rodam. Intervenha se um subagente sair do trilho ou estiver sem contexto relevante.
```

**Auto-verificação em tarefas longas:**
```
Estabeleça um método para checar seu próprio trabalho a cada [intervalo] enquanto
constrói. Rode isso a cada [intervalo], verificando seu trabalho com subagentes de
contexto limpo contra a especificação.
```

---

## 8. Evidência (Evidence)

**Objetivo:** garantir que toda afirmação de progresso seja ancorada num resultado real de
ferramenta. No Fable 5, isto praticamente elimina relatórios de status fabricados.

**Redação canônica oficial:**
```
Antes de reportar progresso, audite cada afirmação contra um resultado de ferramenta
desta sessão. Só reporte trabalho para o qual você consegue apontar evidência; se algo
ainda não foi verificado, diga isso explicitamente. Reporte resultados com fidelidade:
se testes falharam, diga, com a saída; se um passo foi pulado, diga; quando algo está
feito e verificado, afirme isso sem rodeios.
```

---

## 9. Memória (Memory)

**Objetivo:** registrar aprendizados/correções ao longo do trabalho. O Fable 5 vai
especialmente bem quando pode gravar lições e consultá-las depois.

**Redação canônica oficial:**
```
Guarde uma lição por arquivo, com um resumo de uma linha no topo. Registre tanto
correções quanto abordagens confirmadas, incluindo por que importaram. Não salve o que
o repositório ou o histórico do chat já registram; atualize uma nota existente em vez
de criar duplicata; apague notas que se mostrarem erradas.
```

---

## 10. Pontos de Controle (Checkpoint)

**Objetivo:** definir onde o modelo DEVE parar e pedir intervenção humana. No Fable 5, basta
dizer o critério — não precisa enumerar todos os casos.

**Redação canônica oficial:**
```
Pause para o usuário apenas quando o trabalho realmente exigir: uma ação destrutiva ou
irreversível, uma mudança real de escopo, ou uma informação que só ele pode fornecer.
Se bater num desses casos, pergunte e encerre o turno, em vez de terminar numa
promessa.
```

**Para pipelines autônomos (usuário não está assistindo):**
```
Você está operando de forma autônoma. O usuário não está acompanhando em tempo real e
não pode responder no meio da tarefa, então perguntar "Quer que eu...?" trava o
trabalho. Para ações reversíveis que decorrem do pedido original, prossiga sem
perguntar. Antes de encerrar o turno, cheque seu último parágrafo: se for um plano,
uma análise, uma pergunta ou uma promessa ("Vou...", "me avise..."), faça esse
trabalho agora com chamadas de ferramenta. Encerre só quando a tarefa estiver completa
ou você estiver bloqueado por algo que só o usuário fornece.
```

---

## 11. Relatório (Report)

**Objetivo:** definir o formato de entrega — começar pelo resultado, com clareza acima de
concisão. No Fable 5, uma instrução curta de brevidade vale tanto quanto enumerar cada padrão.

**Redação canônica oficial:**
```
Comece pelo resultado. Sua primeira frase ao terminar deve responder "o que
aconteceu" ou "o que você descobriu" — aquilo que eu pediria se dissesse "só me dá o
TLDR". Detalhe de apoio e raciocínio vêm depois. Ser legível e ser conciso são coisas
diferentes, e legibilidade importa mais. O jeito de manter a saída curta é ser
seletivo no que incluir (corte detalhes que não mudam o que o leitor faria a seguir),
não comprimir o texto em fragmentos, abreviações, cadeias de setas (A → B → falha) ou
jargão.
```

---

# Template integrado (pronto para podar)

Use como esqueleto. **Apague os blocos que não se aplicam** ao tamanho da tarefa. Preencha
tudo com conteúdo real — nada de placeholders soltos.

```
# TAREFA
Estou trabalhando em [OBJETIVO MAIOR] para [QUEM SE DESTINA].
Eles precisam de [O QUE O RESULTADO PERMITE REALIZAR].
Com isso em mente: [TAREFA].

# ARQUIVOS DE CONTEXTO
Primeiro, leia estes arquivos completamente antes de responder:
[nome_do_arquivo.md] — [o que ele contém]

# REFERÊNCIA
Aqui está uma referência do que desejo alcançar:
[upload ou colar aqui]

# ESFORÇO
Este é um problema [rotineiro / difícil / o mais difícil ainda não resolvido].
Não se subestime — dimensione o esforço como se estivesse no topo da sua capacidade.

# AÇÃO
Quando tiver informação suficiente para agir, aja. Não re-derive o que já foi
estabelecido, não conteste decisões já tomadas nem narre opções que não vai seguir.
Avaliando uma escolha? Dê uma recomendação, não um levantamento exaustivo.

# ESCOPO
Faça a coisa mais simples que funcione bem. Sem features, refatorações ou abstrações
além do necessário. Sem tratamento de erro para cenários impossíveis. Se estou só
descrevendo um problema, o entregável é o seu diagnóstico.

# DELEGAÇÃO
Delegue subtarefas independentes a subagentes e continue trabalhando. Intervenha se um
subagente sair do trilho. Verifique o progresso contra a especificação a cada [intervalo].

# EVIDÊNCIA
Antes de reportar progresso, audite cada afirmação contra um resultado de ferramenta
desta sessão. Não verificado? Diga explicitamente. Testes falharam? Mostre a saída.

# MEMÓRIA
Guarde aprendizados em [notas.md] — um por arquivo, com resumo de uma linha. Atualize
notas existentes, não duplique. Apague o que se provar errado.

# PONTOS DE CONTROLE
Pause apenas para: ações destrutivas/irreversíveis, mudança real de escopo, ou
informação que só eu posso dar. Caso contrário, vá do início ao fim. Nunca termine só
com uma promessa de entrega.

# RELATÓRIO
Comece pelo resultado — o TLDR que eu pediria. Frases completas, sem cadeias de setas,
sem abreviações incomuns. Claro é melhor que apenas curto.
```
