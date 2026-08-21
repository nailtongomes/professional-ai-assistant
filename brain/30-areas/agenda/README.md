---
type: area
status: active
created: 2026-08-21
updated: 2026-08-21
---

# Agenda

Timezone: America/Fortaleza

Eventos são armazenados usando horário local, salvo indicação explícita diferente.

## Estrutura

Um arquivo por mês, em `events/`:

```text
events/
├── 2026-08.md
├── 2026-09.md
└── ...
```

Arquivos mensais reduzem conflito de sincronização, tamanho de arquivo e custo de
leitura — só o mês consultado precisa ser aberto.

## Formato

```markdown
# Agosto 2026

## 2026-08-21

- 09:00 | Reunião com Henrique
- 14:00-15:00 | Revisar proposta
- all-day | Evento da OAB
```

Datas em ISO `YYYY-MM-DD`, horários em `HH:MM`, formato 24 horas.

## Configuração

O campo `Timezone` acima é a fonte da configuração — ajuste-o para o seu fuso.
Nenhuma Skill deve codificar timezone internamente; todas leem daqui.

Procedimento operacional: `../../70-skills/productivity/agenda/SKILL.md`.
