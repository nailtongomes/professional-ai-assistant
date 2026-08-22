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

printf '\n== casos conceituais ==\n'
check "validate_cases"                  python3 "$REPO/tests/validate_cases.py"
check "validate_cases --strict"         python3 "$REPO/tests/validate_cases.py" --strict

printf '\n== segurança ==\n'
# Ignora comentários: o que importa é o código executável.
code_only() { grep -rhv '^[[:space:]]*#' "$REPO"/scripts/*.sh "$REPO"/scripts/lib/*.sh; }
export -f code_only
# O repositório é público: nenhum domínio, endpoint ou webhook privado pode
# estar versionado. A allowlist cobre só o que é público e legítimo.
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
