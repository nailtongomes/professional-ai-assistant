# Operação da VPS

Como eu — o assistente que executa — opero a VPS. As regras curtas estão em
`CLAUDE.md`, na raiz, para serem carregadas automaticamente por qualquer sessão.
Aqui fica o detalhe.

## Estado do acesso

**SSH ainda não concedido.** Até o usuário confirmar explicitamente numa sessão,
nada é executado na VPS: o trabalho é preparar e deixar pronto.

Quando o acesso vier, ele não muda a postura abaixo — muda só onde os comandos
rodam.

## Postura

```text
propor  →  confirmar  →  executar  →  verificar  →  registrar
```

Antes de qualquer ação com efeito colateral: resumo do que será feito, uma linha
por comando, e espera pela confirmação.

**"Arruma a VPS" não é confirmação.** É autorização para propor um plano. Pedido
genérico autoriza diagnóstico e proposta, nunca destruição.

## Comandos que exigem confirmação explícita

| Comando | Por quê |
| ------- | ------- |
| `docker system prune --volumes` | apaga volumes de qualquer projeto na máquina, não só o nosso |
| `docker volume rm <v>` | dado que só o Docker sabe onde fica |
| `rm -rf <path>` | especialmente `/opt/brain` |
| escrita destrutiva em `/opt/brain/memory` | **não recriável a partir de código** |

Container morre e volta. Imagem se reconstrói. Compose se reescreve em cinco
minutos. **Memória, não**: ela é o único ativo da máquina sem origem no Git.

Regra prática: se a dúvida é "isso é destrutivo?", a resposta é sim — pergunte.

## Diagnóstico primeiro

Todo comando somente leitura é livre e deve vir antes de qualquer proposta:

```bash
sudo ./scripts/doctor.sh --verbose
docker compose ps
docker compose logs --tail 50
df -h; free -m
/opt/files/changelog.sh --list
```

O `doctor` é o ponto de partida único — foi feito para isso.

## Idempotência

Preferir comandos que rodam duas vezes sem quebrar. Antes de propor um passo:
rodar de novo faz mal? Se fizer, reescrever.

Os scripts do repositório aceitam `--dry-run` em tudo que altera estado. Use
primeiro, sempre — inclusive quando "é óbvio que vai funcionar".

## Changelog

```bash
/opt/files/changelog.sh "o que mudou"
/opt/files/changelog.sh --list
```

Append-only, em `/opt/files/changelog.md`, na própria VPS — não no Git, porque
descreve **aquela máquina**. Registrar depois de confirmar que deu certo.

Entrada boa diz o que mudou e o que **não** mudou:

```text
- 2026-08-23T14:02:11Z — claude — runtime nanobot 0.4.2 no ar; brain intocado
- 2026-08-23T15:40:03Z — claude — nanobot → hermes; brain/configs convertido por convert.py
```

## Trocar de agente

```bash
sudo ./scripts/backup.sh                     # 1. obrigatório
                                             # 2. conversão de schema — ver abaixo
sudo nano /opt/runtime/docker-compose.yml    # 3. image:
cd /opt/runtime && docker compose down && docker compose up -d
sudo ./scripts/doctor.sh                     # 4. verificar
/opt/files/changelog.sh "..."                # 5. registrar
```

O passo 2 é o que morde: **memória e configuração não migram sozinhas entre
frameworks**. Formatos diferentes exigem conversão manual ou script, e nenhum
`docker compose up` faz isso por você. Antes de trocar, responda: o novo runtime
lê o formato atual? Se não, qual script converte, e ele foi testado numa cópia?

O `brain/` em si não muda. Ele nunca foi do runtime — é o ponto inteiro da
arquitetura.

## Limites do meu papel

Faço: diagnóstico, deploy, atualização, backup, troca de runtime, registro.

Não faço sem pedido explícito: apagar dado, expor porta, mexer em DNS, alterar
nginx de outros projetos, instalar o que não foi pedido, "limpar" o que não
identifiquei.

A limpeza da VPS legada continua sendo etapa humana separada — roteiro de
auditoria em `docs/OPERATIONS.md#legacy-vps-cleanup`.

## Domínio

O domínio configurado em `ASSISTANT_DOMAIN` aponta para a VPS. Ainda **sem**
reverse proxy, TLS ou
autenticação, e o compose não publica porta. Nada é exposto até os cinco
pré-requisitos de `docs/OPERATIONS.md` existirem.
