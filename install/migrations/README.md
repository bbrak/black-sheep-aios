# Migrations do harness

Migrations **numeradas, ordenadas, idempotentes** e **cross-platform** (uma única implementação
Node — sem duplicar `.sh`/`.ps1`). Rodadas por [`install/lib/bsaios-update.js`](../lib/bsaios-update.js)
durante um update, **antes** do apply. Só rodam para versões **acima** do stamp instalado e **até** a
versão de destino (`installed < version <= latest`).

## Contrato

Arquivo `NNNN-slug.js` (ex.: `0001-move-agents.js`). Exporta:

```js
module.exports = {
  version: '1.1.0',                    // gate: roda se installed < version <= latest
  apply({ claudeHome, platform, repo, say, ok, warn }) {
    // Transformacao idempotente. Rodar 2x = mesmo resultado.
    // Nunca toca em segredos (settings.local.json, .credentials.json, *.pem, *.key).
    // Lance um Error para abortar o update (o updater restaura o backup e mantem a versao antiga).
  }
};
```

- **`version`** — a versão do produto em que a mudança entra. O gate compara com o `version.json`
  instalado e o `manifest.json` de destino.
- **`apply(ctx)`** — recebe `claudeHome` (destino), `platform` (`mac`/`windows`), `repo` (clone-fonte)
  e os loggers. Deve ser **idempotente** (o update é re-executável após uma falha).
- **MINOR/aditivo** aplica com o confirm leve do update; **MAJOR** força confirm + backup (o updater
  já faz backup de tudo o que possui antes de rodar migrations).

## Ordem

Os arquivos são lidos por ordem alfabética do nome (`0001`, `0002`, …). Use o prefixo numérico para
garantir a sequência; o sufixo `-slug` é só descrição.

_(Nenhuma migration necessária para a v1.0.0 — o diretório existe para o padrão estar pronto.)_
