---
type: system-ownership
status: active
created: 2026-08-21
updated: 2026-08-21
---

# Ownership de arquivos

Quem pode alterar o quê. Existe para que nenhum update sobrescreva trabalho seu,
e nenhum agente altere regra do sistema por conta própria.

Três categorias, sem meio-termo.

## managed — controlado pelo repositório

Metodologia, regras e Skills oficiais.

```text
INDEX.md
00-system/           (PHILOSOPHY, agent-rules, conventions, taxonomy,
                      runtime-contract, OWNERSHIP)
70-skills/README.md
70-skills/INDEX.md
Skills oficiais listadas em config/managed-paths.txt
60-memory/*.example.md
```

| Quem altera | Como |
| ----------- | ---- |
| Git | commit no repositório do template |
| `sync.sh` / `update.sh` | aplicam a versão do template |
| você, na instância | **só** com procedimento explícito (ver abaixo) |
| o agente, em runtime | **nunca** |

O agente não edita `managed` — nem para "corrigir" uma regra, nem para
acrescentar uma Skill. Regra que o próprio agente reescreve deixa de ser regra.

Para alterar um arquivo `managed` de verdade: edite no repositório, commite,
e deixe o `update.sh` distribuir. Alterar direto na instância é possível, mas
gera conflito no próximo sync — que é exatamente o aviso que você quer.

## user-owned — seu conteúdo operacional

Tudo que você e o agente produzem no dia a dia.

```text
10-inbox/          20-projects/      30-areas/        50-people/
60-memory/*.md     70-skills/ (Skills locais não listadas no manifesto)
40-resources/      90-archive/       notas, backlogs, decisões e agenda reais
```

| Quem altera | Como |
| ----------- | ---- |
| você | editor, Obsidian, à mão |
| o agente | conforme a Skill autorizar |
| `sync.sh` / `update.sh` | **nunca** |

Nenhum script de update escreve, move ou apaga aqui. É a garantia que sustenta
"atualizar sem medo".

## local-managed — técnico e local da instância

```text
/etc/professional-ai-assistant/assistant.env
/var/lib/professional-ai-assistant/runtime/
/var/log/professional-ai-assistant/
/var/backups/professional-ai-assistant/
overrides locais, sessões, cache
```

| Quem altera | Como |
| ----------- | ---- |
| você, como administrador | à mão, na máquina |
| os scripts | dentro do que cada um declara |
| Git | **nunca** — não é versionado |

**Nunca assuma que isto se replica pelo Git.** Ao montar uma instância nova,
`local-managed` é recriado do zero ou restaurado de backup. Os secrets nunca
saem daqui.

## As três regras

1. Nenhum script de update pode sobrescrever `user-owned`.
2. Nenhum agente pode alterar `managed` sem procedimento administrativo
   explícito.
3. `local-managed` nunca deve ser assumido como replicável pelo Git.

## Onde a fronteira mora

`config/managed-paths.txt`, no repositório, é a lista **exaustiva** do que é
`managed`. Paths explícitos, sem glob: dá para ler a lista inteira e saber o que
um update alcança.

O que não está no manifesto é `user-owned` — inclusive Skills que você criar. É
proteção por omissão, que é o padrão seguro: esquecer de listar não expõe nada,
só deixa de atualizar.

## Conflito

Arquivo `managed` alterado localmente **e** alterado no template: o `sync.sh`
avisa e não escreve. Nenhum processo automático decide qual versão de
`PHILOSOPHY.md` ou de uma Skill prevalece — isso é decisão de pessoa. Ver
`../../docs/OPERATIONS.md`.
