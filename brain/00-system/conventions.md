---
type: system-conventions
status: active
created: 2026-08-21
updated: 2026-08-21
---

# File Conventions

## Formato e codificação

- Nomes de arquivos e diretórios em `kebab-case`.
- Markdown (`.md`) como formato padrão.
- Codificação UTF-8, quebra de linha `LF`.
- Datas em ISO `YYYY-MM-DD`.
- Timestamps em ISO 8601 quando necessários (`2026-08-21T14:30:00-03:00`).

## Estrutura de conteúdo

- Preferir links relativos (`../20-projects/exemplo.md`).
- Evitar paths absolutos dentro dos arquivos do brain.
- Wikilinks (`[[nota]]`) apenas quando não quebrarem a leitura fora do Obsidian.
- Frontmatter YAML simples e **opcional**.
- Conteúdo legível por humano sem depender de plugins.
- Nenhuma informação crítica deve depender de sintaxe proprietária do Obsidian
  (dataview, templater, callouts etc.).

## Frontmatter

Chaves reconhecidas (todas opcionais):

| Chave     | Valores sugeridos                                  |
| --------- | -------------------------------------------------- |
| `type`    | `project`, `area`, `resource`, `person`, `memory`, `inbox`, `skill` |
| `status`  | `active`, `paused`, `done`, `archived`             |
| `created` | data ISO                                            |
| `updated` | data ISO                                            |
| `tags`    | lista simples de strings                            |

Exemplo:

```yaml
---
type: project
status: active
created: 2026-08-21
updated: 2026-08-21
---
```

## Granularidade (importa para Syncthing)

- Prefira **arquivos menores** e notas novas a arquivos monolíticos.
- Prefira **append** no fim do arquivo a reescrita completa.
- Divida por projeto, assunto ou data quando o arquivo crescer.
- Registros cronológicos (decisions, lessons) usam seções `## YYYY-MM-DD — título`,
  em ordem cronológica inversa ou direta, mas consistente dentro do arquivo.

## Nomes de arquivo

```text
20-projects/migracao-vps/README.md
20-projects/migracao-vps/2026-08-21-notas.md
50-people/fulano-de-tal.md
40-resources/n8n/webhooks.md
```
