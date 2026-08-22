# Testes

Dois níveis, ambos rodando sem rede, sem VPS e sem runtime.

```bash
./tests/run-local-tests.sh          # ciclo de vida: scripts, sandbox temporária
python3 tests/validate_cases.py     # casos conceituais das Skills
python3 scripts/validate_structure.py
```

## O que os casos conceituais são — e o que não são

`tests/cases/*.json` registra **o comportamento esperado** de cada Skill: dada
uma frase do usuário, qual Skill deveria atender, que tipo de ação, sobre qual
alvo, e o que jamais pode acontecer.

**Isso é um contrato de expectativa humana, não uma garantia de resposta do
modelo.** Nenhum LLM é executado aqui. O validador confere schema, coerência com
o índice e higiene dos casos — ele não julga se um modelo real acertaria.

O valor está em outro lugar: quando você mudar uma Skill, o arquivo de casos diz
o que ela prometia antes. Se a mudança contradiz um caso, ou o caso está velho,
ou a mudança está errada. É o mais barato que dá para ter sem montar harness de
avaliação — e um harness desses é justamente o tipo de peça que uma pessoa só
não consegue manter.

## Formato

JSON, não YAML: `json` está na biblioteca padrão do Python, `yaml` não. Um
`pip install` a mais numa VPS é manutenção a mais, e o ganho de legibilidade não
paga.

```json
{
  "skill": "backlog",
  "cases": [
    {
      "name": "caso feliz — backlog global",
      "input": "Coloca no backlog estudar MCP.",
      "expected_skill": "backlog",
      "expected_action": "append",
      "expected_target": "10-inbox/backlog.md",
      "must_not": ["create project", "write memory", "invoke external workflow"]
    }
  ]
}
```

`expected_skill` pode ser **diferente** de `skill`: é assim que se registra
"este pedido parece meu, mas pertence a outra Skill". `send-email` deve vencer
`invoke-workflow` genérico; `backlog` deve vencer `manage-project` quando o
usuário disser "backlog".

### Ações aceitas

`create`, `append`, `update`, `read`, `http`, `confirm`, `ask`, `refuse`,
`report`, `noop`. Lista fechada de propósito: precisar de uma ação nova é sinal
para revisar o contrato das Skills antes de inventar vocabulário.

## Cobertura mínima por Skill

Cada arquivo deveria ter, no mínimo: caso feliz, informação ausente,
ambiguidade, ação proibida, secret presente, e um caso em que outra Skill é mais
adequada. O validador avisa quando faltam — como aviso, não erro: a régua é
guia, não burocracia.

## O que o validador checa

Schema mínimo · Skill existe em disco e está registrada no `INDEX.md` ·
`expected_action` dentro do vocabulário · alvo obrigatório para ações de escrita
· alvo nunca absoluto · `must_not` não vazio em caso sensível · nada com cara de
credencial real · nomes e inputs duplicados.

Ele **não** simula raciocínio, não pontua qualidade de resposta e não substitui
leitura do `SKILL.md`.

## Ao alterar uma Skill

1. atualize o `SKILL.md`;
2. atualize os casos, se o contrato mudou;
3. rode `python3 tests/validate_cases.py`;
4. se um caso antigo ficou errado, decida conscientemente — não apague só para
   o validador passar.
