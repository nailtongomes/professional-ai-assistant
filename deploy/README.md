# Deploy na VPS

Layout, compose e o caminho entre o repositório e a máquina. Nada aqui foi
executado: o acesso SSH ainda não foi concedido.

## Layout

```text
/opt/brain/      dados canônicos — brain, memória, Skills     NUNCA apagar
/opt/runtime/    docker-compose.yml + .env do agente ativo    descartável
/opt/files/      changelog.md e utilitários operacionais
```

Mais os caminhos que os scripts do repositório já usam:

```text
/etc/professional-ai-assistant/assistant.env    secrets e configuração
/var/backups/professional-ai-assistant/         backups
/var/log/professional-ai-assistant/<runtime>/   logs por runtime
```

### Encaixe com os scripts

Os scripts usam `BRAIN_DIR` e demais caminhos como **variáveis**, com defaults
diferentes destes. Para operar no layout da VPS, defina no `assistant.env`:

```bash
BRAIN_DIR=/opt/brain
```

Não é refatoração: é o perfil da máquina. Todo o resto — `doctor`, `backup`,
`restore`, `sync` — passa a agir sobre `/opt/brain` sem alteração de código, e a
validação de path continua protegendo, porque as raízes seguras derivam das
mesmas variáveis.

## Regra de dependência

```text
runtime  ──referencia──►  brain      (volume mount)
brain    ──nunca──────►  runtime
```

O compose monta `/opt/brain` em `/brain` dentro do container. Nenhum arquivo do
brain sabe que existe container, imagem ou compose.

## Primeira instalação

Ordem, com confirmação a cada passo que altera estado:

```bash
# 1. estrutura e brain (o install.sh cria e preserva o que existir)
sudo ./scripts/install.sh --dry-run
sudo ./scripts/install.sh

# 2. configuração privada
sudo nano /etc/professional-ai-assistant/assistant.env   # BRAIN_DIR=/opt/brain, OWNER_*, ASSISTANT_RUNTIME
sudo chmod 600 /etc/professional-ai-assistant/assistant.env

# 3. acesso owner-only ANTES de qualquer canal subir
sudo ./scripts/configure-nanobot.sh --dry-run
sudo ./scripts/configure-nanobot.sh

# 4. runtime em container
sudo mkdir -p /opt/runtime /opt/files
sudo cp deploy/docker-compose.yml /opt/runtime/
sudo cp deploy/vps.env.example /opt/runtime/.env
sudo nano /opt/runtime/.env          # RUNTIME_IMAGE é obrigatório
sudo cp scripts/changelog.sh /opt/files/changelog.sh

cd /opt/runtime
docker compose config                # valida; não sobe nada
docker compose up -d

# 5. verificar e registrar
sudo /opt/professional-ai-assistant/repo/scripts/doctor.sh
/opt/files/changelog.sh "deploy inicial: runtime <imagem> no layout /opt"
```

`docker compose config` antes de `up` não é zelo excessivo: é o que pega
`RUNTIME_IMAGE` vazio ou volume errado sem criar container nenhum.

## Trocar de agente

```bash
sudo ./scripts/backup.sh                      # obrigatório antes
sudo nano /opt/runtime/docker-compose.yml     # image: (ou RUNTIME_IMAGE no .env)
```

**Conferir a conversão de schema antes de subir.** Memória e configuração não
migram sozinhas entre frameworks: formatos diferentes exigem script ou trabalho
manual. Isso não é plug-and-play, e tratar como se fosse é o jeito mais rápido
de perder memória.

```bash
cd /opt/runtime
docker compose down
docker compose up -d
sudo ./scripts/doctor.sh
/opt/files/changelog.sh "runtime: nanobot → hermes; brain/configs convertido por <script>"
```

O `brain/` em si não muda: ele nunca foi do runtime.

## Exposição web

O compose **não publica porta**. O domínio de `ASSISTANT_DOMAIN` já aponta para
a VPS, mas nada é servido até existirem reverse proxy, TLS e autenticação — os
cinco pré-requisitos estão em `docs/OPERATIONS.md`.

Quem alcança a interface do agente alcança o brain inteiro. Publicar uma porta
"só para testar" é o erro que dispensa todas as outras proteções.

## Comandos proibidos sem confirmação explícita

```text
docker system prune --volumes    docker volume rm
rm -rf <qualquer coisa>          escrita destrutiva em /opt/brain/memory
```

Ver `CLAUDE.md` e `docs/VPS-OPERATIONS.md`.
