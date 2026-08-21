#!/usr/bin/env bash
#
# Backup dos dados insubstituíveis: brain, manifestos e metadados de versão.
#
#   ./scripts/backup.sh [--dry-run] [--retention-days N] [--include-secrets]
#
# Por padrão NÃO inclui secrets, cache, logs, venv nem checkout Git.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

INCLUDE_SECRETS=0
RETENTION_OVERRIDE=""

usage() {
  cat <<'USAGE'
Uso: backup.sh [--dry-run] [--retention-days N] [--include-secrets]

  --dry-run           mostra o que seria feito; não cria nem remove nada
  --retention-days N  sobrepõe BACKUP_RETENTION_DAYS
  --include-secrets   inclui o assistant.env no backup (decisão explícita:
                      o arquivo resultante passa a conter credenciais)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=1 ;;
    --include-secrets) INCLUDE_SECRETS=1 ;;
    --retention-days) RETENTION_OVERRIDE="${2:?--retention-days exige um número}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; die "argumento desconhecido: $1" ;;
  esac
  shift
done

load_env
: "${BACKUP_RETENTION_DAYS:=14}"
[[ -n "$RETENTION_OVERRIDE" ]] && BACKUP_RETENTION_DAYS="$RETENTION_OVERRIDE"
[[ "$BACKUP_RETENTION_DAYS" =~ ^[0-9]+$ ]] || die "BACKUP_RETENTION_DAYS inválido: $BACKUP_RETENTION_DAYS"

require_command tar
[[ -d "$BRAIN_DIR" ]] || die "brain não encontrado: $BRAIN_DIR"

STAMP="$(backup_stamp)"
DEST="${BACKUP_DIR}/${STAMP}"
assert_safe_path "$DEST"

log "backup → ${DEST}"
is_dry_run && log "modo dry-run: nada será criado nem removido"

ensure_dir "$BACKUP_DIR" 0700 >/dev/null
# Escreve em .partial e renomeia no fim: um diretório com nome final só existe
# quando o backup está completo.
STAGING="${DEST}.partial"
assert_safe_path "$STAGING"
ensure_dir "$STAGING" 0700 >/dev/null

# --- brain -----------------------------------------------------------------
BRAIN_ARCHIVE="${STAGING}/brain.tar.gz"
if is_dry_run; then
  log "[dry-run] tar czf ${BRAIN_ARCHIVE} -C $(dirname "$BRAIN_DIR") $(basename "$BRAIN_DIR")"
else
  # As exclusões precisam vir ANTES do path, ou o tar as ignora.
  tar czf "$BRAIN_ARCHIVE" \
    --exclude='.stfolder' --exclude='.stversions' --exclude='*.sync-conflict-*' \
    --exclude='.obsidian' --exclude='.git' \
    -C "$(dirname "$BRAIN_DIR")" "$(basename "$BRAIN_DIR")" \
    || die "falha ao empacotar o brain"
fi

# --- manifestos e estado ---------------------------------------------------
for extra in "${SCRIPT_DIR}/../config/managed-paths.txt" "${RUNTIME_DIR}/managed-state.sha256"; do
  [[ -f "$extra" ]] && run cp -- "$extra" "${STAGING}/$(basename "$extra")"
done

# --- secrets: fora, salvo decisão explícita --------------------------------
if [[ "$INCLUDE_SECRETS" == "1" ]]; then
  warn "--include-secrets: o backup conterá credenciais. Proteja o destino."
  [[ -f "$CONFIG_FILE" ]] && run cp -- "$CONFIG_FILE" "${STAGING}/assistant.env"
else
  log "secrets NÃO incluídos (padrão)"
fi

# --- manifest --------------------------------------------------------------
brain_files="$( [[ -d "$BRAIN_DIR" ]] && find "$BRAIN_DIR" -type f | wc -l || echo 0 )"
manifest_body="$(cat <<MANIFEST
timestamp: ${STAMP}
template_commit: $(template_version)
nanobot_version: $(nanobot_version 2>/dev/null || echo not-installed)
brain_dir: ${BRAIN_DIR}
brain_files: ${brain_files}
secrets_included: $([[ "$INCLUDE_SECRETS" == "1" ]] && echo yes || echo no)
retention_days: ${BACKUP_RETENTION_DAYS}
contents:
  - brain.tar.gz
$([[ -f "${SCRIPT_DIR}/../config/managed-paths.txt" ]] && echo "  - managed-paths.txt")
$([[ -f "${RUNTIME_DIR}/managed-state.sha256" ]] && echo "  - managed-state.sha256")
$([[ "$INCLUDE_SECRETS" == "1" ]] && echo "  - assistant.env")
MANIFEST
)"

if is_dry_run; then
  printf '[dry-run] manifest:\n%s\n' "$manifest_body"
else
  printf '%s\n' "$manifest_body" > "${STAGING}/manifest.txt"
  ( cd "$STAGING" && sha256sum ./* > SHA256SUMS 2>/dev/null ) || warn "não foi possível gerar SHA256SUMS"
  mv -- "$STAGING" "$DEST"
  chmod 0700 -- "$DEST"
fi

# --- retenção --------------------------------------------------------------
# Só remove diretórios com nome de timestamp, dentro de BACKUP_DIR, e nunca em
# dry-run. Cada candidato passa por assert_safe_path antes de sumir.
if is_dry_run; then
  log "[dry-run] retenção não executada (${BACKUP_RETENTION_DAYS} dias)"
else
  pruned=0
  while IFS= read -r -d '' old; do
    case "$(basename "$old")" in
      [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z) ;;
      *) continue ;;
    esac
    assert_safe_path "$old"
    safe_remove "$old"
    pruned=$((pruned + 1))
  done < <(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d \
             -mtime "+${BACKUP_RETENTION_DAYS}" -print0 2>/dev/null)
  [[ $pruned -gt 0 ]] && log "retenção: ${pruned} backup(s) antigo(s) removido(s)"
fi

log "backup concluído: ${DEST}"
printf '%s\n' "$DEST"
