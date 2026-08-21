#!/usr/bin/env bash
#
# Sincroniza os arquivos GERENCIADOS do template para o brain operacional.
#
#   ./scripts/sync.sh [--dry-run] [--force] [--manifest PATH]
#
# Nunca apaga nada. Nunca toca em arquivo fora de config/managed-paths.txt.
# Arquivo gerenciado modificado localmente vira CONFLITO, não sobrescrita.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

MANIFEST="${SCRIPT_DIR}/../config/managed-paths.txt"
SOURCE_BRAIN=""
FORCE=0

usage() {
  cat <<'USAGE'
Uso: sync.sh [--dry-run] [--force] [--manifest PATH] [--source PATH]

  --dry-run     mostra o que mudaria, sem escrever
  --force       sobrescreve arquivos gerenciados em conflito (faz backup antes)
  --manifest    manifesto alternativo de paths gerenciados
  --source      brain de origem (padrão: <repo>/brain)
USAGE
}

args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=1 ;;
    --force) FORCE=1 ;;
    --manifest) MANIFEST="${2:?--manifest exige um path}"; shift ;;
    --source) SOURCE_BRAIN="${2:?--source exige um path}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) args+=("$1") ;;
  esac
  shift
done
[[ ${#args[@]} -eq 0 ]] || { usage; die "argumento desconhecido: ${args[0]}"; }

load_env
[[ -n "$SOURCE_BRAIN" ]] || SOURCE_BRAIN="${REPO_DIR}/brain"

[[ -f "$MANIFEST" ]]      || die "manifesto não encontrado: $MANIFEST"
[[ -d "$SOURCE_BRAIN" ]]  || die "brain de origem não encontrado: $SOURCE_BRAIN"
if [[ ! -d "$BRAIN_DIR" ]]; then
  is_dry_run || die "brain de destino não encontrado: $BRAIN_DIR (rode install.sh)"
  log "dry-run: brain de destino ainda não existe (${BRAIN_DIR}); tudo apareceria como novo"
fi

STATE_FILE="${RUNTIME_DIR}/managed-state.sha256"
CONFLICT_DIR="${BACKUP_DIR}/conflicts/$(backup_stamp)"

installed=0; updated=0; unchanged=0; conflicts=0
conflict_list=()

sha_of() { sha256sum -- "$1" 2>/dev/null | awk '{print $1}'; }

recorded_sha() {
  local rel="$1"
  [[ -f "$STATE_FILE" ]] || return 1
  awk -v k="$rel" '$2 == k {print $1; found=1} END {exit !found}' "$STATE_FILE"
}

# Expande o manifesto em uma lista de arquivos relativos ao brain.
managed_files() {
  local entry
  while IFS= read -r entry; do
    entry="${entry%%#*}"
    entry="$(printf '%s' "$entry" | tr -d '[:space:]')"
    [[ -n "$entry" ]] || continue
    case "$entry" in
      /*|*..*) warn "entrada inválida no manifesto, ignorada: $entry"; continue ;;
    esac
    if [[ "$entry" == */ ]]; then
      local dir="${SOURCE_BRAIN}/${entry%/}"
      [[ -d "$dir" ]] || { warn "diretório gerenciado ausente na origem: $entry"; continue; }
      ( cd "$SOURCE_BRAIN" && find "${entry%/}" -type f -print )
    else
      [[ -f "${SOURCE_BRAIN}/${entry}" ]] \
        && printf '%s\n' "$entry" \
        || warn "arquivo gerenciado ausente na origem: $entry"
    fi
  done < "$MANIFEST" | sort -u
}

apply_file() {
  local rel="$1" src="${SOURCE_BRAIN}/$1" dst="${BRAIN_DIR}/$1"
  assert_safe_path "$dst"
  ensure_dir "$(dirname "$dst")" >/dev/null
  run cp -- "$src" "$dst"
}

log "sync: ${SOURCE_BRAIN} → ${BRAIN_DIR}"
is_dry_run && log "modo dry-run: nada será escrito"

new_state=""
while IFS= read -r rel; do
  [[ -n "$rel" ]] || continue
  src="${SOURCE_BRAIN}/${rel}"
  dst="${BRAIN_DIR}/${rel}"
  src_sha="$(sha_of "$src")"

  if [[ ! -e "$dst" ]]; then
    log "novo      ${rel}"
    apply_file "$rel"; installed=$((installed + 1))
    new_state+="${src_sha}  ${rel}"$'\n'
    continue
  fi

  dst_sha="$(sha_of "$dst")"
  if [[ "$src_sha" == "$dst_sha" ]]; then
    unchanged=$((unchanged + 1))
    new_state+="${src_sha}  ${rel}"$'\n'
    continue
  fi

  # Difere. O destino ainda está como o último sync deixou?
  prev_sha="$(recorded_sha "$rel" || true)"
  if [[ -n "$prev_sha" && "$prev_sha" == "$dst_sha" ]]; then
    log "atualiza  ${rel}"
    apply_file "$rel"; updated=$((updated + 1))
    new_state+="${src_sha}  ${rel}"$'\n'
    continue
  fi

  # Modificado localmente E alterado no template: conflito.
  if [[ "$FORCE" == "1" ]]; then
    ensure_dir "$CONFLICT_DIR" >/dev/null
    log "conflito  ${rel} (--force: backup em ${CONFLICT_DIR})"
    ensure_dir "$(dirname "${CONFLICT_DIR}/${rel}")" >/dev/null
    run cp -- "$dst" "${CONFLICT_DIR}/${rel}"
    apply_file "$rel"; updated=$((updated + 1))
    new_state+="${src_sha}  ${rel}"$'\n'
  else
    warn "CONFLITO  ${rel} — modificado localmente e alterado no template"
    conflict_list+=("$rel")
    conflicts=$((conflicts + 1))
    # NÃO registrar o sha local do arquivo em conflito: se registrássemos, o
    # próximo sync veria "destino igual ao último aplicado" e sobrescreveria a
    # alteração local em silêncio. Preserva-se o registro anterior, se houver.
    [[ -n "$prev_sha" ]] && new_state+="${prev_sha}  ${rel}"$'\n'
  fi
done < <(managed_files)

if ! is_dry_run; then
  ensure_dir "$RUNTIME_DIR" >/dev/null
  printf '%s' "$new_state" > "$STATE_FILE"
fi

log "sync: ${installed} novo(s), ${updated} atualizado(s), ${unchanged} sem mudança, ${conflicts} conflito(s)"

if [[ $conflicts -gt 0 ]]; then
  printf '\nArquivos em conflito (nada foi sobrescrito):\n' >&2
  printf '  %s\n' "${conflict_list[@]}" >&2
  cat >&2 <<'MSG'

Resolva manualmente. Nenhum processo automático deve escolher qual versão de
PHILOSOPHY.md, agent-rules.md ou de uma Skill prevalece.

  diff <brain>/<arquivo> <repo>/brain/<arquivo>

Depois, ou ajuste o arquivo local e rode o sync de novo, ou aceite a versão do
template com:  sync.sh --force   (o arquivo local vai para backup antes)
MSG
  exit 3
fi
