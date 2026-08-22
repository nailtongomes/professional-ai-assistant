# Adapter: Hermes Agent

Runtime **alternativo**, não o padrão. Ativado por `ASSISTANT_RUNTIME=hermes`.

Nada aqui foi executado contra um Hermes instalado: os fatos abaixo vieram da
documentação e do código-fonte públicos, e cada um está marcado como confirmado
ou como gap.

## Fatos confirmados

| Item | Valor |
| ---- | ----- |
| instalação | `curl -fsSL https://hermes-agent.nousresearch.com/install.sh \| bash` |
| home | `~/.hermes` (Linux/macOS); env `HERMES_HOME` |
| Skills | `~/.hermes/skills/`, compatíveis com o padrão `agentskills.io` |
| template em Skill | `${HERMES_SKILL_DIR}` e `${HERMES_SESSION_ID}` são expandidos no `SKILL.md` |
| contexto/memória | `SOUL.md` (persona), `MEMORY.md`, `USER.md`, `AGENTS.md` |
| gateway | `hermes gateway setup`, `hermes gateway start` |
| autorização | `dm_policy` ∈ `open` \| `allowlist` \| `disabled` \| `pairing`; `allow_from` / `dm_allow_from`; env `<PLATFORM>_DM_POLICY` e `<PLATFORM>_ALLOW_FROM` |
| formato da allowlist | lista YAML **ou** string separada por vírgula |
| modelo/provider | `hermes model`; `hermes setup --portal`; providers configuráveis |
| tools | `hermes tools` (40+ tools) |
| update | `hermes update` |
| diagnóstico | `hermes doctor` |
| Skills automáticas | sim — criação autônoma após tarefas complexas, e auto-melhoria |
| migração OpenClaw | `hermes claw migrate` |

Política de segurança declarada pelo projeto (`SECURITY.md`): *"An allowlist is
required for every enabled network-exposed adapter... Code paths that fail open
when no allowlist is configured are code bugs."* Ou seja, o comportamento
desejado — allowlist obrigatória — é posição oficial do runtime, não invenção
nossa.

## Gaps — não confirmados, e por isso não assumidos

1. **Nome exato da env var de allowlist do Telegram.** O padrão
   `<PLATFORM>_DM_POLICY` / `<PLATFORM>_ALLOW_FROM` está confirmado no código
   (visto para `WHATSAPP_`, `CLOUD_`, `WEIXIN_`), mas não achei a constante
   literal do Telegram nesta leitura. O `configure.py` grava a chave no YAML do
   gateway e **imprime** a linha de env equivalente para conferência manual, em
   vez de chutar um nome.
2. **Default de `dm_policy` quando não configurado.** Não confirmado. Por isso o
   adapter **sempre** grava `dm_policy: allowlist` explicitamente — nunca conta
   com o default.
3. **Apontar as Skills para um diretório externo.** `HERMES_SKILL_DIR` é um token
   de template dentro do `SKILL.md`, **não** um override do diretório de busca.
   Não encontrei configuração suportada para ler Skills fora de `~/.hermes/skills`.
   Por isso o mapeamento usa **symlink** (opção 2 da nossa ordem de preferência),
   não cópia.
4. **Paridade de tools por nome.** Confirmado que existem 40+ tools e que são
   configuráveis; a correspondência nome a nome com as capacidades conceituais
   não foi verificada — ver `../TOOL-MAPPING.md`.

Nenhum gap virou workaround. Cada um está aqui para ser fechado com o runtime na
mão.

## Checklist de paridade

| Capacidade | Nanobot | Hermes | Status |
| ---------- | ------- | ------ | ------ |
| filesystem read | sim | sim | compatível |
| filesystem write/append | sim | sim | compatível |
| HTTP request | sim | sim | compatível |
| carregamento de Skills | sim | sim (`agentskills.io`) | compatível |
| runtime persistente | sim (`gateway --background`) | sim (`gateway start`) | compatível |
| gateway de mensagens | sim | sim | compatível |
| restrição ao owner | `allowFrom` | `dm_policy: allowlist` + `allow_from` | compatível |
| configuração de provider | via config | `hermes model` | compatível |
| diagnóstico próprio | não | `hermes doctor` | Hermes tem mais |
| memória nativa | — | `MEMORY.md`, `USER.md`, sessões | **isolada** (auxiliar) |
| criação automática de Skills | — | sim | **isolada** (proposta) |

"Isolada" significa: existe no runtime, não entra no brain sem revisão humana.

## Uso

```bash
# no assistant.env da VPS
ASSISTANT_RUNTIME=hermes
OWNER_TELEGRAM_ID=<id>

runtime-adapters/hermes/install.sh --dry-run
runtime-adapters/hermes/install.sh
python3 runtime-adapters/hermes/configure.py --dry-run
python3 runtime-adapters/hermes/configure.py
runtime-adapters/hermes/doctor.sh
```

O `scripts/install.sh` e o `scripts/doctor.sh` delegam para cá quando
`ASSISTANT_RUNTIME=hermes` — você não precisa chamar direto.

## Arquivos derivados

O `configure.py` gera, a partir do brain:

```text
brain/00-system/PHILOSOPHY.md   →   ~/.hermes/SOUL.md
brain/70-skills/                →   ~/.hermes/skills/pai-<nome>  (symlink)
```

```text
PHILOSOPHY.md = source
SOUL.md       = generated runtime artifact
```

O `SOUL.md` carrega um cabeçalho dizendo que é gerado e não deve ser editado.
Apagá-lo não perde nada: rode o `configure.py` de novo.

## Memória e Skills geradas pelo Hermes

Ficam onde o Hermes as põe, sob `~/.hermes` — que é `local-managed`. Não são
sincronizadas para `brain/60-memory/` nem para `brain/70-skills/`.

Skills geradas pelo runtime só viram canônicas por revisão humana: copie para
`brain/70-skills/<categoria>/<nome>/SKILL.md`, registre no `INDEX.md` e
acrescente ao `config/managed-paths.txt` se for oficial. Não há promoção
automática, e não deve haver.
