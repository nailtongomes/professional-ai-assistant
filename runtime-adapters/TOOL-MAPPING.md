# Tool mapping

As Skills descrevem capacidades **conceituais**. Nenhuma menciona tool
proprietária de runtime — é o que permite trocar o harness sem reescrevê-las.

Esta tabela é a tradução, e vive fora do brain de propósito: é conhecimento de
integração, não metodologia.

| Capacidade conceitual | Nanobot | Hermes |
| --------------------- | ------- | ------ |
| `read file` | tool de filesystem do runtime | tool de filesystem do runtime |
| `write file` | idem | idem |
| `append file` | idem | idem |
| `list directory` | idem | idem |
| `search text` | idem, quando exposto | idem, quando exposto |
| `http request` | tool HTTP do runtime | tool HTTP do runtime |

Ambos expõem conjuntos de tools próprios — o Hermes documenta 40+ tools,
configuráveis via `hermes tools`. O nome exato de cada tool **não** é fixado
aqui: ele muda entre versões, e uma tabela desatualizada é pior que uma tabela
genérica. O que importa é que a capacidade exista.

## Regra

Nenhuma Skill deve ser reescrita para usar nome de tool de um runtime. Se uma
Skill precisar disso para funcionar, ela está acoplada — e o acoplamento é o bug.

## Como verificar em uma instalação real

```bash
# Hermes
hermes tools

# Nanobot
# consulte a documentação da versão instalada
```

Se uma capacidade da lista de paridade
(`runtime-adapters/hermes/README.md`) não existir no runtime, isso é um **gap**,
não um convite a workaround.
