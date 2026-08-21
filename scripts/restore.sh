#!/usr/bin/env bash
#
# Restaura o brain a partir de um backup. Operação de ALTO RISCO.
#
#   sudo ./scripts/restore.sh --dry-run /var/backups/professional-ai-assistant/<stamp>
#   sudo ./scripts/restore.sh           /var/backups/professional-ai-assistant/<stamp>
#
# Sempre faz backup do estado atual antes de sobrescrever.
# Nunca restaura secrets sem pedido explícito. Nunca assume confirmação.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

ASSUME_YES=0
RESTORE_SECRETS=0
BACKUP_PATH=""

usage() {
  cat <<'USAGE'
Uso: sudo restore.sh [--dry-run] [--yes] [--restore-secrets] <caminho-do-backup>

  --dry-run           mostra o que seria restaurado; não altera nada
  --yes               pula a confirmação interativa (para automação)
  --restore-secrets   também restaura assistant.env, se existir no backup
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    --restore-secrets) RESTORE_SECRETS=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) usage; die "argumento desconhecido: $1" ;;
    *) [[ -z "$BACKUP_PATH" ]] || die "informe apenas um backup"; BACKUP_PATH="$1" ;;
  esac
  shift
done

[[ -n "$BACKUP_PATH" ]] || { usage; die "informe o backup a restaurar"; }

require_linux
require_root
acquire_lock restore
load_env

# --- validação do backup ----------------------------------------------------
BACKUP_PATH="$(readlink -m -- "$BACKUP_PATH")"
assert_safe_path "$BACKUP_PATH"
[[ -d "$BACKUP_PATH" ]] || die "backup não encontrado: $BACKUP_PATH"

ARCHIVE="${BACKUP_PATH}/brain.tar.gz"
MANIFEST="${BACKUP_PATH}/manifest.txt"
[[ -f "$ARCHIVE" ]]  || die "backup inválido: brain.tar.gz ausente"
[[ -f "$MANIFEST" ]] || warn "backup sem manifest.txt"

log "verificando integridade do arquivo"
tar tzf "$ARCHIVE" >/dev/null 2>&1 || die "backup corrompido: brain.tar.gz ilegível"

if [[ -f "${BACKUP_PATH}/SHA256SUMS" ]]; then
  if ( cd "$BACKUP_PATH" && sha256sum -c --quiet SHA256SUMS 2>/dev/null ); then
    log "checksums conferem"
  else
    warn "checksums não conferem — inspecione o backup antes de prosseguir"
  fi
fi

file_count="$(tar tzf "$ARCHIVE" | grep -c '[^/]$' || true)"

# --- o que será restaurado --------------------------------------------------
cat <<PLAN

Backup:  ${BACKUP_PATH}
Destino: ${BRAIN_DIR}
Arquivos no pacote: ${file_count}

$( [[ -f "$MANIFEST" ]] && sed 's/^/  /' "$MANIFEST" )

Será feito:
  1. backup do estado atual do brain
  2. substituição do conteúdo de ${BRAIN_DIR} pelo conteúdo do pacote
  3. ajuste de dono para ${ASSISTANT_USER}
$( [[ "$RESTORE_SECRETS" == "1" ]] \
   && echo "  4. restauração de assistant.env (--restore-secrets)" \
   || echo "  4. secrets NÃO serão restaurados" )
PLAN

if is_dry_run; then
  log "dry-run: nada foi alterado"
  exit 0
fi

# --- confirmação ------------------------------------------------------------
if [[ "$ASSUME_YES" != "1" ]]; then
  printf '\nEsta operação substitui o brain ativo. Digite RESTORE para confirmar: '
  read -r answer
  [[ "$answer" == "RESTORE" ]] || die "confirmação não recebida; nada foi alterado"
fi

# --- backup do estado atual -------------------------------------------------
log "backup do estado atual antes de sobrescrever"
CURRENT_BACKUP="$("${SCRIPT_DIR}/backup.sh" | tail -n1)" \
  || die "não foi possível salvar o estado atual; restore abortado"
log "estado atual salvo em: ${CURRENT_BACKUP}"

# --- restauração ------------------------------------------------------------
# Extrai para um diretório temporário ao lado do brain e troca por rename.
# Sem rm -rf do brain: o diretório antigo é preservado até o fim.
STAGING="${BRAIN_DIR}.restore.$(backup_stamp)"
PREVIOUS="${BRAIN_DIR}.previous.$(backup_stamp)"
assert_safe_path "$STAGING"
assert_safe_path "$PREVIOUS"

mkdir -p -- "$STAGING"
tar xzf "$ARCHIVE" -C "$STAGING" || die "falha ao extrair o backup"

# O pacote contém o diretório do brain na raiz.
inner="$(find "$STAGING" -mindepth 1 -maxdepth 1 -type d | head -n1)"
[[ -n "$inner" ]] || die "estrutura inesperada no backup"

log "substituindo o brain"
mv -- "$BRAIN_DIR" "$PREVIOUS"
mv -- "$inner" "$BRAIN_DIR"
rmdir -- "$STAGING" 2>/dev/null || true
chown -R "${ASSISTANT_USER}:${ASSISTANT_USER}" -- "$BRAIN_DIR"

if [[ "$RESTORE_SECRETS" == "1" && -f "${BACKUP_PATH}/assistant.env" ]]; then
  log "restaurando assistant.env"
  cp -- "${BACKUP_PATH}/assistant.env" "$CONFIG_FILE"
  chmod 0600 -- "$CONFIG_FILE"
elif [[ "$RESTORE_SECRETS" == "1" ]]; then
  warn "--restore-secrets pedido, mas o backup não contém assistant.env"
fi

# --- verificação ------------------------------------------------------------
health_rc=0
"${SCRIPT_DIR}/healthcheck.sh" || health_rc=$?

cat <<SUMMARY

Restore concluído
  restaurado de   ${BACKUP_PATH}
  brain anterior  ${PREVIOUS}   (mantido; remova quando tiver certeza)
  backup do atual ${CURRENT_BACKUP}
SUMMARY

[[ $health_rc -eq 1 ]] && die "healthcheck reprovou após o restore; o brain anterior segue em ${PREVIOUS}"
exit 0
