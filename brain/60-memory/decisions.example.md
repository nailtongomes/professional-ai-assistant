# Decisions (example)

## 2026-08-21 — Estrutura base em Markdown puro

Context:
Necessidade de manter portabilidade entre runtimes.

Decision:
Usar Markdown simples como formato central dos dados e procedimentos.

Reason:
Reduz lock-in tecnológico e facilita inspeção manual/auditoria.

Consequences:
Qualquer runtime compatível com filesystem pode operar sobre o brain.
