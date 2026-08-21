# second-brain-agent

Base **portátil e independente de harness** para um assistente pessoal e
profissional orientado por Skills.

Este repositório é **metodologia + template + documentação + Skills reutilizáveis**.
Ele não é o repositório dos seus dados pessoais reais — esses vivem em uma
instância gerada por `scripts/bootstrap.sh`, fora daqui.

> Estado atual: apenas a fundação. Nenhum agente, canal ou integração
> (Nanobot, Telegram, n8n, Kestra) foi implementado.

## O problema

Assistentes de IA costumam guardar memória, configuração e procedimentos **dentro
do runtime**. Trocar de ferramenta significa perder ou migrar tudo: contexto,
decisões, automações, método de trabalho. Isso é lock-in.

## A proposta

Separar as camadas e deixar apenas a última descartável:

| Camada    | Onde vive              | Substituível? |
| --------- | ---------------------- | ------------- |
| `brain`   | `brain/` (Markdown)    | não — é seu   |
| `skills`  | `brain/70-skills/`     | não — é seu   |
| `data`    | `brain/60-memory/` e demais diretórios | não — é seu |
| `tools`   | nomes conceituais em `brain/00-system/runtime-contract.md` | implementação sim, contrato não |
| `runtime` | fora do repositório    | **sim, totalmente** |
| `secrets` | ambiente / secret manager (`.env`, nunca versionado) | sim — e nunca dentro de `brain/` |

As quatro camadas nunca se misturam no disco: `brain/` é versionado e portátil;
`runtime/`, `logs/`, `sessions/` e `cache/` são artefatos descartáveis e estão no
`.gitignore`; as tools existem como contrato conceitual, não como código aqui; os
secrets vivem só no ambiente.

**Princípio arquitetural central:** o harness é substituível. Se o runtime for
completamente removido, nenhuma Skill, memória, decisão ou metodologia se perde.

## Modelo conceitual

```text
User
  ↓
Channel
  ↓
Agent Runtime
  ↓
Intent Detection
  ↓
Skills Index
  ↓
Selected Skill
  ↓
Tools
  ↓
Filesystem / HTTP / External Automation
```

## Princípio operacional

```text
NO SKILL → NO ACTION
```

Sem Skill adequada — ou com Skill ambígua ou insuficiente — o agente **não
executa**. Ele explica o que falta e, no máximo, propõe criar a Skill.
As 21 regras completas estão em `brain/00-system/agent-rules.md`; a postura de
comunicação — breve e direta por padrão, sem narrar ferramentas nem raciocínio —
está em `brain/00-system/PHILOSOPHY.md`.

## Estrutura

```text
second-brain-agent/
├── README.md
├── .env.example
├── .gitignore
├── LICENSE
├── brain/
│   ├── INDEX.md                  # mapa do segundo cérebro (ponto de entrada)
│   ├── 00-system/
│   │   ├── README.md
│   │   ├── agent-rules.md        # 21 regras operacionais
│   │   ├── PHILOSOPHY.md         # comunicação breve, direta e precisa por padrão
│   │   ├── conventions.md        # nomes, datas, frontmatter, granularidade
│   │   ├── taxonomy.md           # PARA adaptado
│   │   └── runtime-contract.md   # o mínimo que um runtime deve fornecer
│   ├── 10-inbox/                 # não classificado (destino em caso de dúvida)
│   ├── 20-projects/              # objetivo definido, com conclusão possível
│   ├── 30-areas/                 # responsabilidades contínuas
│   │   └── agenda/               # compromissos (events/YYYY-MM.md) + timezone
│   ├── 40-resources/             # conhecimento reutilizável
│   │   └── automation/workflows/ # catálogo de workflows externos (INDEX.md)
│   ├── 50-people/                # contexto sobre pessoas
│   ├── 60-memory/                # profile, preferences, decisions, lessons
│   ├── 70-skills/                # INDEX.md + contrato de Skills
│   │   ├── system/organize-brain/
│   │   ├── productivity/{manage-project,backlog,agenda}/
│   │   └── automation/invoke-workflow/
│   └── 90-archive/               # encerrado / inativo
└── scripts/
    ├── bootstrap.sh              # gera uma instância operacional do brain
    └── validate_structure.py     # valida estrutura e ausência de secrets
```

Um agente novo deve começar por `brain/INDEX.md` e `brain/70-skills/INDEX.md`.
Esses dois arquivos bastam para entender a metodologia — sem varrer o filesystem.

## Skill vs Tool

- **Skill** — conhecimento operacional: *como* executar uma tarefa
  (organizar o brain, cadastrar compromisso, adicionar backlog, consultar processo).
- **Tool** — capacidade computacional: `read_file`, `write_file`, `append_file`,
  `list_files`, `search_text`, `http_request`.

Skills citam Tools por **nome conceitual**. O mapeamento para a implementação real
é responsabilidade do runtime. Ver `brain/70-skills/README.md`.

## Como usar

```bash
git clone <repo-url>
cd second-brain-agent

# gera uma instância operacional do brain, fora deste repositório
./scripts/bootstrap.sh /caminho/do/brain

# valida
python3 scripts/validate_structure.py --brain /caminho/do/brain
```

`bootstrap.sh` nunca sobrescreve arquivos existentes: o que já estiver no destino
é preservado e reportado como `skip`. Use `--dry-run` para simular.

## Endpoints e secrets

Skills referenciam endpoints e credenciais apenas por nome conceitual:

```text
{{N8N_URL}}
{{KESTRA_URL}}
```

Os valores reais vêm do runtime ou do ambiente (`.env`, secret manager). Copie
`.env.example` para `.env` — que é ignorado pelo Git. **Nenhum secret pode entrar
em `brain/`**; `validate_structure.py` procura por padrões evidentes de credencial.

## Obsidian

`brain/` pode ser aberto diretamente como Vault, mas não depende disso:

- Markdown puro; nada crítico depende de plugin.
- Links relativos; Wikilinks só quando não quebrarem a portabilidade.
- Plugins podem melhorar visualização, nunca definir a estrutura dos dados.
- `.obsidian/` não é necessário para interpretar o conteúdo e está no `.gitignore`.

## Syncthing

`brain/` foi pensado para sincronizar entre VPS e computador pessoal. Por isso:

- prefira arquivos menores a arquivos monolíticos;
- prefira criar notas novas e fazer append controlado a reescrever;
- divida por projeto, assunto ou data quando fizer sentido.

**Risco conhecido:** se humano e agente editarem o mesmo arquivo ao mesmo tempo em
máquinas diferentes, o Syncthing gera arquivos `*.sync-conflict-*` e uma das
versões precisa ser reconciliada à mão. Granularidade fina reduz a superfície do
problema; não a elimina. Evite deixar o agente reescrevendo arquivos grandes
enquanto você edita o mesmo vault.

## Portabilidade

A mesma base pode ser consumida por Nanobot, DeepSeek Harness, outro runtime
compatível ou uma aplicação própria. Para isso, o runtime só precisa cumprir
`brain/00-system/runtime-contract.md`: expor as tools conceituais, resolver as
variáveis `{{...}}` e respeitar `NO SKILL → NO ACTION`.

**Teste de sucesso:** apague o runtime por completo. Todo o conteúdo de `brain/`
continua legível, editável e reutilizável com um editor de texto qualquer.

## Casos futuros (não implementados)

```text
Telegram → cadastrar agenda
Telegram → backlog
Telegram → disparar workflow n8n
Telegram → consultar projeto
Telegram → organizar memória
Telegram → consultar processo
```

## Fora de escopo, por decisão

Banco de dados, vector database, embeddings, RAG, Redis, filas, Kubernetes,
frameworks de agentes e dependências grandes. Filesystem + Markdown + dois scripts
de biblioteca padrão são suficientes para inaugurar a metodologia.

## Próximos passos

Nada disso está implementado, e cada item é um PR próprio:

1. runtime que cumpra `brain/00-system/runtime-contract.md` (Nanobot como primeiro candidato);
2. canal de entrada (Telegram ou equivalente);
3. workflows reais registrados em `brain/40-resources/automation/workflows/`;
4. Skills adicionais conforme a necessidade aparecer — nunca antes.

## Licença

MIT — ver `LICENSE`.
