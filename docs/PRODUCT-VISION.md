---
type: product-vision
status: active
created: 2026-08-24
updated: 2026-08-24
---

# Visão de produto

Este documento existe para uma finalidade específica: impedir que decisões
técnicas tomadas hoje, para um usuário só, fechem portas que precisarão estar
abertas amanhã. Não é um roadmap, não autoriza implementação e não descreve
nada que exista. Descreve **fronteiras** — e fronteira é barata de manter
enquanto ninguém a atravessou.

Nada aqui é compromisso comercial. É restrição de projeto.

---

## 1. Duas fases deliberadas

### Fase 1 — Professional AI Assistant

O primeiro usuário é o próprio mantenedor: advogado, desenvolvedor e provedor
de automações jurídicas ao mesmo tempo. O agente ajuda no trabalho diário —
agenda, backlog, projetos, memória, pesquisa, organização, disparo de
workflows, automações jurídicas, tarefas técnicas.

Esse uso não é ensaio. É simultaneamente dogfooding, laboratório, ambiente de
validação e banco de testes para comparar Nanobot e Hermes sob carga real.

**Não otimizar para clientes externos antes de o uso real validar o que existe.**
Toda generalização feita antes do primeiro usuário real generaliza uma suposição.

### Fase 2 — Legal Professional Assistant

Validada internamente, a mesma arquitetura pode ser distribuída a advogados,
escritórios e departamentos jurídicos. Esses usuários não têm perfil técnico, e
a experiência precisa esconder integralmente:

```text
containers · Kestra · n8n · payloads · webhooks
LLM providers · filesystem · runtime internals
```

O advogado conversa com o agente. O agente executa conforme as Skills
habilitadas. O que está por baixo é problema de quem opera, não de quem usa.

---

## 2. Tese do produto

> Entregar um profissional digital especializado em rotinas jurídicas — não
> acesso a mais um chatbot.

A distinção não é retórica. Um chatbot se vende por conversa; um profissional
digital se vende por trabalho concluído. A segunda promessa é mais difícil e é
a única que justifica instância dedicada.

Composição conceitual da entrega:

```text
ambiente dedicado
+ runtime (Nanobot ou Hermes)
+ brain profissional
+ Skills jurídicas
+ créditos de IA
+ acesso às automações jurídicas externas
```

---

## 3. Single-tenant primeiro

**Uma instalação = um cliente.** Regra obrigatória.

```text
Cliente A          Cliente B
   │                  │
ambiente A         ambiente B
   │                  │
runtime A          runtime B
   │                  │
 brain A            brain B
```

Não construir multi-tenancy dentro do brain ou do runtime. Os motivos são
isolamento, privacidade, depurabilidade, backup, restauração, personalização,
raio de dano menor e simplicidade operacional — mas o motivo que decide é este:
multi-tenancy é reversível para dentro, não para fora. Começar isolado e juntar
depois é uma migração; começar junto e separar depois é uma reescrita, feita
sob pressão de um incidente de vazamento entre clientes.

Um backend de automação compartilhado pode ser multi-tenant um dia. Isso é
responsabilidade dele, não deste repositório.

---

## 4. Fronteira entre instância e backend

| Instância do cliente | Backend externo de automações |
| --- | --- |
| conversa, contexto, brain | RPAs, consultas judiciais |
| memória, agenda, projetos | cópias processuais, pesquisas |
| Skills, decisão de intenção | execuções pesadas, retries |
| roteamento, experiência | Kestra, containers, workers |

```text
Advogado → Agente → Skill → contrato HTTP → Automation Gateway
                                              → n8n → Kestra → RPA/API
```

O agente não conhece a infraestrutura interna do backend, e não deve passar a
conhecer por conveniência de depuração.

---

## 5. Automações como serviço

Uma Skill jurídica comercializável é **cliente de um serviço**, não implementação
dele.

`process-query` ensina: quando usar, que dados coletar, que contrato chamar, que
payload enviar, que resposta esperar, como comunicar o resultado.

`process-query` **não** ensina: como fazer crawling do PJe, como executar
Selenium, credenciais do backend, qual container roda, qual flow do Kestra
existe.

Isso protege propriedade intelectual e reduz acoplamento — na prática, permite
reescrever a automação inteira sem tocar em uma linha de Skill.

---

## 6. Créditos de IA ≠ créditos de automação

São dois custos com naturezas diferentes e não devem compartilhar unidade.

| | Cobre | Varia com |
| --- | --- | --- |
| **AI credits** | LLM, tokens, provider, reasoning | verbosidade, modelo, contexto |
| **Automation credits** | consulta processual, cópia integral, pesquisa por CPF/CNPJ/OAB | execução, tempo de RPA, terceiros |

Nada de cobrança é implementado agora. A única exigência é negativa: **não criar
arquitetura que assuma que os dois são a mesma unidade.** Uma conversa longa e
uma consulta processual custam coisas diferentes por razões diferentes; fundi-las
em um contador só é fácil hoje e caro de desfazer depois.

---

## 7. Três catálogos de Skills

Classificação conceitual. A árvore de diretórios permanece como está.

| Catálogo | O que é | Exemplos |
| --- | --- | --- |
| **Core** | genérico, distribuível a qualquer instância | `agenda`, `backlog`, `manage-project`, `organize-brain` |
| **Legal Service** | consome serviço jurídico externo por contrato | `process-query`, `person-search`, `send-email` |
| **Owner/Developer** | específico do mantenedor; nunca distribuído | administração, infraestrutura, backend, operações internas |

A distinção que importa é a terceira: uma Skill de operação interna não pode
vazar para a instalação de um cliente. Hoje nenhuma existe no repositório — e
esse é o momento certo de registrar a regra, antes que a primeira seja escrita.

---

## 8. Portabilidade: Skill não conhece o dono

Uma Skill comercial não depende da identidade do mantenedor.

| Evitar | Preferir |
| --- | --- |
| "meu n8n", "meu servidor", "minha API" | `automation backend`, `configured endpoint` |
| nome da empresa, nome do mantenedor | `workflow contract`, `runtime environment` |

A configuração privada chega à instância no provisionamento, nunca pelo Git.

---

## 9. Personalização e isolamento

Cada cliente pode ter brain próprio, perfil derivado, dados, agenda, projetos,
Skills habilitadas, modelo escolhido e limites próprios.

Memória nunca é compartilhada entre clientes. O template público nunca contém
dado de cliente algum.

---

## 10. Template canônico, sem fork

Este repositório é o **canonical distribution template**. Uma instalação nova
deve conceitualmente rodar:

```text
clone → configure → install → bootstrap
      → select runtime → configure provider
      → configure owner → enable skills → doctor
```

O que **não** deve existir:

```text
branch cliente-a · branch cliente-b · branch cliente-c
```

A regra em uma linha: **configuração pertence à instância; produto pertence ao
Git.** Um branch por cliente transforma cada correção de bug em N merges e é o
caminho mais curto para o produto parar de existir como produto.

---

## 11. Dois modos comerciais possíveis

**Managed Agent** — o cliente recebe instância dedicada com runtime, brain,
Skills, IA, automações, updates, backup e suporte. Produto completo.

**Automation Service** — o cliente que não quer administrar agente compra apenas
execução pronta, por integração simples com o backend.

O backend precisa atender aos dois. Consequência direta e obrigatória:
**as automações jurídicas não podem acoplar-se ao Nanobot nem ao Hermes.**

---

## 12. Runtime é detalhe de implementação

```text
Nanobot  ou  Hermes  ou  harness futuro
```

O produto chama-se Professional AI Assistant. O runtime não aparece no nome, na
promessa nem no contrato com o cliente. Além de liberdade de troca, isso permite
comparar candidatos por custo, tokens, latência, estabilidade, manutenção e
qualidade de tool calling — comparação que só é honesta se nenhum deles estiver
entranhado no produto.

Nanobot permanece o runtime padrão.

---

## 13. Modelo também é substituível

```text
Professional Agent → configured model provider
```

Não se vende "um bot GPT". Vende-se um profissional digital cujo provedor é
configuração, trocável conforme preço, qualidade, privacidade, latência e
janela de contexto.

---

## 14. Dado mínimo necessário

O brain do cliente é privado da instância. O backend de automação recebe
**apenas o que a execução exige**.

```json
{ "numero_processo": "0000000-00.0000.0.00.0000" }
```

Não enviar o brain. Não enviar a memória. Não enviar arquivos desnecessários.
A Skill monta o payload mínimo — e é ela, não o backend, que responde por isso.

Regra operacional em `brain/40-resources/automation/WORKFLOW-CONTRACT.md`.

---

## 15. Quatro fronteiras de conhecimento

| Fronteira | Conteúdo | Onde vive |
| --- | --- | --- |
| **Public template** | metodologia genérica | este repositório |
| **Instance brain** | dados do profissional ou escritório | instância, nunca no Git |
| **Skill** | procedimento | repositório, sem dado e sem segredo |
| **Automation backend** | implementação especializada | fora, opaco para o agente |

Não misturar sem necessidade explícita. Quase todo incidente de vazamento
começa como um atalho entre duas dessas caixas.

---

## 16. Operação por uma pessoa

Os princípios de `ENGINEERING-PRINCIPLES.md` continuam valendo, e a
comercialização não os suspende. Antes de adicionar qualquer componente que só
exista para vender:

> **Precisamos disso para o primeiro cliente?**

Se não: adiar. Não implementar antecipadamente Kubernetes, control plane,
central multi-tenant, billing próprio, IAM próprio, marketplace,
provisionamento massivo ou telemetria pesada.

---

## 17. Caminho de evolução

| Stage | Estado | Situação |
| --- | --- | --- |
| 0 | Template + testes | **feito** |
| 1 | Dogfooding do mantenedor | **atual** |
| 2 | Uso pessoal estável em produção | próximo |
| 3 | Primeiro advogado externo (piloto) | futuro |
| 4 | Instalação repetível | futuro |
| 5 | Oferta comercial gerenciada | futuro |
| 6 | Oferta somente de automação | futuro |
| 7 | Escala | só quando a demanda provar a necessidade |

Os stages futuros não são implementados. Estão aqui para que ninguém os
implemente por acidente.

---

## 18. O primeiro cliente é o teste da arquitetura

O primeiro cliente externo deve ser provisionado com o **mesmo** repositório,
scripts, modelo de brain e Skills core. Mudando apenas:

```text
.env · profile · owner identity · enabled skills
provider/model · configuração comercial
```

Se exigir fork ou alteração manual extensa, isso não é imprevisto: é **dívida
arquitetural**, e deve ser registrada como tal em vez de contornada no caso
concreto. O primeiro provisionamento é a única medição honesta de quão
distribuível o template realmente é.

---

## Critério de leitura

Quem chega ao projeto deve entender, sem esforço:

Hoje construímos um agente profissional para o próprio mantenedor. Esse uso
interno valida brain, Skills, runtime e automações em produção real. Amanhã a
mesma distribuição poderá ser provisionada como instância dedicada para um
advogado ou escritório. Os serviços jurídicos especializados permanecem em
backend externo e podem ser consumidos por crédito. Quem não quiser o agente
completo poderá consumir só as automações. E não construiremos infraestrutura
de escala antes que clientes reais justifiquem a complexidade.
