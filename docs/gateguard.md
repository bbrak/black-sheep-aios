# GateGuard

## O que é

GateGuard é um par de hooks (parte do plugin `bsaios-core`, herdado do ECC) que força o agente a
**verificar fatos antes de agir**: ele bloqueia o primeiro `Edit`/`Write` em cada arquivo e o
primeiro `Bash` de cada sessão até que o agente demonstre que leu/checou o contexto relevante.
É um "treino de disciplina" contra edições às cegas.

Os dois hooks:

| id interno | evento | o que bloqueia |
|---|---|---|
| `pre:bash:gateguard-fact-force` | PreToolUse(Bash), dentro do `pre:bash:dispatcher` | primeiro Bash da sessão / comandos destrutivos |
| `pre:edit-write:gateguard-fact-force` | PreToolUse(Edit\|Write) | primeira escrita em cada arquivo |

## Estado no time

**LIGADO por padrão** (decisão do owner do harness). Ele vem ativo porque o plugin `bsaios-core`
está habilitado no `settings.json` gerado pelo instalador — não há entrada separada de hook para
ligar/desligar no settings.

Quando o GateGuard bloquear, a mensagem do próprio hook diz o que fazer (em geral: ler o arquivo
ou verificar o estado antes de tentar de novo). Isso é o comportamento esperado, não um bug.

## Escape hatches (use com parcimônia)

1. **Desligar só nesta sessão** — rode o Claude Code com a variável de ambiente:

   ```bash
   # macOS (Git Bash/zsh)
   ECC_GATEGUARD=off claude
   ```

   ```powershell
   # Windows (PowerShell)
   $env:ECC_GATEGUARD="off"; claude
   ```

2. **Desligar só um dos gates, permanentemente** — adicione o id à env `ECC_DISABLED_HOOKS` no seu
   `~/.claude/settings.json` (a chave já existe; acrescente ao final, separado por vírgula):

   - `pre:edit-write:gateguard-fact-force` → mantém só o gate de Bash (tuning recomendado se o
     gate de escrita estiver atrapalhando demais)
   - `pre:bash:gateguard-fact-force` → mantém só o gate de Edit/Write

3. **Desligar tudo permanentemente** — adicione os DOIS ids acima à `ECC_DISABLED_HOOKS`.
   Prefira isso a desabilitar o plugin inteiro (o plugin também fornece as 49 skills e 21 agents).

> Regra do time: os escape hatches existem para sessões de setup/reparo que o GateGuard trava.
> Não desligue por padrão sem combinar — o valor dele é justamente o hábito.

## Hooks do ECC já desligados por padrão

O `settings.json` do time já vem com estes ids em `ECC_DISABLED_HOOKS` (ruído sem valor
observado em 30 dias de uso real, ou quebrados no Windows):

```
pre:write:doc-file-warning, pre:governance-capture, post:governance-capture,
post:edit:console-warn, stop:desktop-notify, stop:cost-tracker, stop:session-end,
stop:evaluate-session, pre:observe:continuous-learning, post:observe:continuous-learning
```

Motivos: `cost-tracker` produz números descalibrados; `session-end`/`evaluate-session`
(summarizer) geram dumps sem valor; os `observe:*` alimentam um observer que está `enabled:false`
por travar no Windows (bug #295) — coletar sem observer é só overhead. Não reative o observer no
Windows; no macOS, é decisão consciente sua (custo de tokens em background).
