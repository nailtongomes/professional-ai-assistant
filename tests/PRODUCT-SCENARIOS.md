---
type: conceptual-tests
status: active
created: 2026-08-24
updated: 2026-08-24
---

# Cenários conceituais de produto

Os casos em `tests/cases/*.json` verificam roteamento de Skill. Estes verificam
outra coisa: se as **fronteiras arquiteturais** de `docs/PRODUCT-VISION.md`
seguem de pé.

Não são executáveis, e a distinção é deliberada. Um cenário como "o cliente não
consegue ver a agenda do mantenedor" não deve passar por ser verificado em
runtime — deve ser impossível por construção. Um teste que precisa rodar para
provar isolamento é um teste que admite que o isolamento pode falhar.

Revisar esta lista sempre que uma fronteira for tocada.

---

## 1. Owner — uso pessoal

**Entrada:** "Adicione reunião amanhã às 15h."

**Esperado:** Skill `agenda`, `append` em `30-areas/agenda/events/<YYYY-MM>.md`
do brain **da própria instância**.

**Fronteira:** nenhuma. É o caso da fase 1.

---

## 2. Cliente advogado — serviço jurídico habilitado

**Entrada:** "Consulte o processo 0000000-00.0000.0.00.0000."

**Esperado:** Skill `process-query`, `http` contra o endpoint configurado, sob o
contrato de `WORKFLOW-CONTRACT.md`.

**Fronteira:** a Skill sabe *que contrato chamar*. Não sabe que existe Kestra,
container, Selenium ou credencial de tribunal. Se algum dia souber, a fronteira
do §5 foi atravessada.

---

## 3. Cliente advogado — dado de outra instância

**Entrada:** "Mostre a agenda do mantenedor."

**Esperado:** impossível — não há caminho.

**Fronteira:** esta é a propriedade que o single-tenant compra. A instância do
cliente monta o brain do cliente; o brain do mantenedor não existe naquele
sistema de arquivos, não está em nenhum índice e não é alcançável por
configuração. A resposta certa não é uma recusa educada do agente: é a ausência
de dado.

**Sinal de regressão:** qualquer coisa que faça um brain conhecer outro —
diretório compartilhado, índice central, identificador de tenant em caminho de
arquivo. Se aparecer, multi-tenancy entrou pela porta dos fundos.

---

## 4. Backend de automação — payload

**Recebe:**

```json
{ "numero_processo": "0000000-00.0000.0.00.0000" }
```

**Não recebe:** brain, memória, histórico de conversa, agenda, projetos,
arquivos não relacionados.

**Fronteira:** §14. O responsável por montar o payload é a Skill; o backend não
tem como saber o que não deveria ter recebido.

---

## 5. Troca de runtime

**Ação:** substituir Nanobot por Hermes na instância.

**Esperado:** `process-query` não muda. Nenhum `SKILL.md` muda. Mudam o adapter
e a configuração do runtime.

**Fronteira:** §12. Se a troca exigir editar uma Skill, o runtime vazou para
dentro do produto.

---

## 6. Cliente novo

**Ação:** provisionar uma instalação para um advogado.

**Esperado:** mesmo repositório, mesmos scripts, mesmo modelo de brain, mesmas
Skills core. Mudam `.env`, perfil, identidade do dono, Skills habilitadas,
provedor/modelo e configuração comercial.

**Fronteira:** §10 e §18. Se exigir fork, branch por cliente ou edição manual
extensa, registre como dívida arquitetural — não contorne no caso concreto. O
contorno some no histórico; a dívida registrada, não.

---

## 7. Template público

**Ação:** ler este repositório inteiro, como um estranho.

**Esperado:** metodologia genérica. Nenhum dado de cliente, nenhum segredo,
nenhum endpoint real, nenhum domínio privado, nenhuma identidade do mantenedor
em procedimento operacional.

**Fronteira:** §8 e §15. Há teste automatizado em `tests/run-local-tests.sh`
para as três últimas — o restante é revisão humana.
