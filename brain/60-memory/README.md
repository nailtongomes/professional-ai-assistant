---
type: memory-index
status: active
created: 2026-08-21
updated: 2026-08-21
---

# Memory

Memória persistente do usuário, em Markdown puro. Separada por durabilidade e por
natureza da informação — não por assunto.

| Arquivo          | Contém                                  | Muda com que frequência |
| ---------------- | --------------------------------------- | ----------------------- |
| `profile.md`     | fatos relativamente estáveis            | raramente               |
| `preferences.md` | preferências explícitas do usuário      | ocasionalmente          |
| `decisions.md`   | decisões relevantes, com contexto e motivo | por evento           |
| `lessons.md`     | aprendizados confirmados pelo uso       | por evento              |

Os arquivos `*.example.md` são **referência de estrutura** e permanecem no repositório.
Os arquivos operacionais (`profile.md` etc.) são criados por `scripts/bootstrap.sh`
e não são versionados neste repositório de metodologia.

## Regras

- Registrar apenas o que for **durável e confirmado**.
- Hipótese não vira fato (`../00-system/agent-rules.md`, regra 8).
- Sugestão não vira decisão (regra 9).
- Uma decisão só entra em `decisions.md` quando for explícita ou suficientemente
  confirmada pelo usuário (regra 10).
- Entradas cronológicas usam `## YYYY-MM-DD — título` e são adicionadas por
  **append**, preservando o histórico.
- Nenhum secret, em nenhuma hipótese.
