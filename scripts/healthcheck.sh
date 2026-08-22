#!/usr/bin/env bash
#
# Verifica o estado do assistente: Nanobot, brain, permissões e n8n.
#
#   ./scripts/healthcheck.sh [--quiet]
#
# Saída: 0 tudo ok | 1 falha crítica | 2 apenas avisos.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

QUIET=0
[[ "${1:-}" == "--quiet" ]] && QUIET=1

failures=0
warnings=0

ok()    { [[ "$QUIET" == "1" ]] || printf '  ok    %s\n' "$*"; }
bad()   { printf '  FALHA %s\n' "$*" >&2; failures=$((failures + 1)); }
soft()  { printf '  aviso %s\n' "$*" >&2; warnings=$((warnings + 1)); }

load_env

[[ "$QUIET" == "1" ]] || printf 'Healthcheck — %s\n\n' "$(_ts)"

# --- 1. Nanobot ------------------------------------------------------------
[[ "$QUIET" == "1" ]] || printf 'Nanobot\n'
if bin="$(nanobot_bin)"; then
  ok "binário: ${bin}"
  if version="$("$bin" --version 2>/dev/null | head -n1)" && [[ -n "$version" ]]; then
    ok "versão: ${version}"
  else
    bad "versão não recuperável (nanobot --version falhou)"
  fi

  # Estado do gateway pelo comando oficial. Processo existir não é saúde.
  if gw="$("$bin" gateway status 2>&1)"; then
    ok "gateway: $(printf '%s' "$gw" | head -n1)"
  else
    soft "gateway não está ativo ou não foi configurado"
  fi
else
  bad "nanobot não encontrado (PATH, \$NANOBOT_BIN ou ~/.local/bin)"
fi

home_dir="$(assistant_home)"
if [[ -d "${NANOBOT_HOME:-${home_dir}/.nanobot}" ]]; then
  ok "diretório de configuração: ${NANOBOT_HOME:-${home_dir}/.nanobot}"
else
  soft "diretório de configuração do Nanobot ainda não existe"
fi

# --- 2. Brain --------------------------------------------------------------
[[ "$QUIET" == "1" ]] || printf '\nBrain\n'
if [[ -d "$BRAIN_DIR" ]]; then
  ok "diretório: ${BRAIN_DIR}"
  [[ -f "${BRAIN_DIR}/INDEX.md" ]] && ok "INDEX.md presente" || bad "INDEX.md ausente"
  [[ -f "${BRAIN_DIR}/70-skills/INDEX.md" ]] \
    && ok "índice de Skills presente" || bad "70-skills/INDEX.md ausente"
  [[ -r "$BRAIN_DIR" ]] && ok "legível" || bad "sem permissão de leitura"

  owner="$(stat -c '%U' "$BRAIN_DIR" 2>/dev/null || echo '?')"
  if [[ "$owner" == "$ASSISTANT_USER" ]]; then
    ok "dono: ${owner}"
  elif [[ "$owner" == "root" ]]; then
    soft "brain pertence a root; o runtime não deve rodar como root"
  else
    soft "dono do brain: ${owner} (esperado: ${ASSISTANT_USER})"
  fi

  if command -v python3 >/dev/null 2>&1 && [[ -f "${SCRIPT_DIR}/validate_structure.py" ]]; then
    if python3 "${SCRIPT_DIR}/validate_structure.py" --brain "$BRAIN_DIR" >/dev/null 2>&1; then
      ok "estrutura válida"
    else
      bad "validate_structure.py reprovou o brain"
    fi
  fi
else
  bad "brain não encontrado: ${BRAIN_DIR}"
fi

# --- 3. Controle de acesso --------------------------------------------------
# Nenhuma mensagem é enviada: só leitura do config.
[[ "$QUIET" == "1" ]] || printf '\nAcesso\n'
nb_config="${NANOBOT_CONFIG:-$(assistant_home)/.nanobot/config.json}"
checker="${SCRIPT_DIR}/lib/check_access.py"
if [[ ! -f "$nb_config" ]]; then
  soft "config do Nanobot ausente: ${nb_config}"
elif [[ ! -f "$checker" ]] || ! command -v python3 >/dev/null 2>&1; then
  soft "verificação de acesso indisponível"
else
  access_rc=0
  access_out="$(python3 "$checker" "$nb_config" 2>&1)" || access_rc=$?
  while IFS=$'\t' read -r ch state detail; do
    [[ -n "$ch" ]] || continue
    case "$state" in
      OK)       ok "${ch}: ${detail}" ;;
      DISABLED) ok "${ch}: desabilitado" ;;
      ERROR)    bad "${ch}: ${detail}" ;;
      *)        soft "${ch}: ${detail}" ;;
    esac
  done <<< "$access_out"
  [[ $access_rc -eq 2 ]] && bad "acesso aberto detectado; corrija antes de operar"
fi

# --- 4. n8n ----------------------------------------------------------------
[[ "$QUIET" == "1" ]] || printf '\nn8n\n'
if [[ -z "${N8N_BASE_URL:-}" ]]; then
  soft "N8N_BASE_URL não configurado; verificação pulada"
elif ! command -v curl >/dev/null 2>&1; then
  soft "curl ausente; verificação do n8n pulada"
else
  ping_url="${N8N_BASE_URL%/}/webhook/ping"
  body_file="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$body_file'" EXIT
  status="$(curl -fsS -m "${HEALTHCHECK_TIMEOUT:-10}" -o "$body_file" -w '%{http_code}' \
            "$ping_url" 2>/dev/null || echo "000")"
  if [[ "$status" == "200" ]]; then
    ok "ping: HTTP 200"
    if command -v python3 >/dev/null 2>&1; then
      if python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$body_file" 2>/dev/null; then
        ok "resposta é JSON válido"
      else
        soft "resposta não é JSON (não é falha: só o status 200 é exigido)"
      fi
    fi
  elif [[ "$status" == "000" ]]; then
    bad "ping: sem resposta (rede, DNS ou serviço fora)"
  else
    bad "ping: HTTP ${status} (esperado 200)"
  fi
fi

# --- 5. Diretórios operacionais -------------------------------------------
[[ "$QUIET" == "1" ]] || printf '\nDiretórios\n'
for d in "$RUNTIME_DIR" "$BACKUP_DIR" "$CONFIG_DIR"; do
  [[ -d "$d" ]] && ok "$d" || soft "ausente: $d"
done
if [[ -f "$CONFIG_FILE" ]]; then
  perms="$(stat -c '%a' "$CONFIG_FILE" 2>/dev/null || echo '?')"
  [[ "$perms" == "600" || "$perms" == "640" ]] \
    && ok "assistant.env com permissão ${perms}" \
    || soft "assistant.env com permissão ${perms} (esperado 600)"
else
  soft "assistant.env ausente: ${CONFIG_FILE}"
fi

# --- resumo ----------------------------------------------------------------
printf '\n'
if [[ $failures -gt 0 ]]; then
  printf 'Healthcheck: %d falha(s), %d aviso(s).\n' "$failures" "$warnings" >&2
  exit 1
fi
if [[ $warnings -gt 0 ]]; then
  printf 'Healthcheck: ok, com %d aviso(s).\n' "$warnings"
  exit 2
fi
printf 'Healthcheck: ok.\n'
