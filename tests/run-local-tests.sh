#!/usr/bin/env bash
#
# Testes locais e seguros do ciclo de vida. Nada toca a VPS: tudo acontece
# dentro de um diretório temporário via ASSISTANT_PREFIX.
#
#   ./tests/run-local-tests.sh
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ok()   { printf '  PASS  %s\n' "$*"; PASS=$((PASS+1)); }
bad()  { printf '  FAIL  %s\n' "$*" >&2; FAIL=$((FAIL+1)); }
# Roda em subshell: die() chama exit e não pode derrubar o test runner.
check(){ local d="$1"; shift; if ( "$@" ) >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
check_fails(){ local d="$1"; shift; if ( "$@" ) >/dev/null 2>&1; then bad "$d"; else ok "$d"; fi; }

export ASSISTANT_PREFIX="$TMP"
export ASSISTANT_USER="$(id -un)"
export ASSISTANT_HOME="$TMP/home"
mkdir -p "$ASSISTANT_HOME"

BRAIN="$TMP/srv/professional-ai-assistant/brain"
CONFIG_DIR="$TMP/etc/professional-ai-assistant"
BACKUPS="$TMP/var/backups/professional-ai-assistant"

printf '\n== sintaxe ==\n'
for f in "$REPO"/scripts/*.sh "$REPO"/scripts/lib/*.sh "$REPO"/tests/*.sh; do
  check "bash -n $(basename "$f")" bash -n "$f"
done

printf '\n== shellcheck ==\n'
if command -v shellcheck >/dev/null 2>&1; then
  for f in "$REPO"/scripts/*.sh "$REPO"/scripts/lib/*.sh; do
    check "shellcheck $(basename "$f")" shellcheck -x -S warning "$f"
  done
else
  printf '  SKIP  shellcheck não instalado (opcional)\n'
fi

printf '\n== validação de path (common.sh) ==\n'
# shellcheck source=/dev/null
( set +e; . "$REPO/scripts/lib/common.sh"
  check_fails "recusa /"                 assert_safe_path "/"
  check_fails "recusa /etc"              assert_safe_path "/etc"
  check_fails "recusa path relativo"     assert_safe_path "relativo/x"
  check_fails "recusa path vazio"        assert_safe_path ""
  check_fails "recusa fora das raízes"   assert_safe_path "/tmp/qualquer"
  check_fails "recusa .."                assert_safe_path "$BRAIN/../../etc"
  check      "aceita dentro do brain"    assert_safe_path "$BRAIN/nota.md"
  check_fails "recusa remover a raiz"    safe_remove "$BRAIN"
  exit 0 )

printf '\n== dry-run: install ==\n'
check "install --dry-run" "$REPO/scripts/install.sh" --dry-run --skip-nanobot
check_fails "install --dry-run não criou brain" test -d "$BRAIN"
check_fails "install --dry-run não criou config" test -f "$CONFIG_DIR/assistant.env"

printf '\n== instalação real em sandbox ==\n'
mkdir -p "$CONFIG_DIR" "$BACKUPS" "$TMP/var/lib/professional-ai-assistant/runtime"
cp "$REPO/.env.example" "$CONFIG_DIR/assistant.env"
sed -i 's|^N8N_BASE_URL=.*|N8N_BASE_URL=|' "$CONFIG_DIR/assistant.env"
"$REPO/scripts/bootstrap.sh" "$BRAIN" >/dev/null
check "brain criado"                    test -f "$BRAIN/INDEX.md"
check "estrutura válida"                python3 "$REPO/scripts/validate_structure.py" --brain "$BRAIN"

printf '\n== sync ==\n'
check "sync --dry-run"                  "$REPO/scripts/sync.sh" --dry-run --source "$REPO/brain"
check "sync aplica"                     "$REPO/scripts/sync.sh" --source "$REPO/brain"
check "sync é idempotente"              "$REPO/scripts/sync.sh" --source "$REPO/brain"

# user data intocado
echo "nota pessoal" > "$BRAIN/10-inbox/minha-nota.md"
mkdir -p "$BRAIN/70-skills/local/minha-skill"
echo "# local" > "$BRAIN/70-skills/local/minha-skill/SKILL.md"
"$REPO/scripts/sync.sh" --source "$REPO/brain" >/dev/null 2>&1 || true
check "sync preserva nota do usuário"   test -f "$BRAIN/10-inbox/minha-nota.md"
check "sync preserva Skill local"       test -f "$BRAIN/70-skills/local/minha-skill/SKILL.md"

# conflito: arquivo gerenciado modificado localmente + mudança no template
printf '\n== conflito ==\n'
SRC="$TMP/template-brain"; cp -a "$REPO/brain" "$SRC"
echo "alteração local" >> "$BRAIN/00-system/PHILOSOPHY.md"
echo "alteração do template" >> "$SRC/00-system/PHILOSOPHY.md"
if "$REPO/scripts/sync.sh" --source "$SRC" >/dev/null 2>&1; then
  bad "sync deveria reportar conflito"
else
  [[ $? -ge 1 ]] && ok "sync detecta conflito e aborta"
fi
grep -q "alteração local" "$BRAIN/00-system/PHILOSOPHY.md" \
  && ok "conflito não sobrescreveu o arquivo local" \
  || bad "arquivo local foi sobrescrito"
# Regressão: um conflito não pode virar sobrescrita silenciosa no sync seguinte.
"$REPO/scripts/sync.sh" --source "$SRC" >/dev/null 2>&1 && bad "conflito sumiu na 2a execução" || ok "conflito persiste entre execuções"
grep -q "alteração local" "$BRAIN/00-system/PHILOSOPHY.md" \
  && ok "alteração local sobrevive a syncs repetidos" \
  || bad "alteração local perdida em sync repetido"
check "sync --force resolve"            "$REPO/scripts/sync.sh" --force --source "$SRC"
check "backup do conflito existe"       bash -c "ls -d '$BACKUPS'/conflicts/* >/dev/null 2>&1"

printf '\n== backup ==\n'
check "backup --dry-run"                "$REPO/scripts/backup.sh" --dry-run
BK="$("$REPO/scripts/backup.sh" | tail -n1)"
check "backup criou diretório"          test -d "$BK"
check "backup tem brain.tar.gz"         test -f "$BK/brain.tar.gz"
check "backup tem manifest"             test -f "$BK/manifest.txt"
check "backup sem secrets por padrão"   bash -c "! test -f '$BK/assistant.env'"
check "manifest registra versão"        grep -q "template_commit:" "$BK/manifest.txt"
check "backup preserva nota do usuário" bash -c "tar tzf '$BK/brain.tar.gz' | grep -q 'minha-nota.md'"

printf '\n== restore ==\n'
check "restore --dry-run"               "$REPO/scripts/restore.sh" --dry-run "$BK"
check "restore dry-run não alterou"     test -f "$BRAIN/10-inbox/minha-nota.md"
check_fails "restore recusa backup inexistente" "$REPO/scripts/restore.sh" --dry-run "$TMP/nao-existe"
check_fails "restore recusa path fora da raiz"  "$REPO/scripts/restore.sh" --dry-run "/etc"

printf '\n== healthcheck ==\n'
# Sem nanobot instalado, healthcheck deve falhar (exit 1) e dizer por quê.
if "$REPO/scripts/healthcheck.sh" >/dev/null 2>&1; then
  bad "healthcheck deveria falhar sem nanobot"
else
  ok "healthcheck falha sem nanobot instalado"
fi
NB_STUB="$TMP/home/.local/bin"; mkdir -p "$NB_STUB"
printf '#!/bin/sh\ncase "$1" in --version) echo "nanobot 9.9.9";; gateway) echo "stopped"; exit 1;; esac\n' > "$NB_STUB/nanobot"
chmod +x "$NB_STUB/nanobot"
out="$("$REPO/scripts/healthcheck.sh" 2>&1 || true)"
grep -q "9.9.9" <<<"$out" && ok "healthcheck lê a versão do nanobot" || bad "versão não detectada"
grep -q "N8N_BASE_URL não configurado" <<<"$out" \
  && ok "healthcheck pula n8n sem configuração" || bad "n8n não tratado sem configuração"

printf '\n== update ==\n'
# Repositório sujo deve abortar o update — é a proteção contra sobrescrever
# trabalho não commitado.
if ( cd "$REPO" && [[ -n "$(git status --porcelain)" ]] ); then
  out="$("$REPO/scripts/update.sh" --dry-run --skip-nanobot 2>&1 || true)"
  grep -q "Update aborted: repository has local changes." <<<"$out" \
    && ok "update aborta com alterações locais" \
    || bad "update deveria abortar com repositório sujo"
fi

# Repositório limpo: dry-run precisa completar sem alterar estado.
CLONE="$TMP/clone"
git clone --quiet "$REPO" "$CLONE" 2>/dev/null
if [[ -d "$CLONE/.git" ]]; then
  # O clone reflete o HEAD; traz os scripts da árvore de trabalho e commita,
  # para que o checkout fique limpo e testemos o caminho feliz do update.
  cp -a "$REPO/scripts" "$REPO/config" "$CLONE/" 2>/dev/null || true
  ( cd "$CLONE" \
    && git config user.email t@e && git config user.name t \
    && git add -A >/dev/null && git commit -qm "fixture" >/dev/null 2>&1 || true )
  before="$(find "$BRAIN" -type f | wc -l)"
  check "update --dry-run em repo limpo" env REPO_DIR="$CLONE" "$CLONE/scripts/update.sh" --dry-run --skip-nanobot
  after="$(find "$BRAIN" -type f | wc -l)"
  [[ "$before" == "$after" ]] && ok "update --dry-run não alterou o brain" \
                             || bad "update --dry-run alterou arquivos"
  check_fails "update sem backup possível aborta" \
    env REPO_DIR="$CLONE" BACKUP_DIR=/proc/nao-existe "$CLONE/scripts/update.sh" --skip-nanobot
fi

printf '\n== doctor ==\n'
# 0 = ok, 1 = degradado (sem nanobot na sandbox), 2 = erro. Só 2 reprova.
# A sandbox tem uma Skill local não registrada no índice (criada acima, de
# propósito): o doctor precisa detectar isso e sair 2.
# O `if` é necessário: com `set -e`, capturar $? depois do comando aborta a suíte.
run_doctor() {
  if "$REPO/scripts/doctor.sh" --skip-network >"$TMP/doctor.out" 2>&1; then
    echo 0
  else
    echo $?
  fi
}
rc="$(run_doctor)"
[[ "$rc" == "2" ]] && ok "doctor detecta brain estruturalmente inválido" \
                   || bad "doctor deveria sair 2 com Skill não indexada (saiu $rc)"
grep -q "Structure.*ERROR" "$TMP/doctor.out" \
  && ok "doctor aponta a área com problema" || bad "doctor não apontou Structure"

# Com o brain íntegro, no máximo avisos (sem nanobot real, sem rede).
rm -rf "$BRAIN/70-skills/local"
rc="$(run_doctor)"
[[ "$rc" != "2" ]] && ok "doctor --skip-network roda em brain íntegro (exit $rc)" \
                   || { bad "doctor saiu 2 em brain íntegro"; sed 's/^/    /' "$TMP/doctor.out"; }
grep -q "Nanobot" "$TMP/doctor.out" && ok "doctor reporta estado do Nanobot" || bad "sem linha de Nanobot"
grep -qE "N8N_BASE_URL: (configured|missing)" <("$REPO/scripts/doctor.sh" --skip-network --verbose 2>&1 || true) \
  && ok "doctor mostra config sem imprimir valor" || bad "config não reportada"
check "doctor é somente leitura"        bash -c '
  before=$(find "$1" -type f | wc -l)
  "$0/scripts/doctor.sh" --skip-network >/dev/null 2>&1 || true
  after=$(find "$1" -type f | wc -l)
  [ "$before" = "$after" ]' "$REPO" "$BRAIN"
# Sem brain, doctor precisa sair 2 (erro), não 0.
check_fails "doctor falha sem brain" \
  env ASSISTANT_PREFIX="$TMP/vazio" "$REPO/scripts/doctor.sh" --skip-network

printf '\n== acesso owner-only ==\n'
NB_CFG="$ASSISTANT_HOME/.nanobot/config.json"
mkdir -p "$(dirname "$NB_CFG")"
CFG_ENV="$CONFIG_DIR/assistant.env"

# Caso 6 (preservação) + caso 1 (owner definido): config com outras opções.
cat > "$NB_CFG" <<'JSON'
{"providers":{"groq":{"apiKey":"${GROQ_KEY}"}},
 "channels":{"telegram":{"enabled":true,"token":"${TELEGRAM_TOKEN}","allowFrom":["*"]},
             "slack":{"enabled":false}},
 "outraOpcao":true}
JSON
sed -i '/^OWNER_TELEGRAM_ID=/d' "$CFG_ENV"
echo 'OWNER_TELEGRAM_ID=123456789' >> "$CFG_ENV"

check "configure --dry-run"             "$REPO/scripts/configure-nanobot.sh" --dry-run
grep -q '"\*"' "$NB_CFG" && ok "dry-run não alterou o config" || bad "dry-run alterou o config"

check "configure aplica owner-only"     "$REPO/scripts/configure-nanobot.sh"
if python3 "$REPO/tests/assert_config.py" "$NB_CFG" owner-applied; then
  ok "caso 1: allowFrom = [owner], enabled = true"
else bad "caso 1 falhou"; fi
if python3 "$REPO/tests/assert_config.py" "$NB_CFG" preserved; then
  ok "caso 6: opções não relacionadas preservadas"
else bad "caso 6 falhou"; fi

before="$(sha256sum "$NB_CFG" | cut -d' ' -f1)"
"$REPO/scripts/configure-nanobot.sh" >/dev/null 2>&1
after="$(sha256sum "$NB_CFG" | cut -d' ' -f1)"
[[ "$before" == "$after" ]] && ok "caso 5: idempotente (config byte a byte igual)" \
                            || bad "caso 5: config mudou na 2a execução"

# Caso 3: wildcard é erro grave no doctor.
python3 "$REPO/tests/assert_config.py" "$NB_CFG" set-wildcard
if "$REPO/scripts/doctor.sh" --skip-network >"$TMP/acc.out" 2>&1; then acc_rc=0; else acc_rc=$?; fi
[[ $acc_rc -eq 2 ]] && ok "caso 3: doctor sai 2 com wildcard" || bad "caso 3: doctor saiu $acc_rc"
grep -q "telegram access.*ERROR" "$TMP/acc.out" && ok "caso 3: doctor aponta o canal" \
                                                || bad "caso 3: canal não apontado"
grep -q "123456789" "$TMP/acc.out" && bad "doctor imprimiu o ID completo" \
                                   || ok "doctor mascara o identificador"

check "configure fecha wildcard"        "$REPO/scripts/configure-nanobot.sh"
python3 "$REPO/tests/assert_config.py" "$NB_CFG" owner-applied \
  && ok "wildcard substituído pelo owner" || bad "wildcard permaneceu"

# Caso 2: owner ausente = fail closed, nunca wildcard.
sed -i '/^OWNER_TELEGRAM_ID=/d' "$CFG_ENV"
if "$REPO/scripts/configure-nanobot.sh" >/dev/null 2>&1; then cfg_rc=0; else cfg_rc=$?; fi
[[ $cfg_rc -eq 3 ]] && ok "caso 2: fail closed sinalizado (exit 3)" || bad "caso 2: exit $cfg_rc"
python3 "$REPO/tests/assert_config.py" "$NB_CFG" fail-closed \
  && ok "caso 2: canal desabilitado, allowFrom vazio, sem wildcard" \
  || bad "caso 2: canal não fechou"

# Config corrompido nunca é sobrescrito.
cp "$NB_CFG" "$TMP/cfg.bak"; echo '{quebrado' > "$NB_CFG"
check_fails "configure recusa JSON inválido"  "$REPO/scripts/configure-nanobot.sh"
grep -q "quebrado" "$NB_CFG" && ok "config inválido preservado" || bad "config inválido foi sobrescrito"
cp "$TMP/cfg.bak" "$NB_CFG"

# Caso 4: sender desconhecido não está na allowlist (rejeição é nativa do Nanobot).
echo 'OWNER_TELEGRAM_ID=123456789' >> "$CFG_ENV"
"$REPO/scripts/configure-nanobot.sh" >/dev/null 2>&1
python3 "$REPO/tests/assert_config.py" "$NB_CFG" only-owner \
  && ok "caso 4: segundo sender fora da allowlist" || bad "caso 4 falhou"

printf '\n== seleção de runtime ==\n'
HERMES_DIR="$TMP/hermes-home"; mkdir -p "$HERMES_DIR"
CFG_ENV="$CONFIG_DIR/assistant.env"

check "runtime padrão é nanobot" bash -c '
  . "$0/scripts/lib/common.sh"; [ "$(selected_runtime)" = "nanobot" ]' "$REPO"
check "ASSISTANT_RUNTIME=hermes seleciona hermes" bash -c '
  export ASSISTANT_RUNTIME=hermes; . "$0/scripts/lib/common.sh"
  [ "$(selected_runtime)" = "hermes" ]' "$REPO"
check_fails "runtime inválido falha" bash -c '
  export ASSISTANT_RUNTIME=invalido; . "$0/scripts/lib/common.sh"; selected_runtime' "$REPO"
check "state é separado por runtime" bash -c '
  . "$0/scripts/lib/common.sh"
  n="$(ASSISTANT_RUNTIME=nanobot; selected_runtime)"
  h="$(ASSISTANT_RUNTIME=hermes; selected_runtime)"
  [ "$n" != "$h" ]' "$REPO"

# doctor diagnostica o runtime ativo, sem exigir o outro instalado
if "$REPO/scripts/doctor.sh" --skip-network >"$TMP/rt.out" 2>&1; then :; fi
grep -q "^Runtime  *OK nanobot" "$TMP/rt.out" && ok "doctor mostra o runtime ativo" \
                                              || bad "doctor não mostrou o runtime"
# A configuração vence o ambiente: para trocar de runtime, muda-se o env file.
sed -i 's/^ASSISTANT_RUNTIME=.*/ASSISTANT_RUNTIME=hermes/' "$CFG_ENV"
grep -q '^ASSISTANT_RUNTIME=' "$CFG_ENV" || echo 'ASSISTANT_RUNTIME=hermes' >> "$CFG_ENV"
if "$REPO/scripts/doctor.sh" --skip-network >"$TMP/rt2.out" 2>&1; then :; fi
sed -i 's/^ASSISTANT_RUNTIME=.*/ASSISTANT_RUNTIME=nanobot/' "$CFG_ENV"
grep -q "hermes" "$TMP/rt2.out" && ok "doctor delega ao adapter hermes" || bad "sem delegação"
grep -q "Nanobot.*not installed" "$TMP/rt2.out" && bad "doctor exigiu nanobot com runtime hermes" \
                                                 || ok "doctor não exige o runtime inativo"

printf '\n== adapter hermes ==\n'
cat > "$TMP/hermes.env" <<'ENVEOF'
ASSISTANT_RUNTIME=hermes
OWNER_TELEGRAM_ID=123456789
ENVEOF
HCFG=(--brain "$BRAIN" --hermes-home "$HERMES_DIR" --env-file "$TMP/hermes.env")

# exit 3 = canais sem owner desabilitados (esperado: só telegram tem owner aqui).
run_configure() {
  if python3 "$REPO/runtime-adapters/hermes/configure.py" "$@" >"$TMP/cfg.out" 2>&1
  then echo 0; else echo $?; fi
}
rc="$(run_configure --dry-run "${HCFG[@]}")"
[[ "$rc" == "0" || "$rc" == "3" ]] && ok "configure --dry-run (exit $rc)" || bad "configure --dry-run: exit $rc"
[[ -e "$HERMES_DIR/SOUL.md" ]] && bad "dry-run gravou arquivos" || ok "dry-run não gravou nada"

rc="$(run_configure "${HCFG[@]}")"
[[ "$rc" == "0" || "$rc" == "3" ]] && ok "configure aplica (exit $rc)" || bad "configure aplica: exit $rc"
[[ -f "$HERMES_DIR/SOUL.md" ]] && ok "SOUL.md derivado gerado" || bad "SOUL.md ausente"
grep -q "GERADO" "$HERMES_DIR/SOUL.md" && ok "SOUL.md marcado como derivado" || bad "SOUL.md sem marca"
skills_linked="$(find "$HERMES_DIR/skills" -maxdepth 1 -type l -name 'pai-*' | wc -l)"
[[ "$skills_linked" -eq 8 ]] && ok "8 Skills mapeadas por symlink" || bad "mapeou $skills_linked Skills"

# Skills canônicas não mudam ao configurar o runtime
canon_before="$(find "$BRAIN/70-skills" -name SKILL.md -exec sha256sum {} + | sha256sum)"
run_configure "${HCFG[@]}" >/dev/null
canon_after="$(find "$BRAIN/70-skills" -name SKILL.md -exec sha256sum {} + | sha256sum)"
[[ "$canon_before" == "$canon_after" ]] && ok "Skills canônicas intactas" || bad "Skills canônicas mudaram"

# dados user-owned intactos ao trocar de runtime
[[ -f "$BRAIN/10-inbox/minha-nota.md" ]] && ok "user data preservado na troca de runtime" \
                                         || bad "user data perdido"

# idempotência
run_configure "${HCFG[@]}" >/dev/null
grep -q "convergido" "$TMP/cfg.out" && ok "configure é idempotente" || bad "configure não convergiu"

# owner-only e fail closed
grep -q "dm_policy: allowlist" "$HERMES_DIR/gateway.yaml" && ok "dm_policy allowlist explícito" \
                                                          || bad "dm_policy ausente"
grep -qE 'allow_from: \["123456789"\]' "$HERMES_DIR/gateway.yaml" && ok "allow_from = owner" \
                                                                  || bad "allow_from incorreto"
grep -q "dm_policy: open" "$HERMES_DIR/gateway.yaml" && bad "dm_policy open encontrado" \
                                                     || ok "nenhum dm_policy open"
echo 'ASSISTANT_RUNTIME=hermes' > "$TMP/hermes-noowner.env"
hrc="$(run_configure --brain "$BRAIN" --hermes-home "$HERMES_DIR" \
        --env-file "$TMP/hermes-noowner.env")"
[[ $hrc -eq 3 ]] && ok "fail closed sem owner (exit 3)" || bad "fail closed: exit $hrc"
grep -A3 "^telegram:" "$HERMES_DIR/gateway.yaml" | grep -q "enabled: false" \
  && ok "canal desabilitado sem owner" || bad "canal ficou habilitado"

# Skill gerada pelo runtime não toca as managed
mkdir -p "$HERMES_DIR/skills/auto-gerada"
echo "# gerada pelo runtime" > "$HERMES_DIR/skills/auto-gerada/SKILL.md"
run_configure --brain "$BRAIN" --hermes-home "$HERMES_DIR" --env-file "$TMP/hermes.env" >/dev/null
[[ -f "$HERMES_DIR/skills/auto-gerada/SKILL.md" ]] && ok "Skill do runtime preservada onde nasceu" \
                                                   || bad "Skill do runtime removida"
find "$BRAIN/70-skills" -name "SKILL.md" -newer "$HERMES_DIR/skills/auto-gerada/SKILL.md" 2>/dev/null | grep -q . \
  && bad "Skill gerada alterou o brain" || ok "Skill gerada não alterou managed skills"

# Acoplamento real seria citar o runtime onde a Skill declara capacidades.
# Menção em exemplo de fala do usuário ("decidi usar X no MVP") é conteúdo, não
# acoplamento — por isso a checagem olha a seção Tools, não o arquivo inteiro.
check "Skills declaram capacidades conceituais" python3 - "$REPO" <<'PYEOF'
import re, sys
from pathlib import Path
bad = []
for skill in Path(sys.argv[1], "brain/70-skills").rglob("SKILL.md"):
    text = skill.read_text(encoding="utf-8")
    m = re.search(r"^## Tools$(.*?)^## ", text, re.M | re.S)
    if not m:
        bad.append(f"{skill}: sem seção Tools")
        continue
    if re.search(r"(?i)hermes|nanobot", m.group(1)):
        bad.append(f"{skill}: cita runtime na seção Tools")
sys.exit(1 if bad else 0)
PYEOF

printf '\n== deploy / VPS ==\n'
CL="$TMP/changelog.md"

check "changelog registra entrada"      env CHANGELOG_FILE="$CL" "$REPO/scripts/changelog.sh" "deploy inicial do runtime"
check "changelog é append-only" bash -c '
  before=$(wc -l < "$1")
  CHANGELOG_FILE="$1" "$0/scripts/changelog.sh" "segunda mudança registrada" >/dev/null
  after=$(wc -l < "$1")
  [ "$after" -gt "$before" ] && grep -q "deploy inicial" "$1"' "$REPO" "$CL"
check_fails "changelog recusa descrição vazia" env CHANGELOG_FILE="$CL" "$REPO/scripts/changelog.sh" "curta"
check "changelog --list funciona"       env CHANGELOG_FILE="$CL" "$REPO/scripts/changelog.sh" --list

# Layout /opt: os scripts precisam operar com BRAIN_DIR sobrescrito.
check "BRAIN_DIR=/opt/brain é aceito" bash -c '
  export BRAIN_DIR=/opt/brain
  . "$0/scripts/lib/common.sh"
  assert_safe_path /opt/brain/60-memory' "$REPO"
check_fails "path fora do brain segue recusado" bash -c '
  export BRAIN_DIR=/opt/brain
  . "$0/scripts/lib/common.sh"
  assert_safe_path /opt/outra-coisa' "$REPO"

# compose: válido, sem porta publicada, sem volume nomeado, imagem obrigatória
check "compose sem ports publicadas" bash -c '! grep -qE "^\s*ports:" "$0/deploy/docker-compose.yml"' "$REPO"
check "compose sem volumes nomeados" bash -c '! grep -qE "^volumes:" "$0/deploy/docker-compose.yml"' "$REPO"
check "compose exige RUNTIME_IMAGE"   bash -c 'grep -q "RUNTIME_IMAGE:?" "$0/deploy/docker-compose.yml"' "$REPO"
check "compose monta /opt/brain"      bash -c 'grep -q "/opt/brain:/brain" "$0/deploy/docker-compose.yml"' "$REPO"
check "compose sem privilégio extra"  bash -c 'grep -q "no-new-privileges:true" "$0/deploy/docker-compose.yml"' "$REPO"
if command -v docker >/dev/null 2>&1; then
  check "docker compose config valida" bash -c '
    d="$(mktemp -d)"; cp "$0/deploy/docker-compose.yml" "$d/"
    : > "$d/assistant.env"
    sed -i "s|/etc/professional-ai-assistant/assistant.env|$d/assistant.env|" "$d/docker-compose.yml"
    cd "$d" && RUNTIME_IMAGE=exemplo:tag docker compose config -q' "$REPO"
  check_fails "compose falha sem RUNTIME_IMAGE" bash -c '
    d="$(mktemp -d)"; cp "$0/deploy/docker-compose.yml" "$d/"
    : > "$d/assistant.env"
    sed -i "s|/etc/professional-ai-assistant/assistant.env|$d/assistant.env|" "$d/docker-compose.yml"
    cd "$d" && docker compose config -q' "$REPO"
else
  printf '  SKIP  docker não instalado (validação de compose)\n'
fi

# regras de operação presentes e sem valor privado
check "CLAUDE.md lista comandos proibidos" bash -c '
  grep -q "docker system prune --volumes" "$0/CLAUDE.md" \
  && grep -q "docker volume rm" "$0/CLAUDE.md" \
  && grep -q "/opt/brain/memory" "$0/CLAUDE.md"' "$REPO"
check "CLAUDE.md exige confirmação explícita" \
  bash -c 'grep -qi "aguardar confirmação" "$0/CLAUDE.md"' "$REPO"
check "regra de dependência documentada" bash -c '
  grep -q "brain    ──nunca" "$0/CLAUDE.md" && grep -q "brain    ──nunca" "$0/deploy/README.md"' "$REPO"
check "troca de runtime alerta sobre schema" \
  bash -c 'grep -qi "migram sozinhas" "$0/deploy/README.md"' "$REPO"
check_fails "nenhum secret no deploy/" bash -c '
  grep -rnE "^(RUNTIME_IMAGE|ASSISTANT_RUNTIME)=.+" "$0/deploy/vps.env.example" | grep -vE "=nanobot$" | grep -q .' "$REPO"

printf '\n== casos conceituais ==\n'


check "validate_cases"                  python3 "$REPO/tests/validate_cases.py"
check "validate_cases --strict"         python3 "$REPO/tests/validate_cases.py" --strict

printf '\n== segurança ==\n'
# Ignora comentários: o que importa é o código executável.
code_only() { grep -rhv '^[[:space:]]*#' "$REPO"/scripts/*.sh "$REPO"/scripts/lib/*.sh; }
export -f code_only
# O repositório é público: nenhum domínio, endpoint ou webhook privado pode
# estar versionado. A allowlist cobre só o que é público e legítimo.
# Hostname sem esquema também vaza infraestrutura: o teste anterior só olhava
# URLs com http(s):// e deixou passar um "tests.exemplo.com" solto.
check_fails "nenhum domínio privado em texto" bash -c '
  grep -rhIoE "\\b[a-z0-9-]+\\.[a-z0-9-]+\\.(com|net|org|io|dev|app|br)\\b" \
    "$0/scripts" "$0/config" "$0/brain" "$0/docs" "$0/deploy" "$0/CLAUDE.md" \
    "$0/.env.example" 2>/dev/null \
  | sort -u \
  | grep -vE "^(raw\\.githubusercontent\\.com|hermes-agent\\.nousresearch\\.com|automation\\.example\\.com|[a-z-]+\\.example\\.com)$" \
  | grep -q .' "$REPO"
check_fails "nenhum host privado versionado" bash -c '
  grep -rhoE "https?://[A-Za-z0-9.-]+" "$0"/scripts "$0"/config "$0"/brain "$0"/docs "$0"/.env.example 2>/dev/null \
    | sort -u \
    | grep -vE "^https://(raw\.githubusercontent\.com|github\.com|json-schema\.org|automation\.example\.com|example\.com|SEU-ENDPOINT-PRIVADO)$" \
    | grep -vE "^http://(127\.0\.0\.1|localhost)$" \
    | grep -q .' "$REPO"
check_fails "nenhum valor preenchido no .env.example" \
  bash -c "grep -E '^(ASSISTANT_DOMAIN|ASSISTANT_BASE_URL|N8N_BASE_URL|KESTRA_BASE_URL|.*_ENDPOINT|.*_API_KEY|.*_TOKEN)=.+' '$REPO/.env.example' | grep -q ."
check_fails "rm -rf fora de safe_remove"       bash -c "code_only | grep -E 'rm -rf' | grep -qv 'safe_remove'"
check_fails "git reset --hard"                 bash -c "code_only | grep -q 'reset --hard'"
check_fails "rsync --delete"                   bash -c "code_only | grep -q 'rsync.*--delete'"
check_fails "curl canalizado direto para sh"   bash -c "code_only | grep -qE 'curl[^|]*\| *sh'"
check      "todo script usa set -Eeuo pipefail" bash -c '
  for f in "$0"/scripts/*.sh "$0"/scripts/lib/common.sh; do
    case "$(basename "$f")" in bootstrap.sh|common.sh) continue ;; esac
    grep -q "set -Eeuo pipefail" "$f" || exit 1
  done' "$REPO"

printf '\n== resultado ==\n  %d passaram, %d falharam\n\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
