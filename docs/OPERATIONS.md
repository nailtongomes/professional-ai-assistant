# Operações

Referência do dia a dia: o que cada script faz, o que é gerenciado, e o que
ainda não foi feito de propósito.

## Solo operator routine

O sistema é mantido por uma pessoa. Duas rotinas bastam.

### Antes de atualizar

```bash
sudo ./scripts/doctor.sh          # o estado está sadio?
sudo ./scripts/backup.sh          # rede de segurança
sudo ./scripts/update.sh --dry-run
sudo ./scripts/update.sh
sudo ./scripts/doctor.sh          # continua sadio?
```

O `update.sh` já faz backup sozinho — o backup explícito antes existe para o
caso de você querer o ponto de retorno mesmo se decidir não atualizar.

### Quando algo falhar

```bash
sudo ./scripts/doctor.sh --verbose        # ponto de partida único
ls /var/log/professional-ai-assistant/    # logs
# task_id da execução, quando houver, para rastrear na automação
```

Restaure **somente se necessário** — `docs/RESTORE.md`. Restore é a última
opção, não a primeira: quase toda falha é configuração ausente ou serviço fora
do ar, e o `doctor` diz qual.

### Ritmo sugerido

| Quando | O quê |
| ------ | ----- |
| ao mexer no sistema | `doctor.sh` antes e depois |
| semanal | `doctor.sh`; conferir idade do último backup |
| ao alterar Skill | `tests/validate_cases.py` |
| mensal | ler `docs/ENGINEERING-PRINCIPLES.md` e perguntar o que dá para remover |

Se essa rotina começar a crescer, o problema é o sistema, não o runbook.

## Scripts

| Script | Faz | Root | `--dry-run` |
| ------ | --- | ---- | ----------- |
| `install.sh` | estrutura, usuário, brain, config, runtime | sim | sim |
| `update.sh` | template + gerenciados + runtime, com backup antes | sim | sim |
| `sync.sh` | só os arquivos gerenciados, do template para o brain | sim | sim |
| `backup.sh` | brain, manifestos, metadados | sim | sim |
| `restore.sh` | substitui o brain a partir de um backup | sim | sim |
| `healthcheck.sh` | Nanobot, brain, permissões, n8n | não | n/a |
| `bootstrap.sh` | cria um brain novo a partir do template | não | sim |
| `doctor.sh` | diagnóstico somente leitura; não corrige nada | não | n/a |
| `configure-nanobot.sh` | aplica a allowlist owner-only ao config do Nanobot | sim | sim |

Todos são idempotentes. `install.sh` dez vezes converge para o mesmo estado.

## Concorrência

`install`, `update` e `restore` usam `flock` em
`/var/lock/professional-ai-assistant.lock`. Só um por vez. Sem `flock` no
sistema, seguem com aviso.

## MVP access model

O MVP atende **somente o proprietário**. A fronteira é determinística e fica no
canal, antes do agente:

```text
Owner
  │ Telegram ID / WhatsApp ID / Email
  ▼
allowFrom nativo do Nanobot
  │ sender fora da lista → descartado aqui
  ▼
Agent → brain / skills / tools
```

```text
UNKNOWN ID = NO LLM
NOT ALLOWED = NO AGENT
```

A rejeição acontece **antes do LLM**: desconhecido não consome token, não
alcança o brain e não aparece em prompt nenhum.

Dois pontos que decorrem disso:

- **A identidade do owner é configuração operacional privada, não memória do
  agente.** Ela vive no `assistant.env` da VPS e no `config.json` do Nanobot —
  nunca em `brain/`, nunca numa Skill, nunca numa nota.
- **O LLM não decide quem é o owner.** Editar `PHILOSOPHY.md`, `agent-rules.md`
  ou qualquer prompt não concede acesso a ninguém: quando o texto é lido, a
  autorização já aconteceu. É por isso que a allowlist é do canal e não uma
  Skill.

### Configurar

```bash
sudo sed -i '/^OWNER_TELEGRAM_ID=/d' /etc/professional-ai-assistant/assistant.env
echo 'OWNER_TELEGRAM_ID=<seu user id numérico, sem @>' \
  | sudo tee -a /etc/professional-ai-assistant/assistant.env >/dev/null
sudo chmod 600 /etc/professional-ai-assistant/assistant.env

sudo ./scripts/configure-nanobot.sh --dry-run
sudo ./scripts/configure-nanobot.sh
sudo ./scripts/doctor.sh
```

O script edita o `config.json` existente preservando o resto — token, provider,
MCP, tudo que já estiver lá. Idempotente: rodar de novo não muda um byte.

O User ID do Telegram é numérico e **sem o `@`**. WhatsApp usa o sender ID
(telefone sem `+`) ou JID; Email usa o endereço.

### Fail closed

Variável do owner ausente **não** abre o canal:

| Situação | Resultado |
| -------- | --------- |
| `OWNER_TELEGRAM_ID` definido | `enabled: true`, `allowFrom: ["<id>"]` |
| `OWNER_TELEGRAM_ID` ausente ou vazio | `enabled: false`, `allowFrom: []`, exit 3 |
| `allowFrom: ["*"]` encontrado | substituído pelo owner; recusado se persistir |

Remover a variável por acidente **fecha** o acesso. Nunca o abre.

Por que desabilitar o canal em vez de confiar em `allowFrom: []`: a documentação
atual do Nanobot descreve `["*"]` (todos) e a omissão do campo (modo pairing),
mas **não** documenta explicitamente a semântica da lista vazia. Como o
comportamento não é garantido, o script não o usa como bloqueio — desabilita o
canal e deixa a lista vazia apenas como reforço.

### Pairing

O Nanobot suporta pairing quando `allowFrom` é omitido: o primeiro DM recebe um
código, aprovado com `/pairing approve <code>`.

Para este MVP, **preferimos allowlist estática**. Pairing é um fluxo interativo
com janela de aprovação; a allowlist é determinística e não tem janela. Pairing
segue disponível como opção futura, mas não substitui o owner allowlist agora.

### Wildcard

`allowFrom: ["*"]` bypassa o pairing e libera qualquer um que alcance o canal. Em
canal pessoal isso é **erro grave**: o `doctor` sai com código 2 e o
`configure-nanobot.sh` se recusa a gravar um config que o contenha.

Nenhum arquivo versionado deste repositório contém `["*"]`, e a suíte de testes
falha se alguém introduzir um.

### Future external-user access

Ainda **não implementado**, e deliberadamente fora desta fase:

```text
unknown user
  ▼
deterministic gate        (allowFrom continua sendo a primeira muralha)
  ▼
authorization service
  ▼
n8n / customer lookup
  ▼
allowed public skills
  ▼
metering / billing
```

Quando existir, a regra que já fica registrada: **usuário externo nunca recebe o
mesmo conjunto de tools e contexto do owner.**

| | OWNER | EXTERNAL USER |
| - | ----- | ------------- |
| brain pessoal | sim | não |
| memória, agenda, projetos | sim | não |
| Skills privadas | sim | não |
| Skills públicas | sim | apenas as autorizadas |
| tools administrativas | sim | não |

Nada disso entra sem dor real e documentada — `docs/ENGINEERING-PRINCIPLES.md`.
Sem banco de usuários, sem créditos, sem billing, sem ACL dinâmica agora.

## Diagnóstico

```bash
sudo ./scripts/doctor.sh                 # 0 ok | 1 degradado | 2 erro
sudo ./scripts/doctor.sh --skip-network  # sem nenhuma chamada HTTP
sudo ./scripts/doctor.sh --verbose       # detalhe por verificação
```

Somente leitura: não corrige, não altera permissão, não imprime valor de secret
— apenas `configured` ou `missing` por variável.

Verifica repositório (branch, commit, working tree), brain e arquivos
essenciais, paths do manifesto, permissão de escrita nas áreas do usuário,
scripts presentes e executáveis, Nanobot e versão, `assistant.env` e permissão,
health da automação, idade do último backup, e `validate_structure.py`.

Antes do deploy, Nanobot ausente é **aviso**, não erro.

Também reporta o controle de acesso por canal, sem imprimir o identificador
inteiro:

```text
telegram access    OK owner-only (...4821)
whatsapp access    DISABLED
email access       DISABLED
```

`ERROR allowFrom wildcard: acesso aberto` faz o `doctor` sair com código 2.

## Arquivos gerenciados vs. dados do usuário

`config/managed-paths.txt` é a fronteira. Só o que está listado ali pode ser
tocado por um update. A política completa — quem altera o quê — está em
`brain/00-system/OWNERSHIP.md`.

| Gerenciado (o template atualiza) | Do usuário (nunca tocado) |
| -------------------------------- | ------------------------- |
| `PHILOSOPHY.md`, `agent-rules.md`, `conventions.md`, `taxonomy.md`, `runtime-contract.md` | `10-inbox/`, `20-projects/`, `30-areas/`, `50-people/` |
| `INDEX.md`, `70-skills/INDEX.md`, `70-skills/README.md` | agenda real, memória real, notas, backlogs |
| as cinco Skills oficiais | Skills locais e experimentais |
| exemplos de memória (`*.example.md`) | `60-memory/*.md` operacionais |

**Por que um manifesto e não `70-skills/managed/` e `70-skills/local/`:** a
separação por diretório quebraria os índices e os paths já publicados, e
obrigaria a classificar toda Skill nova. O manifesto dá a mesma garantia sem
mexer na estrutura, e protege por omissão — o padrão seguro.

Nunca usamos `rsync --delete` contra o brain. Nada é apagado por um update.

## Conflitos

Arquivo gerenciado modificado localmente **e** alterado no template:

```text
CONFLITO  00-system/PHILOSOPHY.md — modificado localmente e alterado no template
```

O sync sai com código `3` e não escreve nada. Nenhum processo automático — e
nenhum LLM — decide qual versão de `PHILOSOPHY.md`, de `agent-rules.md` ou de
uma Skill prevalece.

```bash
diff /srv/professional-ai-assistant/brain/00-system/PHILOSOPHY.md \
     /opt/professional-ai-assistant/repo/brain/00-system/PHILOSOPHY.md
```

Resolva à mão e rode o sync de novo, ou aceite a versão do template com
`sync.sh --force` — que salva a sua versão em
`/var/backups/professional-ai-assistant/conflicts/<stamp>/` antes.

O conflito **persiste** entre execuções: um arquivo em conflito não é registrado
como sincronizado, então o sync seguinte não o sobrescreve em silêncio.

Nota conhecida: `70-skills/INDEX.md` é gerenciado, e é também onde você registra
Skills locais. Registrar uma Skill local ali gera conflito no próximo update do
índice. É a fricção aceita em troca de manter o índice único e consistente.

## Permissões

O runtime **não roda como root**. O `install.sh` cria o usuário de serviço
`assistant` (`--system`, sem shell de login).

| Caminho | Dono | Modo |
| ------- | ---- | ---- |
| `/srv/.../brain` | `assistant` | `0750` |
| `/var/lib/.../runtime` | `assistant` | `0750` |
| `/etc/professional-ai-assistant` | `root` | `0750` |
| `assistant.env` | `root` | `0600` |
| `/var/backups/...` | `root` | `0700` |

Root é só para administração. Least privilege.

## systemd

Nenhuma unit é criada. O Nanobot já oferece execução persistente própria:

```bash
sudo -u assistant -H nanobot gateway --background
sudo -u assistant -H nanobot gateway status
sudo -u assistant -H nanobot gateway logs
sudo -u assistant -H nanobot gateway restart
sudo -u assistant -H nanobot gateway stop
```

Criar uma unit paralela ao gerenciador do próprio Nanobot daria dois donos para
o mesmo processo. Se um dia for necessária, ela deve rodar como `assistant`,
carregar `EnvironmentFile=/etc/professional-ai-assistant/assistant.env`, ter
restart sensato e **não** expor a WebUI.

## Logs

`/var/log/professional-ai-assistant/`, dono `assistant`, modo `0750`.

Nunca registre tokens, senhas, chaves de API ou conteúdo pessoal desnecessário.
Os scripts não imprimem valores de configuração — só o caminho do arquivo.

## Healthcheck

```bash
sudo ./scripts/healthcheck.sh          # 0 ok | 2 avisos | 1 falha
sudo ./scripts/healthcheck.sh --quiet  # para cron
```

Verifica: binário do Nanobot, versão recuperável, estado do gateway pelo comando
oficial, diretório de configuração, brain presente e legível, dono do brain,
`validate_structure.py`, `${N8N_BASE_URL}/webhook/ping` = HTTP 200, diretórios
operacionais e permissão do `assistant.env`.

Processo existir não é saúde: o gateway é consultado pelo comando oficial.

`N8N_BASE_URL` vem sempre do ambiente. O domínio real aparece só no
`.env.example`, nunca na lógica.

## Repositório público vs. configuração privada

Este repositório é público. A regra é simples:

```text
Git público  =  sem domínios reais, sem endpoints, sem webhooks, sem secrets
```

O que fica versionado são **nomes de variáveis e contratos**. O que fica na VPS
são os valores:

```text
/etc/professional-ai-assistant/assistant.env   (0600, root, fora do Git)
```

Como o valor chega até a Skill:

```text
Skill
  │ usa
  ▼
{{PROCESS_QUERY_ENDPOINT}}
  │ resolvido pelo runtime, que carregou o assistant.env
  ▼
URL real
```

Nenhuma Skill conhece o domínio. Nenhum arquivo do brain conhece o endpoint. O
runtime carrega o env, resolve os nomes e faz a chamada — e é o único ponto onde
o valor real existe.

O **path do webhook também é sensível**: revela nome interno de fluxo e ajuda
quem quiser sondar a automação. Por isso cada workflow usa uma variável de
endpoint **completo**, em vez de base + path concatenados. Isso também deixa
mover um workflow de host sem tocar em arquivo versionado.

### Configurar um endpoint na VPS

Idempotente — remove a linha anterior antes de acrescentar, para não duplicar:

```bash
sudo sed -i '/^PROCESS_QUERY_ENDPOINT=/d' /etc/professional-ai-assistant/assistant.env
echo 'PROCESS_QUERY_ENDPOINT=https://SEU-ENDPOINT-PRIVADO' \
  | sudo tee -a /etc/professional-ai-assistant/assistant.env >/dev/null
sudo chmod 600 /etc/professional-ai-assistant/assistant.env
sudo ./scripts/healthcheck.sh
```

Rodar duas vezes deixa uma linha só. O mesmo vale para `N8N_BASE_URL`,
`SEND_EMAIL_ENDPOINT` e os demais.

Nunca cole o valor real em issue, PR, commit ou arquivo do brain.

### Nunca commitar

```text
domínio privado    webhook real    API key    token
password           certificado     cookie     session    credencial
```

O teste `nenhum host privado versionado`, em `tests/run-local-tests.sh`, varre
`scripts/`, `config/`, `brain/`, `docs/` e `.env.example` procurando qualquer
host fora da allowlist pública. Ele roda junto com a suíte.

## Domínio do assistente — ainda não configurado

O domínio pretendido fica em `ASSISTANT_DOMAIN`, no `assistant.env` da VPS —
nunca neste repositório, que é público. **Nada de nginx, Caddy, DNS ou TLS foi
tocado nesta etapa**, por decisão.

O que falta, antes de expor qualquer coisa:

1. **Reverse proxy** — a WebUI do Nanobot escuta em `http://127.0.0.1:8765`.
   Deve continuar ligada só ao loopback; quem fala com a internet é o proxy.
2. **TLS** — certificado válido para o domínio configurado, renovação
   automática, HTTP redirecionando para HTTPS.
3. **Autenticação obrigatória** — o Nanobot **não pode** ser exposto sem
   autenticação. Quem alcança a WebUI alcança o brain inteiro e as ferramentas
   do agente. No mínimo: autenticação no proxy, e de preferência também
   restrição por IP.
4. **Firewall** — `8765` nunca aberto para fora; só `80`/`443` no proxy.
5. **Rate limiting e logs de acesso** no proxy.

Até que os cinco existam, o acesso é local ou por túnel SSH.

## Legacy VPS cleanup

A VPS pode ter serviços de projetos anteriores. O objetivo futuro é dedicar o
domínio do assistente a este projeto — mas **limpeza é etapa humana separada**, e
nenhum script deste repositório remove nada da VPS.

Antes de remover qualquer coisa, audite e anote o que encontrar:

```bash
systemctl list-units --type=service --state=running   # services
docker ps -a && docker images                          # containers
crontab -l; ls -la /etc/cron.*                         # cron
ss -tulpn                                              # ports
ls -la /etc/nginx/sites-enabled/                       # nginx
ls -la /opt /srv /var/www                              # directories
getent passwd | awk -F: '$3>=1000'                     # users
ufw status verbose 2>/dev/null || iptables -L -n       # firewall
```

Roteiro sugerido, um item por vez:

1. inventarie tudo antes de tocar em qualquer coisa;
2. para cada item, responda: quem usa, o que quebra se parar;
3. **pare** o serviço e observe alguns dias — não remova ainda;
4. faça backup do que for específico daquele serviço;
5. só então remova, um por vez, com como reverter anotado;
6. mexa em nginx e DNS por último, e nunca junto.

Nunca remova em lote. Nunca remova o que você não conseguiu identificar.
