# Skills Contract

Skills são conhecimento operacional independente de runtime.

## Estrutura recomendada

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

Padrão preferencial:

```text
<categoria>/<nome-da-skill>/SKILL.md
```

## Skill vs Tool

### Skill
Conhecimento operacional que define **como executar uma tarefa**.

Exemplos futuros:
- organizar segundo cérebro
- cadastrar compromisso
- adicionar backlog
- consultar processo
- baixar processo

### Tool
Capacidade computacional usada pela Skill.

Exemplos conceituais:
- `read_file`
- `write_file`
- `append_file`
- `list_files`
- `http_request`

Evite acoplamento direto com nomes proprietários de runtimes.

## Conteúdo mínimo esperado em cada Skill

Uma Skill deve responder claramente:

- quando deve ser usada;
- qual objetivo possui;
- quais arquivos pode consultar;
- quais arquivos pode alterar;
- quais ferramentas são necessárias;
- quais dados são obrigatórios;
- qual procedimento seguir;
- quando deve parar;
- quando deve pedir esclarecimento;
- o que não deve fazer;
- qual formato de resposta produzir.
