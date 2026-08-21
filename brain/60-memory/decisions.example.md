---
type: memory
status: example
created: 2026-08-21
updated: 2026-08-21
---

# Decisions (example)

Registro append-only de decisões relevantes. Formato fixo, uma seção por decisão.

## 2026-08-21 — Estrutura base em Markdown puro

Context:
Necessidade de manter portabilidade entre runtimes de agente.

Decision:
Usar Markdown simples como formato central de dados e procedimentos.

Reason:
Reduz lock-in tecnológico e permite inspeção e auditoria manual.

Consequences:
Qualquer runtime com acesso a filesystem pode operar sobre o brain; em troca,
não há consultas estruturadas nem integridade referencial garantida.

## 2026-08-21 — Índice antes de varredura

Context:
Varrer o filesystem inteiro consome contexto e é imprevisível.

Decision:
Todo acesso começa por `brain/INDEX.md` e `brain/70-skills/INDEX.md`.

Reason:
Progressive disclosure mantém o custo de leitura baixo e previsível.

Consequences:
Índices desatualizados passam a ser um defeito operacional, não apenas estético.
