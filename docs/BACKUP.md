# Backup

## O que é backup — e o que não é

Três mecanismos diferentes, que muita gente confunde:

| Mecanismo | Responde a | Não resolve |
| --------- | ---------- | ----------- |
| **Git** | "qual é a versão da metodologia e do código?" | perda de dados pessoais — eles não estão lá |
| **Syncthing** | "meus dados estão disponíveis nas duas máquinas?" | apagou de um lado, apaga do outro |
| **Backup** | "consigo voltar ao estado de ontem?" | disponibilidade em tempo real |

Syncthing **não é backup**: ele replica o erro. Git **não é backup** dos seus
dados: o brain operacional não é versionado neste repositório.

## O que entra

- `brain/` inteiro, empacotado em `brain.tar.gz`
- `managed-paths.txt` — o manifesto vigente
- `managed-state.sha256` — o estado do último sync
- `manifest.txt` — timestamp, commit do template, versão do Nanobot, contagem
  de arquivos, se há secrets
- `SHA256SUMS` — checksums de tudo que está no diretório

## O que fica de fora

Cache, logs, venv, pacotes reinstaláveis, checkout Git completo, artefatos de
Syncthing (`.stfolder`, `.stversions`, `*.sync-conflict-*`) e `.obsidian/`.

**Secrets ficam de fora por padrão.** Um backup com credenciais é um alvo. Para
incluí-los, é decisão explícita:

```bash
sudo ./scripts/backup.sh --include-secrets
```

O manifesto registra `secrets_included: yes` — e o diretório resultante precisa
ser tratado como material sensível.

## Onde fica

```text
/var/backups/professional-ai-assistant/2026-08-21T143500Z/
├── brain.tar.gz
├── manifest.txt
├── managed-paths.txt
├── managed-state.sha256
└── SHA256SUMS
```

Permissão `0700`. Nomes em UTC, ISO 8601.

## Como executar

```bash
sudo ./scripts/backup.sh --dry-run          # mostra sem criar nem remover
sudo ./scripts/backup.sh                    # cria
sudo ./scripts/backup.sh --retention-days 30
```

O `update.sh` chama o backup sozinho, antes de qualquer alteração. Backup que
falha aborta o update.

## Atomicidade

O backup é montado em `<stamp>.partial` e renomeado no fim. Um diretório com
nome final é, por construção, um backup completo — se você encontrar um
`.partial`, ele é lixo de uma execução interrompida.

## Retenção

`BACKUP_RETENTION_DAYS` (padrão `14`). A remoção:

- nunca roda em `--dry-run`;
- só considera diretórios dentro de `/var/backups/professional-ai-assistant`;
- só aceita nomes com formato exato de timestamp;
- passa por validação de path antes de cada remoção;
- nunca remove a própria raiz de backups.

## Como verificar um backup

```bash
cat /var/backups/professional-ai-assistant/<stamp>/manifest.txt
tar tzf /var/backups/professional-ai-assistant/<stamp>/brain.tar.gz | head
cd /var/backups/professional-ai-assistant/<stamp> && sha256sum -c SHA256SUMS
```

Um backup que você nunca testou restaurar é uma hipótese, não uma garantia.
