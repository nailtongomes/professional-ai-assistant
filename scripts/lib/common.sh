#!/usr/bin/env bash
# Funções compartilhadas pelos scripts de ciclo de vida.
# Uso: source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
#
# Não é um framework. Só o que mais de um script precisa.

# ---------------------------------------------------------------- paths ----
# ASSISTANT_PREFIX permite testar tudo dentro de um diretório temporário.
# Em produção fica vazio e os paths são os absolutos documentados.
: "${ASSISTANT_PREFIX:=}"

: "${REPO_DIR:=${ASSISTANT_PREFIX}/opt/professional-ai-assistant/repo}"
: "${BRAIN_DIR:=${ASSISTANT_PREFIX}/srv/professional-ai-assistant/brain}"
: "${RUNTIME_DIR:=${ASSISTANT_PREFIX}/var/lib/professional-ai-assistant/runtime}"
: "${CONFIG_DIR:=${ASSISTANT_PREFIX}/etc/professional-ai-assistant}"
: "${CONFIG_FILE:=${CONFIG_DIR}/assistant.env}"
: "${BACKUP_DIR:=${ASSISTANT_PREFIX}/var/backups/professional-ai-assistant}"
: "${LOG_DIR:=${ASSISTANT_PREFIX}/var/log/professional-ai-assistant}"
: "${LOCK_FILE:=${ASSISTANT_PREFIX}/var/lock/professional-ai-assistant.lock}"

# Diretórios sob os quais escrita e remoção são permitidas. Qualquer path
# destrutivo é validado contra esta lista antes de ser tocado.
ASSISTANT_SAFE_ROOTS=(
  "$BRAIN_DIR" "$RUNTIME_DIR" "$CONFIG_DIR" "$BACKUP_DIR" "$LOG_DIR" "$REPO_DIR"
)

: "${DRY_RUN:=0}"
: "${ASSISTANT_USER:=assistant}"

# ------------------------------------------------------------------ log ----
_ts()  { date -u +%Y-%m-%dT%H:%M:%SZ; }
log()  { printf '[%s] %s\n' "$(_ts)" "$*"; }
warn() { printf '[%s] AVISO: %s\n' "$(_ts)" "$*" >&2; }
die()  { printf '[%s] ERRO: %s\n' "$(_ts)" "$*" >&2; exit 1; }

# Timestamp usado em nomes de backup: 2026-08-21T143500Z
backup_stamp() { date -u +%Y-%m-%dT%H%M%SZ; }

# ------------------------------------------------------------- dry-run ----
is_dry_run() { [[ "$DRY_RUN" == "1" ]]; }

# run: executa, ou apenas imprime em dry-run.
run() {
  if is_dry_run; then
    printf '[dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

# Consome --dry-run/-n dos argumentos e devolve o resto em ASSISTANT_ARGS.
parse_common_flags() {
  ASSISTANT_ARGS=()
  local a
  for a in "$@"; do
    case "$a" in
      --dry-run|-n) DRY_RUN=1 ;;
      *) ASSISTANT_ARGS+=("$a") ;;
    esac
  done
}

# --------------------------------------------------------- pré-requisitos --
require_command() {
  local cmd="$1" hint="${2:-}"
  command -v "$cmd" >/dev/null 2>&1 && return 0
  die "comando ausente: ${cmd}${hint:+ — $hint}"
}

require_linux() {
  [[ "$(uname -s)" == "Linux" ]] || die "este script só roda em Linux (detectado: $(uname -s))"
}

require_root() {
  if is_dry_run; then
    [[ "${EUID:-$(id -u)}" -eq 0 ]] || warn "sem root: o dry-run segue, mas a execução real exige sudo"
    return 0
  fi
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "execute com sudo"
}

# ------------------------------------------------------ validação de path --
# Recusa path vazio, relativo, raiz, ou fora das raízes seguras.
# Chame antes de QUALQUER remoção ou escrita em massa.
assert_safe_path() {
  local path="$1" root resolved
  [[ -n "$path" ]]            || die "path vazio recusado"
  [[ "$path" == /* ]]         || die "path relativo recusado: $path"
  [[ "$path" != */.. && "$path" != *"/../"* ]] || die "path com .. recusado: $path"

  case "$path" in
    /|/bin|/boot|/dev|/etc|/home|/lib|/proc|/root|/run|/sbin|/srv|/sys|/usr|/var)
      die "path de sistema recusado: $path" ;;
  esac

  # Normaliza sem exigir que exista (o pai precisa existir).
  resolved="$(readlink -m -- "$path")" || die "não foi possível resolver: $path"

  for root in "${ASSISTANT_SAFE_ROOTS[@]}"; do
    [[ -n "$root" ]] || continue
    root="$(readlink -m -- "$root")"
    [[ "$resolved" == "$root" || "$resolved" == "$root"/* ]] && return 0
  done
  die "path fora das raízes gerenciadas: $path"
}

# Remoção protegida: só dentro das raízes seguras, nunca a própria raiz.
safe_remove() {
  local target="$1" root
  assert_safe_path "$target"
  for root in "${ASSISTANT_SAFE_ROOTS[@]}"; do
    [[ "$(readlink -m -- "$target")" == "$(readlink -m -- "$root")" ]] \
      && die "recusado: remoção da própria raiz $target"
  done
  [[ -e "$target" ]] || return 0
  run rm -rf -- "$target"
}

ensure_dir() {
  local dir="$1" mode="${2:-0755}" owner="${3:-}"
  assert_safe_path "$dir"
  [[ -d "$dir" ]] || run mkdir -p -- "$dir"
  run chmod "$mode" -- "$dir"
  [[ -n "$owner" ]] && run chown "$owner" -- "$dir"
  return 0
}

# ------------------------------------------------------------- ambiente ----
# Carrega o arquivo de configuração real. Nunca imprime valores.
load_env() {
  local file="${1:-$CONFIG_FILE}"
  if [[ ! -f "$file" ]]; then
    warn "configuração não encontrada: $file (seguindo com padrões)"
    return 0
  fi
  # shellcheck disable=SC1090
  set -a; . "$file"; set +a
  log "configuração carregada: $file"
}

# ------------------------------------------------------------------ lock ---
# Impede install/update/restore concorrentes. Sem flock, segue com aviso.
acquire_lock() {
  local who="${1:-lifecycle}"
  if is_dry_run; then
    log "dry-run: lock não adquirido"
    return 0
  fi
  if ! command -v flock >/dev/null 2>&1; then
    warn "flock ausente: seguindo sem trava de concorrência"
    return 0
  fi
  ensure_dir "$(dirname "$LOCK_FILE")" 0755 >/dev/null 2>&1 || true
  exec 9>"$LOCK_FILE" || die "não foi possível abrir o lock: $LOCK_FILE"
  flock -n 9 || die "outra operação em andamento (lock: $LOCK_FILE)"
  log "lock adquirido por ${who}"
}

# ------------------------------------------------------------- versões -----
# Versão do template = commit do repositório controlado.
template_version() {
  local dir="${1:-$REPO_DIR}"
  if [[ -d "$dir/.git" ]] && command -v git >/dev/null 2>&1; then
    git -C "$dir" rev-parse --short HEAD 2>/dev/null || echo "unknown"
  else
    echo "unknown"
  fi
}

# Caminho do nanobot: o instalador oficial NÃO garante PATH.
# Ordem: NANOBOT_BIN explícito → PATH → wrapper padrão do instalador.
nanobot_bin() {
  if [[ -n "${NANOBOT_BIN:-}" && -x "${NANOBOT_BIN}" ]]; then
    printf '%s\n' "$NANOBOT_BIN"; return 0
  fi
  if command -v nanobot >/dev/null 2>&1; then
    command -v nanobot; return 0
  fi
  local home_dir
  home_dir="$(assistant_home)"
  local candidate="${NANOBOT_BIN_DIR:-${home_dir}/.local/bin}/nanobot"
  [[ -x "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
  return 1
}

nanobot_version() {
  local bin
  bin="$(nanobot_bin)" || { echo "not-installed"; return 1; }
  "$bin" --version 2>/dev/null | head -n1 || echo "unknown"
}

assistant_home() {
  if [[ -n "${ASSISTANT_HOME:-}" ]]; then printf '%s\n' "$ASSISTANT_HOME"; return 0; fi
  getent passwd "$ASSISTANT_USER" 2>/dev/null | cut -d: -f6 | grep . \
    || printf '%s\n' "/home/${ASSISTANT_USER}"
}
