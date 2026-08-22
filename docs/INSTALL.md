# Instalação

Guia da instalação futura na VPS. Nada aqui foi executado em produção.

## Camadas e onde cada coisa mora

| Camada          | Caminho                                    | Some se apagar? |
| --------------- | ------------------------------------------ | --------------- |
| SOURCE          | `/opt/professional-ai-assistant/repo`      | não — está no Git |
| BRAIN           | `/srv/professional-ai-assistant/brain`     | **sim — é insubstituível** |
| RUNTIME         | `/var/lib/professional-ai-assistant/runtime` | não — estado derivado |
| CONFIG/SECRETS  | `/etc/professional-ai-assistant/assistant.env` | sim — refazível, mas com trabalho |
| BACKUPS         | `/var/backups/professional-ai-assistant`   | é a rede de segurança |

O repositório Git não é o lugar dos dados mutáveis. O Nanobot não é a fonte da
verdade. O brain nunca é apagado por install ou update.

## Sequência

### 1. Preparar a VPS

Linux com `git`, `curl`, `tar`, `sha256sum` e **Python 3.11+** (exigência do
instalador oficial do Nanobot). O `install.sh` instala `git` e `curl` se
faltarem; o resto é responsabilidade do operador.

### 2. Clonar o repositório

```bash
git clone https://github.com/nailtongomes/professional-ai-assistant.git
cd professional-ai-assistant
```

### 3. Revisar a configuração

```bash
cat .env.example
```

### 4. Criar a configuração real

O `install.sh` cria `/etc/professional-ai-assistant/assistant.env` a partir do
exemplo, com permissão `0600`, e **nunca sobrescreve** um arquivo existente.

O `.env.example` vem com todos os valores vazios, de propósito: o repositório é
público. Domínios, endpoints de workflow, webhooks e credenciais só existem no
arquivo da VPS — nunca no Git, nunca em `brain/`. Ver
[OPERATIONS](OPERATIONS.md#repositório-público-vs-configuração-privada).

### 5. Dry-run

```bash
sudo ./scripts/install.sh --dry-run
```

Mostra tudo que seria feito. Não escreve nada.

### 6. Instalar

```bash
sudo ./scripts/install.sh
```

O script é idempotente: rodar de novo converge para o mesmo estado, preservando
brain, configuração e Skills locais.

### 7. Healthcheck

```bash
sudo ./scripts/healthcheck.sh
```

Saída: `0` tudo ok, `2` ok com avisos, `1` falha.

### 8. Configurar o Nanobot

Como usuário `assistant`, não como root:

```bash
sudo -u assistant -H nanobot agent -m "ping"
sudo -u assistant -H nanobot gateway --background
sudo -u assistant -H nanobot gateway status
```

### 9. Canais (depois)

Telegram e afins só depois que o assistente estiver saudável localmente — e
sempre com a allowlist do owner aplicada antes de o canal subir:

```bash
sudo ./scripts/configure-nanobot.sh --dry-run
sudo ./scripts/configure-nanobot.sh
```

O MVP é owner-only por construção: sem `OWNER_TELEGRAM_ID`, o canal é
desabilitado em vez de aberto. Ver
[OPERATIONS](OPERATIONS.md#mvp-access-model).

### 10. Exposição web (por último)

O domínio do assistente (`ASSISTANT_DOMAIN`) ainda **não** é configurado.
Ver `OPERATIONS.md`.

## Trust boundary: `curl | sh`

O instalador oficial do Nanobot é:

```bash
curl -fsSL https://raw.githubusercontent.com/HKUDS/nanobot/main/scripts/install.sh | sh
```

Isso executa código remoto de terceiro sem inspeção. Se o repositório upstream
for comprometido, o comando executa o que vier — com as permissões de quem
rodou.

**Nosso `install.sh` não usa esse pipe.** Ele baixa o instalador para arquivo,
roda o `--dry-run` oficial primeiro, e só então executa — como usuário
`assistant`, nunca como root. Ainda assim, é código de terceiro: o risco é
reduzido, não eliminado.

Para auditar você mesmo antes:

```bash
curl -fsSL https://raw.githubusercontent.com/HKUDS/nanobot/main/scripts/install.sh -o /tmp/nanobot-install.sh
less /tmp/nanobot-install.sh
sh /tmp/nanobot-install.sh --dry-run
sh /tmp/nanobot-install.sh
```

## Versão do Nanobot

O Nanobot é dependência externa substituível. Este repositório não se acopla ao
código dele.

Política padrão: **última versão estável** publicada pelo instalador oficial —
que não oferece pinning próprio.

Para fixar uma versão, defina `NANOBOT_VERSION` em `assistant.env` e instale
manualmente, como `assistant`:

```bash
sudo -u assistant -H uv tool install 'nanobot-ai==<versão>'
# ou
sudo -u assistant -H python3 -m pip install --user 'nanobot-ai==<versão>'
```

Com `NANOBOT_VERSION` preenchido, o `install.sh` avisa que o pin é manual, em
vez de fingir que o instalador oficial o respeita.

A versão instalada é registrada no healthcheck, no manifesto de cada backup e no
resumo do update.

## Onde o Nanobot é instalado

O instalador oficial não exige root e não altera o PATH. Ele usa `uv`, `pipx` ou
uma venv gerenciada em `~/.nanobot/venv`, e cria um wrapper em
`${NANOBOT_BIN_DIR:-~/.local/bin}/nanobot`.

Por isso nossos scripts **não assumem `nanobot` no PATH**: procuram em
`$NANOBOT_BIN`, no PATH e no wrapper padrão, nessa ordem.
