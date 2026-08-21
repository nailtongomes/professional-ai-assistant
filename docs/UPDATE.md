# Update

```bash
cd /opt/professional-ai-assistant/repo
git status
sudo ./scripts/update.sh --dry-run
sudo ./scripts/update.sh
```

O script faz as próprias validações — os comandos acima são conveniência, não
pré-requisito.

## O que o update faz, em ordem

```text
preflight  → backup → fetch → validar → aplicar → sync → runtime → healthcheck
```

Falhou uma etapa crítica, **para**. Não segue em cascata.

| Etapa | O que acontece |
| ----- | -------------- |
| preflight | confere brain, dependências e se o checkout está limpo |
| backup | backup completo; **se falhar, o update é abortado** |
| fetch | `git fetch` da branch atual |
| validar | conta os commits a aplicar |
| aplicar | `git pull --ff-only` — sem merge, sem resolução automática |
| sync | só arquivos gerenciados; conflito aborta |
| runtime | reexecuta o instalador oficial do Nanobot |
| healthcheck | reprovou, o update falha |

## Alterações locais abortam o update

```text
Update aborted: repository has local changes.
```

O checkout em `/opt/.../repo` é controlado: nada nele deve ser editado à mão.
Commite, descarte, ou mova a alteração para o brain — que é onde trabalho
pessoal deve viver.

Nunca usamos `git reset --hard` nem merge automático. Se o pull não for
fast-forward, o update para e a resolução é humana.

## Se falhar no meio

A mensagem diz a etapa, o backup criado, a versão anterior e o comando de
restore. **Não afirmamos que houve rollback** — não houve. Restaurar é uma
decisão sua, documentada em `RESTORE.md`.

## Identificar a versão instalada

```bash
git -C /opt/professional-ai-assistant/repo rev-parse --short HEAD   # template
sudo -u assistant -H nanobot --version                              # runtime
sudo ./scripts/healthcheck.sh                                       # ambos
```

Cada backup também registra as duas versões em `manifest.txt`.

## Atualizar sem mexer no runtime

```bash
sudo ./scripts/update.sh --skip-nanobot
```
