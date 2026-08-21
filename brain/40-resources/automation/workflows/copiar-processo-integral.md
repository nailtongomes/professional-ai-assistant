---
type: workflow
name: copiar-processo-integral
status: placeholder
provider: n8n
risk: low
---

# Copiar processo integral

> **Placeholder.** Contrato declarado, endpoint ainda não provisionado. Enquanto
> `status: placeholder`, este workflow **não é invocável**: vale a regra
> `UNKNOWN WORKFLOW = NO ACTION`. Ao provisionar, mude para `status: active`,
> preencha a variável de endpoint na VPS e registre a entrada em `INDEX.md`.

## Description

Obtém a cópia integral de um processo judicial. Operação demorada: espera-se resposta assíncrona com `task_id`.

## Endpoint

`{{PROCESS_COPY_ENDPOINT}}` — endpoint completo, resolvido em runtime.

Nem o domínio nem o path do webhook são versionados: este repositório é público
e o nome interno do webhook também é tratado como sensível. O valor real vive
apenas em `/etc/professional-ai-assistant/assistant.env`, na VPS.

## Method

POST

## Required input

- numero_processo

## Payload

```json
{
  "numero_processo": "{{numero_processo}}"
}
```

## Success

HTTP 200 ou 202. **202 não é conclusão** — ver `Response`.

## Response

```json
{
  "task_id": "string",
  "status": "queued|running|completed|failed",
  "result": {}
}
```

## Notes

Quase sempre assíncrono. Reportar `queued`/`running` como estado, nunca como
conclusão.
