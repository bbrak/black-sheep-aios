# Hooks do time

Três hooks leves e autônomos (Node puro, zero dependências). Todos são à prova de falha:
qualquer erro → `exit 0`, nunca travam a sessão. Ligados no `settings.json` global pelo
instalador do kit.

| Arquivo | Evento | O que faz |
|---|---|---|
| `session-context.js` | SessionStart (startup/clear/compact) | Injeta resumo do projeto: pasta, stack, branch, arquivos modificados, presença de CLAUDE.md |
| `skill-suggester.js` | UserPromptSubmit | Descobre as skills instaladas em tempo real e lembra a skill certa quando o assunto casa |
| `loop-detector.js` | UserPromptSubmit | Se a mesma mensagem se repete 3×, injeta protocolo de quebra de loop |
| `utils.js` | — | Biblioteca compartilhada (git info, detecção de stack, I/O) |

Nenhum deles usa IA ou consome tokens: são 100% Node local (leitura de arquivo + comparação de
string). O único texto que entra no contexto é o lembrete curto do skill-suggester, e só quando há
casamento forte.

## skill-suggester: como funciona e como calibrar

Não tem tabela fixa. A cada mensagem ele varre `~/.claude/skills`, o `.claude/skills` do projeto
e as skills de plugins (`~/.claude/plugins`), lê a `description` de cada `SKILL.md` e casa com o
texto da pessoa. Skill nova ou plugin novo → aparece sozinho no próximo prompt. Para não pesar,
guarda um índice em `.skill-index.json`, reconstruído só quando alguma pasta de skills muda (mtime)
ou a cada 24h (para pegar descrições editadas).

Casamento é por **palavra inteira** (aceita plural em "s") e ignora acentos — "slides" casa
"slide", mas "icon" não casa "ícone".

Travas contra excesso de sugestão (topo do arquivo):

- `SCORE_MINIMO = 2` — força mínima do casamento (palavra do nome da skill = 2 pontos; cada
  palavra da descrição = 1). Suba para 3–4 se quiser menos sugestões.
- `MAX_SUGESTOES = 2` — teto de sugestões por mensagem.
- `COOLDOWN_H = 6` — não repete a mesma skill sugerida dentro dessa janela.
- Lista `STOP` — ignora palavras genéricas (usar, criar, arquivo, the, for…) que casariam com tudo.

### Allowlist (importante se você tem MUITAS skills)

Com dezenas/centenas de skills instaladas, o casamento por palavra-chave gera falso-positivo
(ex.: "data" em português casa com uma skill de *data scraping*). A solução é curar:
copie `suggest-allowlist.example.txt` para `suggest-allowlist.txt` e liste as skills-carro-chefe
que você quer que sejam lembradas — uma por linha. Com o arquivo presente, só essas entram nas
sugestões. Para a cauda longa, confie no disparo nativo do Claude (que lê a descrição inteira
com o modelo e desambigua pelo contexto).

> Teste real com 333 skills: sem allowlist a precisão ficou em ~55%; com uma allowlist de ~10
> skills o ruído praticamente sumiu. Veja `_RELATORIO-TESTE-SKILL-SUGGESTER.md`.

### Testar em lote

`test-suggester-batch.js` roda a mesma pontuação contra uma lista de frases (uma por linha):

```
node test-suggester-batch.js <.skill-index.json> <frases.txt> [--min N]
```

> Quer melhor precisão de disparo? O que mais importa não é este hook, e sim a `description` de cada
> skill: escreva-a com as palavras que a pessoa realmente usa. O Claude já dispara skills sozinho a
> partir dela — este hook é só um reforço/ensino.

## Outros ajustes

- **Sensibilidade do loop:** troque `const N = 3` em `loop-detector.js`.
- **Desligar um hook:** remova a entrada correspondente em `~/.claude/settings.json`.

## Requisito

Precisam de Node no PATH (já é pré-requisito do Claude Code no Windows — seção B0 do guia).
