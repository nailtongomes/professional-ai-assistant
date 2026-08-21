---
type: workflow
name: enviar-email
status: placeholder
provider: n8n
risk: medium
---

# Enviar e-mail

> **Placeholder.** Contrato declarado, endpoint ainda não provisionado. Enquanto
> `status: placeholder`, este workflow **não é invocável**: vale a regra
> `UNKNOWN WORKFLOW = NO ACTION`. Ao provisionar, mude para `status: active`,
> preencha a variável de endpoint na VPS e registre a entrada em `INDEX.md`.

## Description

Envia e-mail por automação externa. O agente não fala SMTP, não acessa provedor de e-mail e não conhece credencial.

## Endpoint

`{{SEND_EMAIL_ENDPOINT}}` — endpoint completo, resolvido em runtime.

Nem o domínio nem o path do webhook são versionados: este repositório é público
e o nome interno do webhook também é tratado como sensível. O valor real vive
apenas em `/etc/professional-ai-assistant/assistant.env`, na VPS.

## Method

POST

## Required input

- to
- subject
- body

## Payload

```json
{
  "to": ["{{recipient}}"],
  "subject": "{{subject}}",
  "body": "{{body}}"
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

Campos opcionais: `cc`, `bcc`, `attachments`. Efeito externo irreversível:
`risk: medium` exige confirmação quando destinatário, assunto ou conteúdo não
estiverem inequívocos.
