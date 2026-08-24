# Portabilidade de runtime

O harness é substituível. Este documento diz o que sobrevive à troca e o que não.

## Canônico — seu, nunca migra

```text
brain/               conhecimento, memória, projetos, agenda, pessoas
brain/70-skills/     procedimentos
brain/00-system/     regras, filosofia, convenções, ownership
brain/40-resources/  catálogo e contrato dos workflows
config/              manifesto do que o template gerencia
```

Markdown puro, legível sem agente nenhum.

## Substituível — do runtime, descartável

```text
runtime (Nanobot, Hermes, outro)
memória nativa e sessões
config nativo do runtime
logs nativos
Skills geradas pelo runtime
arquivos derivados (ex.: SOUL.md)
```

Apagar tudo isso e reinstalar não perde conhecimento. **Se perder, algo canônico
vazou para a camada errada** — e isso é o defeito a corrigir, não um custo a
aceitar.

## Trocar de runtime

Conceitual. Nada aqui foi executado.

```text
nanobot
   │ parar o runtime atual
   ▼
backup            (scripts/backup.sh — obrigatório, política vigente)
   │
   ▼
ASSISTANT_RUNTIME=hermes        no assistant.env
   │
   ▼
configurar adapter              runtime-adapters/hermes/{install.sh,configure.py}
   │
   ▼
doctor                          scripts/doctor.sh
   │
   ▼
benchmark                       benchmarks/
```

Voltar é o mesmo caminho com `ASSISTANT_RUNTIME=nanobot`. **Não há migração de
dados em nenhuma direção**: os dados nunca estiveram dentro do runtime.

Um runtime ativo por vez. Sem execução simultânea, sem fallback automático, sem
balanceamento — cada um desses transforma um problema de configuração em um
problema distribuído.

## Migração assistida do próprio runtime

O Hermes oferece `hermes claw migrate`, que importa personas, memórias, Skills,
allowlists e chaves de outro assistente.

**Nossa portabilidade não depende disso, e não deve.** Aquele mecanismo existe
para quem guardou os dados dentro do harness antigo; nós nunca guardamos. Se um
dia usarmos, será por conveniência pontual — nunca como pilar da arquitetura.

## Runtime não entra no produto

A substituibilidade tem uma consequência comercial, registrada em
`PRODUCT-VISION.md`: o produto chama-se Professional AI Assistant, e o nome do
runtime não aparece na promessa nem no contrato com o cliente. Nanobot continua
o padrão; Hermes continua suportado; um terceiro pode entrar.

Isso também é o que torna honesta a comparação entre candidatos por custo,
tokens, latência, estabilidade, manutenção e qualidade de tool calling — medição
que não vale nada se um deles já estiver entranhado no produto.

O mesmo vale para o modelo: o provedor de LLM é configuração da instância, nunca
identidade do produto.

## Teste de portabilidade

Três perguntas, todas com resposta obrigatória "sim":

1. Trocar de runtime exige alterar configuração e adapter — **não** reescrever
   brain ou Skills?
2. Voltar ao runtime anterior dispensa migração dos dados canônicos?
3. Toda memória, Skill ou estado criado só pelo runtime é tratado como derivado
   ou local — nunca como fonte única?

Se alguma virar "não", o acoplamento voltou. Corrija antes de seguir.

## Estado separado por runtime

```text
/var/lib/professional-ai-assistant/runtime/nanobot/
/var/lib/professional-ai-assistant/runtime/hermes/
/var/log/professional-ai-assistant/nanobot/
/var/log/professional-ai-assistant/hermes/
```

Nunca misturados: estado compartilhado entre runtimes é como um sobrescreve o
outro em silêncio.
