# Operação deste repositório e da VPS

Regras para qualquer sessão de Claude Code que opere este projeto. Elas valem
para **mim, o assistente que executa** — não para o agente que roda dentro do
brain. As regras do agente estão em `brain/00-system/agent-rules.md`.

## Papel

Eu faço deploy, manutenção e evolução dos agentes na VPS (Hostinger). O usuário
decide; eu executo, e paro quando a ação tem efeito colateral não confirmado.

## Acesso

O acesso SSH **não está concedido** até o usuário dizer explicitamente nesta
sessão que está. Enquanto isso:

- não assumir credencial disponível;
- não tentar conectar;
- preparar tudo localmente e deixar pronto para executar.

## Antes de qualquer ação com efeito colateral na VPS

1. resumir o que será feito, em uma linha por comando;
2. **aguardar confirmação explícita**;
3. só então executar.

Pedido genérico — "arruma a VPS", "atualiza aí", "faz o deploy" — **não** é
confirmação para comandos destrutivos. É autorização para propor um plano.

## Nunca executar sem confirmação explícita nesta sessão

```text
docker system prune --volumes
docker volume rm <qualquer>
rm -rf <qualquer caminho>          — especialmente /opt/brain
qualquer escrita destrutiva em /opt/brain/memory
```

`/opt/brain/memory` é **dado persistente não recriável a partir de código**.
Container morre, imagem se reconstrói, memória não. Tratar com o cuidado de
banco de dados de produção sem réplica.

Em caso de dúvida sobre se um comando é destrutivo: ele é. Pergunte.

## Idempotência

Preferir comandos que podem rodar duas vezes sem quebrar nada. Antes de
escrever um passo novo, responder: rodar isso de novo faz mal? Se fizer,
reescrever.

Os scripts do repositório já seguem isso (`--dry-run` em tudo que altera
estado). Use `--dry-run` primeiro, sempre.

## Changelog

Toda mudança relevante de infraestrutura vai para `/opt/files/changelog.md`,
**na própria VPS**, com data e o que mudou:

```bash
/opt/files/changelog.sh "subiu runtime nanobot v0.4.2; sem mudança no brain"
```

O script está em `scripts/changelog.sh` neste repositório e é copiado para a VPS
no deploy. Registrar depois da mudança dar certo, não antes.

## Layout da VPS

Há **dois** perfis de deploy, e confundi-los é a origem mais provável de erro
operacional. O que decide qual está em uso é o que existe na máquina, não a
memória de quem opera.

**Nativo — padrão do MVP.** É o que `scripts/install.sh` monta, e os caminhos
são os defaults de `scripts/lib/common.sh`:

```text
/opt/professional-ai-assistant/repo/     checkout controlado     (descartável)
/srv/professional-ai-assistant/brain/    dados canônicos         (nunca apagar)
/var/lib/professional-ai-assistant/      runtime/ e data/        (descartável)
/etc/professional-ai-assistant/          assistant.env, chmod 600
/var/log/professional-ai-assistant/      logs
/var/backups/professional-ai-assistant/  backups
```

**Docker — alternativa.** Descrito em `deploy/`, com o brain em `/opt/brain` e
o compose em `/opt/runtime`. Não é o caminho do primeiro MVP.

Antes de qualquer comando que dependa de caminho, confirme o perfil:

```bash
test -d /srv/professional-ai-assistant/brain && echo nativo
test -d /opt/brain && echo docker
```

O diretório do brain — qualquer que seja o perfil — é o único que não se
reconstrói a partir do Git.

Regra de dependência, em uma direção só:

```text
runtime  ──referencia──►  brain      (volume mount)
brain    ──nunca──────►  runtime
```

Framework troca ou morre; o brain persiste. Se algum dia o brain precisar saber
qual runtime está rodando, o acoplamento voltou — corrija o brain, não o runtime.

## Trocar de agente

1. editar `image:` em `/opt/runtime/docker-compose.yml`;
2. **verificar se `brain/configs` precisa conversão de schema** — memória e
   configuração não migram sozinhas entre formatos diferentes; isso é trabalho
   manual ou script, nunca plug-and-play;
3. `docker compose down && docker compose up -d`;
4. `doctor` e changelog.

O passo 2 é o que costuma ser subestimado. Antes dele: backup.

## Domínio

O domínio do assistente (`ASSISTANT_DOMAIN`, no `assistant.env`) já aponta
para a VPS — DNS e subdomínio configurados.
Ainda **sem** reverse proxy, TLS ou autenticação — ver
`docs/OPERATIONS.md#domínio-do-assistente--ainda-não-configurado`. Nada é
exposto publicamente antes disso.

## Repositório

`main` é a linha de trabalho. Alterações vão por PR, com a suíte local passando:

```bash
./tests/run-local-tests.sh
python3 tests/validate_cases.py
python3 scripts/validate_structure.py
```

Nunca commitar identidade, domínio privado, token ou endpoint real — o
repositório é público, e há teste que falha se isso acontecer.
