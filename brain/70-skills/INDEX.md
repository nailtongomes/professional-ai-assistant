---
type: skills-index
status: active
created: 2026-08-21
updated: 2026-08-21
---

# Skills Index

Ponto de entrada obrigatório antes de qualquer ação. Este índice é deliberadamente
curto: ele deve caber no contexto inteiro, e só a Skill selecionada é carregada
por completo (progressive disclosure).

```text
pedido do usuário
→ índice de Skills
→ seleção da Skill
→ leitura do SKILL.md
→ execução
```

Se nenhuma entrada abaixo corresponder ao pedido, ou se a correspondência for
ambígua: **não executar**. Explique ao usuário o que falta e ofereça criar a Skill.

## Formato de cada entrada

```markdown
## <name>

Description:
<uma linha sobre o que a Skill faz>

Path:
<categoria>/<nome-da-skill>/SKILL.md

When to use:
<gatilho observável no pedido do usuário>
```

## Categorias previstas

| Categoria     | Escopo                                          |
| ------------- | ----------------------------------------------- |
| `system/`     | manutenção do próprio brain                     |
| `personal/`   | vida pessoal (agenda, hábitos, finanças)        |
| `productivity/` | gestão de projetos, backlog e execução pessoal |
| `professional/` | trabalho, clientes, processos                 |
| `automation/` | disparo de workflows externos (n8n, Kestra)     |

## Skills registradas

## organize-brain

Description:
Classifica e armazena novas informações no segundo cérebro usando a taxonomia
definida pelo sistema.

Path:
system/organize-brain/SKILL.md

When to use:
Quando o usuário pedir para anotar, registrar, guardar, organizar ou persistir
uma informação sem indicar um procedimento especializado melhor.

## manage-project

Description:
Gerencia criação, consulta, estado, backlog, decisões e notas de projetos.

Path:
productivity/manage-project/SKILL.md

When to use:
Quando o usuário pedir para criar, consultar ou atualizar um projeto, ou registrar
informação explicitamente relacionada a um projeto.

## backlog

Description:
Registra rapidamente itens para lembrar, avaliar, pesquisar ou fazer depois.

Path:
productivity/backlog/SKILL.md

When to use:
Quando o usuário pedir para colocar algo no backlog, guardar para depois, lembrar
de avaliar, pesquisar ou fazer futuramente.

<!--
Exemplo de entrada, para referência de formato (não é uma Skill ativa):

## agenda

Description:
Gerencia compromissos e eventos.

Path:
personal/agenda/SKILL.md

When to use:
Quando o usuário pedir para consultar, criar ou alterar compromissos.
-->

## Manutenção

Ao adicionar uma Skill: crie `<categoria>/<nome>/SKILL.md` **e** registre a
entrada aqui. Uma Skill não indexada é uma Skill inexistente para o agente.
