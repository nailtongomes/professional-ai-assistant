---
type: workflow-index
status: active
created: 2026-08-21
updated: 2026-08-21
---

# Workflows Index

Catálogo dos workflows externos que o assistente pode invocar. É a fonte da
verdade sobre **quais automações existem**; o procedimento de invocação está em
`../../../70-skills/automation/invoke-workflow/SKILL.md`.

```text
UNKNOWN WORKFLOW = NO ACTION
```

Workflow não registrado aqui não é executado — mesmo que o usuário forneça uma
URL, e mesmo que exista um workflow parecido.

Consulte este índice primeiro. Só abra o arquivo do workflow escolhido; não varra
o diretório quando o índice bastar.

## Formato de cada entrada

```markdown
## <name>

Description:
<uma linha>

Path:
<arquivo>.md

Provider:
n8n | kestra | api-interna | outro

Risk:
low | medium | high
```

## Endpoints

Cada workflow declara uma **variável de endpoint completo**, resolvida em runtime
a partir de `/etc/professional-ai-assistant/assistant.env`, na VPS.

```text
Skill  →  {{PROCESS_QUERY_ENDPOINT}}  →  runtime resolve  →  URL real
```

Nem o domínio nem o path do webhook são versionados: este repositório é público,
e o nome interno de um webhook também é informação de infraestrutura. O runtime
não concatena base + path — a variável já carrega a URL inteira, o que permite
mover um workflow de host sem tocar em arquivo versionado.

## Workflows registrados

_Nenhum workflow ativo._

Os arquivos abaixo declaram contratos com `status: placeholder`: o formato está
definido, o endpoint ainda não foi provisionado. Enquanto estiverem assim, a
regra `UNKNOWN WORKFLOW = NO ACTION` os mantém fora de execução.

| Arquivo | Endpoint | Risco | Usado por |
| ------- | -------- | ----- | --------- |
| `consultar-processo.md` | `{{PROCESS_QUERY_ENDPOINT}}` | low | `process-query` |
| `copiar-processo-integral.md` | `{{PROCESS_COPY_ENDPOINT}}` | low | `process-query` |
| `consultar-documento.md` | `{{PERSON_SEARCH_ENDPOINT}}` | low | `person-search` |
| `enviar-email.md` | `{{SEND_EMAIL_ENDPOINT}}` | medium | `send-email` |

`exemplo-consultar-processo.md` é só referência de formato e não deve ser
invocado.

### Ativar um workflow

1. provisione o fluxo na automação;
2. preencha a variável de endpoint no `assistant.env` da VPS;
3. mude `status: placeholder` para `status: active` no arquivo do workflow;
4. registre-o na tabela acima.

Sem os quatro passos, o agente não executa.

## Manutenção

Ao registrar um workflow: crie `<nome>.md` **e** a entrada neste índice. Workflow
sem entrada no índice é workflow inexistente para o agente.
