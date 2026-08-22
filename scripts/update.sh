#!/usr/bin/env bash
#
# Atualiza template, arquivos gerenciados e runtime — nessa ordem, parando na
# primeira falha crítica.
#
#   sudo ./scripts/update.sh --dry-run
#   sudo ./scripts/update.sh
#
# Sempre faz backup antes. Sem backup, sem update.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

SKIP_NANOBOT=0
BACKUP_PATH=""
STAGE="preflight"

usage() {
  cat <<'USAGE'
Uso: sudo update.sh [--dry-run] [--skip-nanobot]

  --dry-run       mostra o que mudaria, sem alterar estado
  --skip-nanobot  atualiza template e arquivos gerenciados, não o runtime
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=1 ;;
    --skip-nanobot) SKIP_NANOBOT=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; die "argumento desconhecido: $1" ;;
  esac
  shift
done

# Em qualquer falha, diz onde parou e onde está o backup. Nunca afirma que
# houve rollback: rollback é o restore, e é operação humana.
on_failure() {
  local code=$?
  printf '\n' >&2
  printf 'UPDATE FALHOU na etapa: %s (código %d)\n' "$STAGE" "$code" >&2
  if [[ -n "$BACKUP_PATH" ]]; then
    printf 'Backup criado antes das alterações: %s\n' "$BACKUP_PATH" >&2
    printf 'Versão anterior do template: %s\n' "${PREV_VERSION:-desconhecida}" >&2
    printf 'Nenhum rollback automático foi executado. Para restaurar:\n' >&2
    printf '  sudo %s/restore.sh --dry-run %s\n' "$SCRIPT_DIR" "$BACKUP_PATH" >&2
    printf '  sudo %s/restore.sh %s\n' "$SCRIPT_DIR" "$BACKUP_PATH" >&2
    printf 'Detalhes: docs/RESTORE.md\n' >&2
  else
    printf 'Nenhuma alteração de estado havia sido feita.\n' >&2
  fi
  exit "$code"
}
trap on_failure ERR

require_linux
require_root
acquire_lock update
load_env
is_dry_run && log "modo dry-run: nenhuma alteração será gravada"

# --- preflight --------------------------------------------------------------
STAGE="preflight"
log "preflight"
[[ -d "$BRAIN_DIR" ]] || die "brain não encontrado: ${BRAIN_DIR} (rode install.sh)"
require_command git
require_command tar

CHECKOUT="$REPO_DIR"
[[ -d "${CHECKOUT}/.git" ]] || CHECKOUT="$(cd "${SCRIPT_DIR}/.." && pwd)"
[[ -d "${CHECKOUT}/.git" ]] || die "nenhum checkout Git encontrado para atualizar"

PREV_VERSION="$(template_version "$CHECKOUT")"
PREV_NANOBOT="$(nanobot_version 2>/dev/null || echo not-installed)"
log "template atual: ${PREV_VERSION} | nanobot: ${PREV_NANOBOT}"

# Alteração local no checkout controlado aborta o update: nada aqui deve
# sobrescrever trabalho não commitado.
if [[ -n "$(git -C "$CHECKOUT" status --porcelain)" ]]; then
  git -C "$CHECKOUT" status --short >&2
  die "Update aborted: repository has local changes."
fi

# --- backup -----------------------------------------------------------------
STAGE="backup"
log "backup antes de qualquer alteração"
backup_args=()
is_dry_run && backup_args+=(--dry-run)
if is_dry_run; then
  "${SCRIPT_DIR}/backup.sh" "${backup_args[@]}" >/dev/null || die "backup falhou"
  BACKUP_PATH="(dry-run)"
else
  BACKUP_PATH="$("${SCRIPT_DIR}/backup.sh" | tail -n1)" || die "backup falhou; update abortado"
  [[ -d "$BACKUP_PATH" ]] || die "backup não produziu diretório válido; update abortado"
fi
log "backup: ${BACKUP_PATH}"

# --- fetch ------------------------------------------------------------------
STAGE="fetch"
BRANCH="$(git -C "$CHECKOUT" rev-parse --abbrev-ref HEAD)"
log "fetch origin/${BRANCH}"
run git -C "$CHECKOUT" fetch --quiet origin "$BRANCH"

# --- validar atualização ----------------------------------------------------
STAGE="validar atualização"
if is_dry_run; then
  ahead="$(git -C "$CHECKOUT" rev-list --count "HEAD..origin/${BRANCH}" 2>/dev/null || echo 0)"
  log "[dry-run] ${ahead} commit(s) a aplicar em ${BRANCH}"
else
  ahead="$(git -C "$CHECKOUT" rev-list --count "HEAD..origin/${BRANCH}")"
  if [[ "$ahead" -eq 0 ]]; then
    log "template já está atualizado"
  else
    log "${ahead} commit(s) a aplicar"
  fi
fi

# --- aplicar ----------------------------------------------------------------
# Somente fast-forward. Sem merge automático, sem reset --hard, sem resolução
# automática de conflito.
STAGE="aplicar template"
if is_dry_run; then
  log "[dry-run] git -C ${CHECKOUT} pull --ff-only origin ${BRANCH}"
else
  git -C "$CHECKOUT" pull --ff-only origin "$BRANCH" \
    || die "pull não é fast-forward; resolva manualmente (nada foi alterado além do fetch)"
fi
NEW_VERSION="$(template_version "$CHECKOUT")"

# --- sincronizar ------------------------------------------------------------
STAGE="sincronizar arquivos gerenciados"
sync_args=(--source "${CHECKOUT}/brain")
is_dry_run && sync_args+=(--dry-run)
set +e
"${SCRIPT_DIR}/sync.sh" "${sync_args[@]}"
sync_rc=$?
set -e
if [[ $sync_rc -eq 3 ]]; then
  die "sync reportou conflito em arquivo gerenciado; resolva antes de prosseguir"
elif [[ $sync_rc -ne 0 ]]; then
  die "sync falhou (código ${sync_rc})"
fi

# --- runtime ----------------------------------------------------------------
STAGE="atualizar runtime"
RUNTIME="$(selected_runtime)"
log "runtime ativo: ${RUNTIME}"
if [[ "$RUNTIME" == "hermes" ]]; then
  # O Hermes tem mecanismo próprio de update. Só o runtime ativo é atualizado.
  if is_dry_run; then
    log "[dry-run] runuser -u ${ASSISTANT_USER} -- hermes update"
  elif command -v hermes >/dev/null 2>&1; then
    runuser -u "$ASSISTANT_USER" -- env HOME="$(assistant_home)" hermes update \
      || die "hermes update falhou"
  else
    warn "hermes não instalado; rode install.sh"
  fi
elif [[ "$SKIP_NANOBOT" == "1" ]]; then
  log "atualização do Nanobot pulada (--skip-nanobot)"
elif ! nanobot_bin >/dev/null 2>&1; then
  warn "Nanobot não instalado; rode install.sh"
else
  HOME_DIR="$(assistant_home)"
  installer="$(mktemp /tmp/nanobot-install.XXXXXX.sh)"
  if is_dry_run; then
    log "[dry-run] baixar e reexecutar o instalador oficial como ${ASSISTANT_USER}"
  else
    curl -fsSL "https://raw.githubusercontent.com/HKUDS/nanobot/main/scripts/install.sh" \
      -o "$installer" || die "não foi possível baixar o instalador do Nanobot"
    [[ -s "$installer" ]] || die "instalador do Nanobot veio vazio"
    runuser -u "$ASSISTANT_USER" -- env HOME="$HOME_DIR" NANOBOT_SKIP_WIZARD=1 \
      sh "$installer" || die "atualização do Nanobot falhou"
    rm -f -- "$installer"
  fi
fi
NEW_NANOBOT="$(nanobot_version 2>/dev/null || echo not-installed)"

# --- healthcheck ------------------------------------------------------------
STAGE="healthcheck"
health_rc=0
if is_dry_run; then
  log "dry-run: healthcheck pulado (nada foi alterado)"
else
  "${SCRIPT_DIR}/healthcheck.sh" || health_rc=$?
  [[ $health_rc -eq 1 ]] && die "healthcheck reprovou após o update"
fi

trap - ERR
cat <<SUMMARY

Update concluído$(is_dry_run && printf ' (dry-run: nada foi gravado)')
  template  ${PREV_VERSION} → ${NEW_VERSION}
  nanobot   ${PREV_NANOBOT} → ${NEW_NANOBOT}
  backup    ${BACKUP_PATH}
SUMMARY
