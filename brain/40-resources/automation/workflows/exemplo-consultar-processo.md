---
type: workflow
name: exemplo-consultar-processo
status: example
provider: n8n
risk: low
---

# Exemplo — Consultar processo

> **Este arquivo é um exemplo de formato, não um workflow ativo.**
> Não invoque. O endpoint abaixo não aponta para nenhum serviço real, e a entrada
> correspondente não existe em `INDEX.md`. Use-o como molde ao registrar um
> workflow de verdade.

## Description

Consulta informações de um processo judicial.

## Endpoint

{{N8N_URL}}/webhook/consultar-processo

## Method

POST

## Required input

- numero_processo

## Optional input

- tribunal

## Payload

```json
{
  "numero_processo": "{{numero_processo}}",
  "tribunal": "{{tribunal}}"
}
```

## Success

HTTP 200 ou 202.

## Response

```json
{
  "task_id": "string",
  "status": "queued|running|completed|failed",
  "result": {}
}
```

## Notes

Não consultar diretamente outro sistema se este workflow estiver indisponível.
