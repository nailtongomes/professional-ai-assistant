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

## Workflows registrados

_Nenhum workflow real registrado._

O arquivo `exemplo-consultar-processo.md` existe apenas como referência de
formato e **não deve ser invocado**: seu endpoint não aponta para nenhum serviço
real. Registre workflows reais aqui, um por arquivo.

## Manutenção

Ao registrar um workflow: crie `<nome>.md` **e** a entrada neste índice. Workflow
sem entrada no índice é workflow inexistente para o agente.
