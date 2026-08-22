#!/usr/bin/env bash
#
# Diagnóstico somente leitura: "o que está errado nesta instalação?"
#
#   ./scripts/doctor.sh
#   ./scripts/doctor.sh --skip-network
#   ./scripts/doctor.sh --verbose
#
# Não corrige nada. Não altera permissões. Não imprime valores de secrets.
#
# Exit: 0 healthy | 1 warning/degraded | 2 error
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

SKIP_NETWORK=0
VERBOSE=0

usage() {
  cat <<'USAGE'
Uso: doctor.sh [--skip-network] [--verbose]

  --skip-network  não faz nenhuma chamada HTTP
  --verbose       mostra os detalhes de cada verificação

Exit: 0 saudável | 1 degradado (avisos) | 2 erro
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-network) SKIP_NETWORK=1 ;;
    --verbose|-v) VERBOSE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; die "argumento desconhecido: $1" ;;
  esac
  shift
done

errors=0
warns=0
details=()

# Uma linha por área. O detalhe fica embaixo, e só com --verbose.
report() { # área, estado, detalhe
  printf '%-18s %s\n' "$1" "$2"
  [[ -n "${3:-}" ]] && details+=("  ${1}: ${3}")
  case "$2" in
    ERROR*) errors=$((errors + 1)) ;;
    WARN*)  warns=$((warns + 1)) ;;
  esac
}

load_env >/dev/null 2>&1 || true

# --- repositório ------------------------------------------------------------
REPO_CHECKOUT="$REPO_DIR"
[[ -d "${REPO_CHECKOUT}/.git" ]] || REPO_CHECKOUT="$(cd "${SCRIPT_DIR}/.." && pwd)"
if [[ -d "${REPO_CHECKOUT}/.git" ]] && command -v git >/dev/null 2>&1; then
  branch="$(git -C "$REPO_CHECKOUT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
  commit="$(git -C "$REPO_CHECKOUT" rev-parse --short HEAD 2>/dev/null || echo '?')"
  dirty="$(git -C "$REPO_CHECKOUT" status --porcelain 2>/dev/null | wc -l)"
  if [[ "$dirty" -gt 0 ]]; then
    report "Repository" "WARN dirty (${dirty} arquivo(s))" "${branch}@${commit} em ${REPO_CHECKOUT}"
    [[ "$VERBOSE" == "1" ]] && git -C "$REPO_CHECKOUT" status --short | sed 's/^/    /'
  else
    report "Repository" "OK ${branch}@${commit}" "$REPO_CHECKOUT"
  fi
else
  report "Repository" "WARN sem checkout Git" "procurado em ${REPO_DIR}"
fi

# --- brain ------------------------------------------------------------------
if [[ -d "$BRAIN_DIR" ]]; then
  missing=()
  for f in INDEX.md 00-system/PHILOSOPHY.md 00-system/agent-rules.md 70-skills/INDEX.md; do
    [[ -f "${BRAIN_DIR}/${f}" ]] || missing+=("$f")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    report "Brain" "ERROR arquivos ausentes" "${missing[*]}"
  elif [[ -r "$BRAIN_DIR" ]]; then
    skills="$(find "${BRAIN_DIR}/70-skills" -name SKILL.md 2>/dev/null | wc -l)"
    report "Brain" "OK ${skills} Skill(s)" "$BRAIN_DIR"
  else
    report "Brain" "ERROR sem permissão de leitura" "$BRAIN_DIR"
  fi
else
  report "Brain" "ERROR não encontrado" "$BRAIN_DIR"
fi

# --- managed files ----------------------------------------------------------
MANIFEST="${REPO_CHECKOUT}/config/managed-paths.txt"
if [[ ! -f "$MANIFEST" ]]; then
  report "Managed files" "WARN manifesto não encontrado" "$MANIFEST"
elif [[ ! -d "$BRAIN_DIR" ]]; then
  report "Managed files" "SKIP brain ausente"
else
  absent=0
  while IFS= read -r entry; do
    entry="${entry%%#*}"; entry="$(printf '%s' "$entry" | tr -d '[:space:]')"
    [[ -n "$entry" ]] || continue
    [[ -e "${BRAIN_DIR}/${entry%/}" ]] || absent=$((absent + 1))
  done < "$MANIFEST"
  if [[ $absent -gt 0 ]]; then
    report "Managed files" "WARN ${absent} path(s) do manifesto ausente(s)" "rode sync.sh"
  else
    report "Managed files" "OK" "$MANIFEST"
  fi
fi

# --- user data --------------------------------------------------------------
if [[ -d "$BRAIN_DIR" ]]; then
  writable=1
  for d in 10-inbox 20-projects 30-areas 60-memory; do
    [[ -d "${BRAIN_DIR}/${d}" ]] || continue
    [[ -w "${BRAIN_DIR}/${d}" ]] || writable=0
  done
  owner="$(stat -c '%U' "$BRAIN_DIR" 2>/dev/null || echo '?')"
  if [[ $writable -eq 1 ]]; then
    report "User data" "OK gravável (dono: ${owner})"
  else
    report "User data" "WARN sem permissão de escrita" "dono: ${owner}; esperado: ${ASSISTANT_USER}"
  fi
fi

# --- scripts ----------------------------------------------------------------
missing_scripts=()
for s in install.sh update.sh sync.sh backup.sh restore.sh healthcheck.sh; do
  path="${SCRIPT_DIR}/${s}"
  if [[ ! -f "$path" ]]; then missing_scripts+=("${s}: ausente")
  elif [[ ! -x "$path" ]]; then missing_scripts+=("${s}: sem permissão de execução"); fi
done
if [[ ${#missing_scripts[@]} -gt 0 ]]; then
  report "Scripts" "ERROR ${#missing_scripts[@]} problema(s)" "${missing_scripts[*]}"
else
  report "Scripts" "OK"
fi

# --- nanobot ----------------------------------------------------------------
# Antes do deploy, ausência é aviso, não erro.
if bin="$(nanobot_bin 2>/dev/null)"; then
  version="$("$bin" --version 2>/dev/null | head -n1 || echo '?')"
  report "Nanobot" "OK ${version}" "$bin"
else
  report "Nanobot" "WARN not installed" "esperado após install.sh"
fi

# --- configuração -----------------------------------------------------------
# Só presença. Nunca valor.
if [[ -f "$CONFIG_FILE" ]]; then
  perms="$(stat -c '%a' "$CONFIG_FILE" 2>/dev/null || echo '?')"
  state="OK"
  [[ "$perms" == "600" ]] || state="WARN permissão ${perms} (esperado 600)"
  report "Runtime config" "$state" "$CONFIG_FILE"
  for var in N8N_BASE_URL PROCESS_QUERY_ENDPOINT PROCESS_COPY_ENDPOINT \
             DOCUMENT_QUERY_ENDPOINT PERSON_SEARCH_ENDPOINT SEND_EMAIL_ENDPOINT; do
    if [[ -n "${!var:-}" ]]; then
      details+=("  ${var}: configured")
    else
      details+=("  ${var}: missing")
    fi
  done
else
  report "Runtime config" "WARN assistant.env ausente" "$CONFIG_FILE"
fi

# --- automação --------------------------------------------------------------
if [[ "$SKIP_NETWORK" == "1" ]]; then
  report "Automation" "SKIP rede desabilitada"
elif [[ -z "${N8N_BASE_URL:-}" ]]; then
  report "Automation" "WARN N8N_BASE_URL não configurado"
elif ! command -v curl >/dev/null 2>&1; then
  report "Automation" "WARN curl ausente"
else
  status="$(curl -fsS -m "${HEALTHCHECK_TIMEOUT:-10}" -o /dev/null -w '%{http_code}' \
            "${N8N_BASE_URL%/}/webhook/ping" 2>/dev/null || echo "000")"
  case "$status" in
    200) report "Automation" "OK HTTP 200" ;;
    000) report "Automation" "ERROR sem resposta" "verifique rede, DNS e serviço" ;;
    *)   report "Automation" "ERROR HTTP ${status}" "esperado 200" ;;
  esac
fi

# --- backup -----------------------------------------------------------------
if [[ -d "$BACKUP_DIR" ]]; then
  last="$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -name '*Z' 2>/dev/null | sort | tail -n1)"
  if [[ -n "$last" ]]; then
    age_days="$(( ( $(date +%s) - $(stat -c %Y "$last" 2>/dev/null || date +%s) ) / 86400 ))"
    if [[ $age_days -gt 7 ]]; then
      report "Backup" "WARN último há ${age_days} dia(s)" "$(basename "$last")"
    else
      report "Backup" "OK há ${age_days} dia(s)" "$(basename "$last")"
    fi
  else
    report "Backup" "WARN no backup found" "$BACKUP_DIR"
  fi
else
  report "Backup" "WARN diretório ausente" "$BACKUP_DIR"
fi

# --- estrutura --------------------------------------------------------------
if command -v python3 >/dev/null 2>&1 && [[ -f "${SCRIPT_DIR}/validate_structure.py" ]] \
   && [[ -d "$BRAIN_DIR" ]]; then
  if python3 "${SCRIPT_DIR}/validate_structure.py" --brain "$BRAIN_DIR" >/dev/null 2>&1; then
    report "Structure" "OK"
  else
    report "Structure" "ERROR validate_structure reprovou" "rode: validate_structure.py --brain ${BRAIN_DIR}"
  fi
fi

# --- resumo -----------------------------------------------------------------
if [[ "$VERBOSE" == "1" && ${#details[@]} -gt 0 ]]; then
  printf '\n'
  printf '%s\n' "${details[@]}"
fi

printf '\n'
if [[ $errors -gt 0 ]]; then
  printf 'Overall: ERROR (%d erro(s), %d aviso(s))\n' "$errors" "$warns"
  exit 2
fi
if [[ $warns -gt 0 ]]; then
  printf 'Overall: WARN (%d aviso(s))\n' "$warns"
  exit 1
fi
printf 'Overall: OK\n'
