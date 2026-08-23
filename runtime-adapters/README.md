# Runtime adapters

O harness é substituível. O brain não é.

```text
brain + skills + policies + workflow contracts   ← canônico, seu
                    │
                    ▼
             runtime adapter                     ← fino, descartável
             ┌──────┴──────┐
             ▼             ▼
          Nanobot       Hermes
```

Um runtime ativo por vez, escolhido por configuração explícita:

```env
ASSISTANT_RUNTIME=nanobot   # padrão do MVP
```

Nunca por detecção de binário instalado: configuração explícita vence, sempre.
Um binário presente por acidente não deve mudar qual runtime opera o assistente.

## O que um adapter faz

- instala o runtime;
- mapeia nossa configuração para a dele;
- aponta o runtime para o brain e para as Skills;
- configura modelo e provider;
- configura acesso owner-only quando o runtime suportar;
- valida o runtime (`doctor`).

## O que um adapter nunca faz

Conteúdo do brain · definição de Skills · regra de negócio · workflows n8n ·
billing · dados pessoais. Nada disso pertence à camada de runtime.

## Estrutura

```text
runtime-adapters/
├── README.md            (este arquivo)
├── TOOL-MAPPING.md      capacidade conceitual → tool real de cada runtime
├── nanobot/README.md    adapter padrão; reutiliza scripts/ existentes
└── hermes/              adapter alternativo
    ├── README.md
    ├── install.sh
    ├── configure.py
    └── doctor.sh
```

Scripts genéricos — `install.sh`, `update.sh`, `doctor.sh`, `healthcheck.sh`,
`backup.sh`, `restore.sh` — continuam em `scripts/` e **não são duplicados** por
adapter. Eles fazem dispatch pelo `ASSISTANT_RUNTIME`.

## Estado, logs e secrets

Cada runtime tem o seu, nunca compartilhado:

```text
/var/lib/professional-ai-assistant/runtime/nanobot/
/var/lib/professional-ai-assistant/runtime/hermes/
/var/log/professional-ai-assistant/nanobot/
/var/log/professional-ai-assistant/hermes/
```

Secrets continuam em `/etc/professional-ai-assistant/assistant.env`, fora do Git.
Quando um runtime exigir armazenamento próprio de credencial, isso é
**runtime-local secret** — documentado, nunca duplicado no repositório ou no brain.

## Memória e Skills nativas do runtime

```text
Runtime-native memory is auxiliary.
```

Hermes e outros runtimes têm memória, sessões e criação automática de Skills.
Nada disso é fonte da verdade. O canônico é `brain/`; o que o runtime gera é
**derivado ou runtime-local**, e só vira canônico por revisão humana explícita.

Sem sync bidirecional, sem merge automático, sem promoção automática.

## Adicionar um runtime novo

Só quando houver motivo real. Um adapter existe para um runtime que você vai
usar — não por hipótese. Se suportar um runtime exigir refatorar o brain ou as
Skills, o problema é o adapter, não o brain.
