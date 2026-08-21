# second-brain-agent

Base portátil e independente de harness para um assistente pessoal/profissional orientado por Skills.

## O problema

Assistentes de IA costumam guardar memória, regras e procedimentos dentro de runtimes específicos, gerando lock-in.

## A proposta

Separar claramente:

- `brain` (dados e organização)
- `skills` (procedimentos)
- `data` (memória em Markdown)
- `runtime` (substituível)
- `tools` (capacidades computacionais)

Assim, o runtime só consome a estrutura; não é dono dela.

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

## Princípio

```text
NO SKILL → NO ACTION
```

Sem Skill adequada, ambígua ou insuficiente, o agente deve recusar execução.

## Estrutura

Comece por:

- `brain/INDEX.md`
- `brain/70-skills/INDEX.md`

Esses arquivos permitem descoberta progressiva sem varrer todo o filesystem.

## Portabilidade

A mesma base pode ser consumida por:

- Nanobot
- DeepSeek Harness
- outro runtime compatível
- aplicação própria

## Endpoints e secrets

Skills podem referenciar endpoints conceitualmente, por exemplo:

- `{{N8N_URL}}`
- `{{KESTRA_URL}}`

Valores reais devem vir do ambiente/runtime (`.env`, secret manager etc.). Nunca salve secrets em `brain/`.

## Obsidian e Syncthing

- `brain/` pode ser aberto como Vault do Obsidian.
- A estrutura não depende de `.obsidian/` nem de plugins proprietários.
- Em Syncthing, prefira arquivos menores para reduzir conflito.
- Se humano e agente editarem o mesmo arquivo simultaneamente, podem ocorrer conflitos de sincronização.

## Casos futuros (não implementados aqui)

- Telegram → cadastrar agenda
- Telegram → backlog
- Telegram → disparar workflow n8n
- Telegram → consultar projeto
- Telegram → organizar memória
- Telegram → consultar processo

## Bootstrap

Este repositório funciona como metodologia + template.

```bash
git clone <repo-url>
cd second-brain-agent
./scripts/bootstrap.sh /caminho/do/brain
```

## Validar estrutura

```bash
python3 scripts/validate_structure.py
python3 scripts/validate_structure.py --brain /caminho/do/brain
```
