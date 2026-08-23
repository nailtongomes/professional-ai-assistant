#!/usr/bin/env bash
#
# Instala o Hermes Agent. Só roda quando ASSISTANT_RUNTIME=hermes.
#
#   runtime-adapters/hermes/install.sh --dry-run
#   runtime-adapters/hermes/install.sh
#
# Não instala Nanobot. Não toca no brain.
set -Eeuo pipefail

ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${ADAPTER_DIR}/../.." && pwd)"
# shellcheck source=../../scripts/lib/common.sh
. "${REPO_ROOT}/scripts/lib/common.sh"

HERMES_INSTALLER_URL="https://hermes-agent.nousresearch.com/install.sh"

usage() { echo "Uso: install.sh [--dry-run]"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; die "argumento desconhecido: $1" ;;
  esac
  shift
done

load_env
[[ "${ASSISTANT_RUNTIME:-nanobot}" == "hermes" ]] \
  || die "ASSISTANT_RUNTIME=${ASSISTANT_RUNTIME:-nanobot}; este adapter só roda com 'hermes'"

require_linux
HOME_DIR="$(assistant_home)"
HERMES_STATE="${RUNTIME_DIR}/hermes"

log "instalando Hermes Agent para o usuário ${ASSISTANT_USER}"
is_dry_run && log "modo dry-run: nada será executado"

ensure_dir "$HERMES_STATE" 0750 "${ASSISTANT_USER}:${ASSISTANT_USER}" >/dev/null

if command -v hermes >/dev/null 2>&1 \
   || [[ -x "${HERMES_HOME:-${HOME_DIR}/.hermes}/bin/hermes" ]]; then
  log "Hermes já instalado; use 'hermes update' para atualizar"
  exit 0
fi

# TRUST BOUNDARY: instalador remoto de terceiro, igual ao do Nanobot. Baixamos
# para arquivo e deixamos o operador auditar; não canalizamos curl para bash.
installer="$(mktemp /tmp/hermes-install.XXXXXX.sh)"
if is_dry_run; then
  log "[dry-run] curl -fsSL ${HERMES_INSTALLER_URL} -o ${installer}"
  log "[dry-run] revisar ${installer} e executá-lo como ${ASSISTANT_USER}"
  exit 0
fi

require_command curl
log "baixando instalador oficial"
curl -fsSL "$HERMES_INSTALLER_URL" -o "$installer" \
  || die "não foi possível baixar o instalador do Hermes"
[[ -s "$installer" ]] || die "instalador do Hermes veio vazio"
chmod 0755 -- "$installer"

warn "o instalador do Hermes é código de terceiro; revise antes de prosseguir:"
warn "  less ${installer}"

log "executando como ${ASSISTANT_USER} (nunca como root)"
runuser -u "$ASSISTANT_USER" -- env HOME="$HOME_DIR" bash "$installer" \
  || die "a instalação do Hermes falhou"
rm -f -- "$installer"

log "Hermes instalado; configure com: python3 ${ADAPTER_DIR}/configure.py"
