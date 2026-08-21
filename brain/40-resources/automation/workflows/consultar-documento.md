---
type: workflow
name: consultar-documento
status: placeholder
provider: n8n
risk: low
---

# Consultar documento ou pessoa

> **Placeholder.** Contrato declarado, endpoint ainda não provisionado. Enquanto
> `status: placeholder`, este workflow **não é invocável**: vale a regra
> `UNKNOWN WORKFLOW = NO ACTION`. Ao provisionar, mude para `status: active`,
> preencha a variável de endpoint na VPS e registre a entrada em `INDEX.md`.

## Description

Consulta por identificador: CPF, CNPJ ou inscrição na OAB. A automação decide as fontes.

## Endpoint

`{{PERSON_SEARCH_ENDPOINT}}` — endpoint completo, resolvido em runtime.

Nem o domínio nem o path do webhook são versionados: este repositório é público
e o nome interno do webhook também é tratado como sensível. O valor real vive
apenas em `/etc/professional-ai-assistant/assistant.env`, na VPS.

## Method

POST

## Required input

- document_type
- document (ou number + state, quando `document_type` for `oab`)

## Payload

```json
{
  "document_type": "cpf|cnpj|oab",
  "document": "{{value}}"
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

Para `oab`, o contrato aceita `number` e `state` no lugar de `document`.
Identificadores são dados operacionais: não persistir em memória permanente só
por terem sido consultados.
