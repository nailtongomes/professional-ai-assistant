# Restore

Operação de **alto risco**: substitui o brain ativo.

## Nunca faça isso

Copiar arquivos por cima do brain ativo:

```bash
# NÃO
tar xzf brain.tar.gz -C /srv/professional-ai-assistant/
cp -r backup/* /srv/professional-ai-assistant/brain/
```

Isso mistura dois estados: arquivos criados depois do backup sobrevivem, os
restaurados entram por cima, e o resultado não corresponde a momento nenhum.
Use o script.

## Procedimento

### 1. Escolher o backup

```bash
ls -1 /var/backups/professional-ai-assistant/
cat /var/backups/professional-ai-assistant/<stamp>/manifest.txt
```

### 2. Dry-run — obrigatório antes do real

```bash
sudo ./scripts/restore.sh --dry-run /var/backups/professional-ai-assistant/<stamp>
```

Valida o pacote, confere os checksums e mostra o que seria restaurado. Não
altera nada.

### 3. Restaurar

```bash
sudo ./scripts/restore.sh /var/backups/professional-ai-assistant/<stamp>
```

Pede confirmação: é preciso digitar `RESTORE`. Nenhuma outra resposta prossegue.

### 4. Verificar

```bash
sudo ./scripts/healthcheck.sh
```

## O que o script garante

1. valida o backup antes — `tar tzf` e `SHA256SUMS`;
2. mostra o plano;
3. **faz backup do estado atual** antes de sobrescrever;
4. extrai para um diretório temporário e troca por `mv` — sem `rm -rf` do brain;
5. preserva o brain anterior em `<brain>.previous.<stamp>`;
6. ajusta o dono para `assistant`;
7. roda o healthcheck no fim.

O brain anterior **não é apagado**. Remova você mesmo, depois de conferir:

```bash
sudo rm -rf /srv/professional-ai-assistant/brain.previous.<stamp>
```

## Secrets

Não são restaurados por padrão. Com `--restore-secrets`, o `assistant.env` do
backup sobrescreve o atual — só se o backup tiver sido feito com
`--include-secrets`.

## Automação

```bash
sudo ./scripts/restore.sh --yes <backup>
```

Existe para automação futura. **Nunca** é assumido: sem `--yes`, a confirmação
interativa é obrigatória.

## Restaurar em máquina nova

```bash
git clone https://github.com/nailtongomes/professional-ai-assistant.git
cd professional-ai-assistant
sudo ./scripts/install.sh              # cria estrutura e brain vazio
sudo ./scripts/restore.sh <backup>     # substitui pelo brain real
sudo ./scripts/healthcheck.sh
```

O `assistant.env` precisa ser preenchido à mão — os secrets não vêm no backup.
