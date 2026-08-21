---
type: system-taxonomy
status: active
created: 2026-08-21
updated: 2026-08-21
---

# Taxonomy (PARA pragmático)

| Diretório       | Significado                                   | Critério de entrada |
| --------------- | --------------------------------------------- | ------------------- |
| `10-inbox/`     | captura rápida, não classificada              | há qualquer dúvida sobre onde salvar |
| `20-projects/`  | objetivo definido e possibilidade de conclusão| existe um "pronto" reconhecível |
| `30-areas/`     | responsabilidade contínua, sem fim previsto   | precisa ser mantido, não concluído |
| `40-resources/` | conhecimento reutilizável e referência        | útil para mais de um projeto |
| `50-people/`    | contexto sobre pessoas relevantes             | a informação é centrada em alguém |
| `60-memory/`    | fatos persistentes sobre o usuário            | é durável e confirmado |
| `70-skills/`    | procedimentos operacionais do agente          | ensina COMO executar uma tarefa |
| `90-archive/`   | conteúdo encerrado ou inativo                 | saiu de uso ativo, mas tem valor histórico |

## Regra de desempate

Em caso de dúvida, **Inbox**. Classificar errado custa mais caro que classificar
depois.

## Transições esperadas

```text
10-inbox → 20-projects | 30-areas | 40-resources | 50-people | 60-memory
20-projects (concluído) → 90-archive
30-areas (encerrada)    → 90-archive
```

Mover conteúdo é operação de alto risco (ver `agent-rules.md`, regra 17):
exige confirmação explícita do usuário.
