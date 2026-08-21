---
type: skills-contract
status: active
created: 2026-08-21
updated: 2026-08-21
---

# Skills Contract

Uma Skill é **conhecimento operacional** em Markdown comum, independente de
runtime. Este arquivo define o formato esperado. Nenhuma Skill real foi criada
ainda — o padrão está apenas preparado para recebê-las.

## Skill vs Tool

### Skill — conhecimento operacional
Define **como executar uma tarefa**. Exemplos futuros:

```text
organizar segundo cérebro
cadastrar compromisso
adicionar backlog
consultar processo
baixar processo
```

### Tool — capacidade computacional
Define **o que é tecnicamente possível**. Nomes conceituais, jamais nomes
proprietários de runtime (ver `../00-system/runtime-contract.md`):

```text
read_file
write_file
append_file
list_files
search_text
http_request
```

Uma Skill cita `append_file`; o runtime decide se isso vira uma chamada MCP,
uma função Python ou um `>>` de shell.

## Estrutura de diretórios

```text
brain/70-skills/
├── system/
│   └── organize-brain/
│       └── SKILL.md
├── personal/
│   └── agenda/
│       └── SKILL.md
└── automation/
    └── n8n/
        └── SKILL.md
```

Padrão preferencial: `<categoria>/<nome-da-skill>/SKILL.md`.
O diretório próprio permite anexar arquivos de apoio (templates, exemplos) à
Skill sem poluir o índice.

## Conteúdo mínimo de um SKILL.md

Uma Skill deve responder, explicitamente, a todas estas perguntas:

| Seção            | Pergunta que responde                     |
| ---------------- | ----------------------------------------- |
| `When to use`    | quando deve ser usada                     |
| `Goal`           | qual objetivo possui                      |
| `Reads`          | quais arquivos pode consultar             |
| `Writes`         | quais arquivos pode alterar               |
| `Tools`          | quais ferramentas são necessárias         |
| `Required input` | quais dados são obrigatórios              |
| `Procedure`      | qual procedimento seguir                  |
| `Stop conditions`| quando deve parar                         |
| `Ask when`       | quando deve pedir esclarecimento          |
| `Never`          | o que não deve fazer                      |
| `Output format`  | qual formato de resposta produzir         |

## Template

```markdown
---
type: skill
name: <nome-da-skill>
status: active
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# <nome-da-skill>

## When to use
<gatilhos observáveis no pedido do usuário>

## Goal
<resultado esperado, em uma frase>

## Reads
- <path relativo ao brain>

## Writes
- <path relativo ao brain>

## Tools
- read_file
- append_file

## Required input
- <campo>: <descrição> (obrigatório)

## Procedure
1. ...
2. ...

## Stop conditions
- <condição que encerra a execução com sucesso>
- <condição que encerra sem executar>

## Ask when
- <dado obrigatório ausente>
- <ambiguidade de destino ou de intenção>

## Never
- ...

## Output format
<estrutura da resposta ao usuário>
```

## Regras de escrita de Skills

- Paths sempre relativos a `brain/`.
- Nenhum secret; use `{{VARIAVEL}}` para endpoints e credenciais.
- Sem sintaxe específica de runtime.
- `Writes` é uma **fronteira**: o que não está listado não pode ser alterado.
- Se a Skill não cobrir o caso, ela deve mandar parar, não improvisar.
- Toda Skill nova precisa de uma entrada em `INDEX.md`.
