---
type: workflow
name: consultar-processo
status: placeholder
provider: n8n
risk: low
---

# Consultar processo

> **Placeholder.** Contrato declarado, endpoint ainda não provisionado. Enquanto
> `status: placeholder`, este workflow **não é invocável**: vale a regra
> `UNKNOWN WORKFLOW = NO ACTION`. Ao provisionar, mude para `status: active`,
> preencha a variável de endpoint na VPS e registre a entrada em `INDEX.md`.

## Description

Consulta dados e movimentações de um processo judicial. A automação decide o sistema de origem; o agente não conhece tribunal nem endereço de sistema processual.

## Endpoint

`{{PROCESS_QUERY_ENDPOINT}}` — endpoint completo, resolvido em runtime.

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
  "numero_processo": "{{numero_processo}}",
  "tipo_consulta": "{{tipo_consulta}}"
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

`tipo_consulta` é opcional; omitir quando o usuário não especificar. Não
enviar `tribunal` nem `sistema` por dedução — a automação autodetecta.
