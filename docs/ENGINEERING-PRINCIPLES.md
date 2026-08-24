# Engineering Principles for a Solo-Maintained Assistant

Este projeto é mantido por **uma pessoa**. Isso não é uma limitação temporária a
ser superada com mais ferramentas — é a restrição de projeto que decide o que
pode entrar.

Toda abstração nova precisa responder quatro perguntas antes de existir:

1. que problema concreto resolve?
2. quanto custa manter?
3. qual o impacto operacional quando quebrar às duas da manhã?
4. qual alternativa mais simples foi considerada, e por que não serve?

Se uma solução simples resolve 80–90% do problema, ela vence. Os 10% restantes
raramente pagam o custo de operar a solução completa sozinho.

## As dez regras

**1. Sem banco de dados antes de necessidade comprovada.** Markdown em
filesystem é legível, versionável, sincronizável e não tem processo para cair,
migração para rodar nem backup próprio para esquecer.

**2. Sem fila própria enquanto n8n e Kestra resolverem execução assíncrona.**
Eles já têm retry, agendamento e histórico. Uma fila nossa seria mais um serviço
para monitorar e a mesma funcionalidade.

**3. Sem serviço novo se um script ou arquivo resolve.** Serviço tem ciclo de
vida, porta, log, atualização e modo de falha. Arquivo tem conteúdo.

**4. Sem abstração antes de dois usos reais.** Um uso é um caso. Dois são um
padrão. Generalizar a partir de um caso produz a abstração errada e o custo de
desfazê-la.

**5. Sem responsabilidade duplicada** entre agente, n8n, Kestra e scripts. Duas
camadas fazendo a mesma coisa significam dois lugares para corrigir o mesmo bug
e um para esquecer.

**6. Cada camada tem um papel só:**

```text
Agent    decide e roteia
n8n      integra
Kestra   orquestra execução pesada
Script   executa tarefa determinística
Brain    persiste conhecimento
```

**7. LLM não executa lógica que pode ser determinística.** Montar payload
simples é do agente. Retry, backoff e agendamento são do workflow engine.
Execução de RPA é do script. Modelo é caro, não reproduz e não deve ser o lugar
onde a lógica mora.

**8. Operação diagnosticável com `doctor.sh`, logs e `task_id`.** Se descobrir
por que algo falhou exige abrir cinco sistemas, o desenho está errado — não
falta ferramenta de observabilidade.

**9. Toda automação nova responde seis perguntas:** que problema resolve, qual
Skill chama, qual workflow recebe, qual script executa, como falha, e como
diagnosticar. Sem as seis respostas, ela não entra.

**10. Se a manutenção mensal começar a exigir conhecimento demais, simplifique
antes de adicionar ferramenta.** O sintoma de "preciso de uma ferramenta nova"
costuma ser excesso de peças, não falta de uma.

## Mapa de responsabilidades

```text
User
  │
Agent          intent, contexto, roteamento, resposta
  │
Skill          procedimento e contrato
  │
HTTP
  │
n8n            integração e coordenação leve
  │
Kestra         execução longa, retry, agendamento
  │
Container/Script   trabalho determinístico
```

Fora do fluxo de execução, mas parte do sistema:

| Peça | Responsabilidade | O que **não** faz |
| ---- | ---------------- | ----------------- |
| Brain | conhecimento persistente | executar |
| Git | metodologia versionada | guardar dados pessoais |
| Syncthing | replicação entre máquinas | backup |
| Backup | recuperação de desastre | disponibilidade |

Não misture. Syncthing replica o erro; Git não guarda o seu brain; backup não
está online quando você precisa do arquivo agora.

## Comercialização não suspende estas regras

A visão de produto (`PRODUCT-VISION.md`) prevê distribuir esta arquitetura a
clientes externos. Isso não afrouxa nada acima. A pergunta que filtra qualquer
componente que só exista para vender é:

> Precisamos disso para o **primeiro** cliente?

Se não, adiar. Um mantenedor só não sustenta control plane, billing próprio,
IAM próprio, marketplace ou provisionamento massivo — e nenhum deles é
necessário para o cliente número um.

## Não implementar

```text
Prometheus   Grafana   ELK      Sentry        OpenTelemetry
PostgreSQL   Redis     RabbitMQ Kafka
Kubernetes   Terraform Ansible  Vault
```

Nenhum está proibido para sempre. Todos estão proibidos **até existir dor
operacional real e documentada** que os justifique. Cada um é uma boa
ferramenta que custa tempo de operação — tempo que, aqui, sai do único operador.

Quando a dor aparecer, escreva-a em `60-memory/decisions.md` antes de escolher a
ferramenta. Dor documentada é requisito; dor imaginada é hobby.
