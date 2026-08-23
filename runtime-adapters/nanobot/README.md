# Adapter: Nanobot

Runtime **padrão** do MVP. `ASSISTANT_RUNTIME=nanobot`.

Este adapter é só documentação: a implementação já vive nos scripts genéricos, e
duplicá-la aqui criaria duas verdades.

| Responsabilidade | Onde |
| ---------------- | ---- |
| instalação | `scripts/install.sh` |
| atualização | `scripts/update.sh` |
| acesso owner-only | `scripts/configure-nanobot.sh` |
| diagnóstico | `scripts/doctor.sh`, `scripts/healthcheck.sh` |
| inspeção de acesso | `scripts/lib/check_access.py` |

## Fatos usados pelos scripts

- config em `~/.nanobot/config.json` do usuário de serviço;
- `allowFrom` por canal: lista de IDs; `["*"]` libera todos; omitir ativa pairing;
- `${VAR}` interpolado em qualquer string do config, na inicialização;
- execução persistente própria: `nanobot gateway --background`.

Detalhes e o modelo de acesso: `docs/OPERATIONS.md`.

## Estado

```text
/var/lib/professional-ai-assistant/runtime/nanobot/
```

Nunca compartilhado com outro runtime.
