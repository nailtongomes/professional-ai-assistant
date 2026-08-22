# Benchmarks de runtime

Comparar Nanobot e Hermes **com as mesmas entradas**, para que a escolha futura
seja decidida por dado e não por impressão.

Nesta fase existe apenas o **formato**. Nenhum benchmark foi executado, e nada
aqui chama API paga.

## Estrutura

```text
benchmarks/
├── README.md
├── scenarios/    entradas idênticas para qualquer runtime
└── results/      saídas, um arquivo por execução (não versionadas)
```

Os cenários reaproveitam a expectativa já registrada em `tests/cases/*.json` —
mesma fonte de verdade, dois usos: teste conceitual e comparação entre runtimes.

## Cenários

| # | Cenário | Verifica |
| - | ------- | -------- |
| 1 | adicionar backlog | seleção de Skill simples |
| 2 | consultar agenda | leitura com progressive disclosure |
| 3 | criar projeto | escrita estruturada |
| 4 | selecionar process-query | roteamento entre Skills próximas |
| 5 | montar payload de consulta | fidelidade ao contrato |
| 6 | rejeitar ação sem Skill | `NO SKILL → NO ACTION` |
| 7 | rejeitar secret em memory | recusa de credencial |
| 8 | identificar conflito de agenda | leitura antes de escrita |
| 9 | invocar workflow conhecido | integração HTTP |
| 10 | negar workflow desconhecido | `UNKNOWN WORKFLOW = NO ACTION` |

Metade mede acerto; metade mede **recusa**. Um runtime que executa tudo que
pedem não é melhor — é pior.

## Schema de resultado

```json
{
  "runtime": "nanobot|hermes",
  "model": "string",
  "scenario": "string",
  "success": true,
  "expected_skill": "string",
  "selected_skill": "string",
  "tool_calls": 1,
  "input_tokens": 0,
  "output_tokens": 0,
  "latency_ms": 0,
  "estimated_cost": 0,
  "notes": ""
}
```

Nem todo runtime expõe todas as métricas. Campo indisponível é `null` — nunca
zero, que se confunde com medição real.

## Critério de comparação

```text
accuracy · token usage · latency · cost · tool-call efficiency
security · operational complexity · update reliability
memory behavior · skill compatibility
```

**Nenhum vencedor é declarado nesta PR.** Custo e latência dependem do modelo,
não só do runtime; comparar sem fixar o modelo mede a coisa errada.

Antes de rodar, decida: mesmo modelo nos dois? Então mede runtime. Modelos
diferentes? Então mede a combinação, e a conclusão vale só para ela.
