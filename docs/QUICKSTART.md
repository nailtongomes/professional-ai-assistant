# Quickstart

Comandos essenciais para instalar, atualizar, levar o brain para outra máquina e
replicar o assistente para um novo cliente.

Guias completos: [INSTALL](INSTALL.md) · [UPDATE](UPDATE.md) ·
[BACKUP](BACKUP.md) · [RESTORE](RESTORE.md) · [OPERATIONS](OPERATIONS.md)

---

## 1. Instalar

```bash
git clone https://github.com/nailtongomes/professional-ai-assistant.git
cd professional-ai-assistant

sudo ./scripts/install.sh --dry-run     # confere; não escreve nada
sudo ./scripts/install.sh               # instala
sudo ./scripts/healthcheck.sh           # 0 ok | 2 avisos | 1 falha
```

Depois, preencha a configuração real e valide:

```bash
sudo nano /etc/professional-ai-assistant/assistant.env
sudo ./scripts/healthcheck.sh
```

Esse arquivo é o único lugar onde domínios, endpoints e credenciais existem — o
repositório é público e só versiona nomes de variáveis. Ver
[OPERATIONS](OPERATIONS.md#repositório-público-vs-configuração-privada).

Idempotente: rodar de novo não duplica nada e não toca no brain existente.

### Fechar o acesso ao owner

O MVP é owner-only. Sem isso, o canal não sobe:

```bash
sudo sed -i '/^OWNER_TELEGRAM_ID=/d' /etc/professional-ai-assistant/assistant.env
echo 'OWNER_TELEGRAM_ID=<user id numérico, sem @>' \
  | sudo tee -a /etc/professional-ai-assistant/assistant.env >/dev/null
sudo ./scripts/configure-nanobot.sh
sudo ./scripts/doctor.sh
```

Sem o ID, o canal é **desabilitado** — nunca aberto. Ver
[OPERATIONS](OPERATIONS.md#mvp-access-model).

## 2. Atualizar

```bash
cd /opt/professional-ai-assistant/repo
sudo ./scripts/update.sh --dry-run
sudo ./scripts/update.sh
```

Faz backup antes. Aborta se o checkout tiver alterações locais ou se um arquivo
gerenciado estiver em conflito. Nunca apaga o brain.

## 3. Baixar uma cópia do brain

O brain vive na máquina, não no Git. Para levar uma cópia:

**Na máquina de origem** — gere o pacote:

```bash
sudo ./scripts/backup.sh
# imprime o caminho, ex.: /var/backups/professional-ai-assistant/2026-08-21T143500Z
```

**Na sua máquina** — baixe:

```bash
scp -r usuario@servidor:/var/backups/professional-ai-assistant/<stamp> ./brain-copia/
```

Ou o brain direto, sem passar por backup:

```bash
rsync -avz usuario@servidor:/srv/professional-ai-assistant/brain/ ./brain-copia/
```

**Abrir a cópia** — é Markdown puro: qualquer editor, ou o Obsidian apontado
para a pasta. Nenhum runtime é necessário para ler.

```bash
tar xzf ./brain-copia/brain.tar.gz -C ./
cat ./brain/INDEX.md
```

> O backup não contém secrets por padrão. Copiar o brain não copia credenciais.

## 4. Levar para outra máquina

```bash
# na máquina nova
git clone https://github.com/nailtongomes/professional-ai-assistant.git
cd professional-ai-assistant
sudo ./scripts/install.sh                       # estrutura + brain vazio

# traga o backup da máquina antiga e restaure por cima
sudo ./scripts/restore.sh --dry-run /caminho/do/backup
sudo ./scripts/restore.sh /caminho/do/backup

sudo nano /etc/professional-ai-assistant/assistant.env   # secrets à mão
sudo ./scripts/healthcheck.sh
```

Os secrets não viajam no backup — é a única parte manual, e é proposital.

## 5. Replicar para um novo cliente

Cada cliente é uma instância independente: mesmo template, brain próprio,
configuração própria, backups próprios. Nada é compartilhado entre eles.

```bash
git clone https://github.com/nailtongomes/professional-ai-assistant.git
cd professional-ai-assistant
sudo ./scripts/install.sh                # brain novo, do template, sem dados de ninguém
sudo nano /etc/professional-ai-assistant/assistant.env
sudo ./scripts/healthcheck.sh
```

Para gerar só o brain, sem instalar nada na máquina:

```bash
./scripts/bootstrap.sh /caminho/do/brain-do-cliente
python3 scripts/validate_structure.py --brain /caminho/do/brain-do-cliente
```

### Personalizar por cliente

| O que muda | Onde |
| ---------- | ---- |
| domínio, n8n, retenção, usuário de serviço | `/etc/professional-ai-assistant/assistant.env` |
| Skills específicas do cliente | `brain/70-skills/<categoria>/<nome>/SKILL.md` + `INDEX.md` |
| workflows do cliente | `brain/40-resources/automation/workflows/` |
| o que o template controla | `config/managed-paths.txt` |

Skills que você **não** listar em `config/managed-paths.txt` são locais daquele
cliente: nenhum update do template as toca. É assim que a mesma base serve
vários clientes sem que um herde as customizações do outro.

### Manter todos os clientes atualizados

Melhorias na metodologia e nas Skills oficiais saem daqui e chegam a cada
instância com o mesmo comando:

```bash
sudo ./scripts/update.sh --dry-run && sudo ./scripts/update.sh
```

Se um cliente tiver editado um arquivo gerenciado, o sync avisa em vez de
sobrescrever — o conflito é resolvido por uma pessoa, cliente a cliente.

---

## Referência rápida

| Preciso de… | Comando |
| ----------- | ------- |
| instalar | `sudo ./scripts/install.sh` |
| conferir sem alterar | qualquer script com `--dry-run` |
| atualizar | `sudo ./scripts/update.sh` |
| ver se está saudável | `sudo ./scripts/healthcheck.sh` |
| gerar backup | `sudo ./scripts/backup.sh` |
| restaurar | `sudo ./scripts/restore.sh <backup>` |
| aplicar só os arquivos do template | `sudo ./scripts/sync.sh` |
| criar um brain novo, isolado | `./scripts/bootstrap.sh <destino>` |
| validar um brain | `python3 scripts/validate_structure.py --brain <destino>` |
| versão instalada | `sudo ./scripts/healthcheck.sh` |

Todo script que altera estado aceita `--dry-run`.
