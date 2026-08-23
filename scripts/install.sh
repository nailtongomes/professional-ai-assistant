#!/usr/bin/env bash
#
# Instala a camada operacional do assistente. Idempotente: rodar dez vezes
# converge para o mesmo estado.
#
#   sudo ./scripts/install.sh --dry-run
#   sudo ./scripts/install.sh
#
# Nunca apaga brain, secrets ou dados do usuário.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

SKIP_NANOBOT=0

usage() {
  cat <<'USAGE'
Uso: sudo install.sh [--dry-run] [--skip-nanobot]

  --dry-run       mostra as operações sem executá-las
  --skip-nanobot  não instala o runtime (só estrutura, brain e config)
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

NANOBOT_INSTALLER_URL="https://raw.githubusercontent.com/HKUDS/nanobot/main/scripts/install.sh"

# 1. plataforma e privilégios ------------------------------------------------
require_linux
require_root
acquire_lock install
is_dry_run && log "modo dry-run: nenhuma alteração será gravada"

# 2. dependências mínimas ----------------------------------------------------
log "verificando dependências"
missing=()
for cmd in git curl tar sha256sum; do
  command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done

if [[ ${#missing[@]} -gt 0 ]]; then
  log "ausentes: ${missing[*]}"
  # Instala apenas git e curl, e apenas via gerenciador conhecido.
  installable=(); manual=()
  for m in "${missing[@]}"; do
    case "$m" in git|curl) installable+=("$m") ;; *) manual+=("$m") ;; esac
  done
  [[ ${#manual[@]} -gt 0 ]] && die "instale manualmente e rode de novo: ${manual[*]}"
  if command -v apt-get >/dev/null 2>&1; then
    run apt-get update -qq
    run apt-get install -y --no-install-recommends "${installable[@]}"
  elif command -v dnf >/dev/null 2>&1; then
    run dnf install -y "${installable[@]}"
  elif command -v pacman >/dev/null 2>&1; then
    run pacman -Sy --noconfirm "${installable[@]}"
  else
    die "gerenciador de pacotes não reconhecido; instale manualmente: ${installable[*]}"
  fi
else
  log "dependências ok"
fi

# Python 3.11+ é exigido pelo instalador oficial do Nanobot.
if [[ "$SKIP_NANOBOT" != "1" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    if python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3,11) else 1)'; then
      log "python3 $(python3 -V 2>&1 | awk '{print $2}') ok"
    else
      die "o instalador do Nanobot exige Python 3.11+; encontrado $(python3 -V 2>&1)"
    fi
  else
    die "python3 ausente: exigido pelo instalador do Nanobot"
  fi
fi

# 3. usuário dedicado --------------------------------------------------------
# O runtime não roda como root (least privilege).
if id -u "$ASSISTANT_USER" >/dev/null 2>&1; then
  log "usuário ${ASSISTANT_USER} já existe"
else
  log "criando usuário de serviço ${ASSISTANT_USER}"
  if command -v useradd >/dev/null 2>&1; then
    run useradd --system --create-home --shell /usr/sbin/nologin "$ASSISTANT_USER"
  else
    die "useradd ausente; crie o usuário ${ASSISTANT_USER} manualmente"
  fi
fi
HOME_DIR="$(assistant_home)"

# 4. diretórios --------------------------------------------------------------
log "garantindo diretórios"
ensure_dir "$BRAIN_DIR"   0750 "${ASSISTANT_USER}:${ASSISTANT_USER}"
ensure_dir "$RUNTIME_DIR" 0750 "${ASSISTANT_USER}:${ASSISTANT_USER}"
ensure_dir "$CONFIG_DIR"  0750
ensure_dir "$BACKUP_DIR"  0700
ensure_dir "$LOG_DIR"     0750 "${ASSISTANT_USER}:${ASSISTANT_USER}"

# 5. checkout controlado -----------------------------------------------------
# Se o repo já está no destino, nada a fazer. Se estamos rodando de outro
# lugar, copiamos o checkout atual — sem clonar por rede.
REPO_SOURCE="$(cd "${SCRIPT_DIR}/.." && pwd)"
if [[ "$REPO_SOURCE" == "$(readlink -m "$REPO_DIR")" ]]; then
  log "repositório já está em ${REPO_DIR}"
elif [[ -d "${REPO_DIR}/.git" ]]; then
  log "checkout controlado já existe em ${REPO_DIR} (use update.sh para atualizar)"
else
  log "copiando checkout para ${REPO_DIR}"
  ensure_dir "$REPO_DIR" 0755
  run cp -a "${REPO_SOURCE}/." "${REPO_DIR}/"
fi

# 6. configuração ------------------------------------------------------------
if [[ -f "$CONFIG_FILE" ]]; then
  log "configuração preservada: ${CONFIG_FILE}"
else
  log "criando configuração inicial a partir de .env.example"
  if is_dry_run; then
    log "[dry-run] cp ${REPO_SOURCE}/.env.example ${CONFIG_FILE}"
  else
    cp -- "${REPO_SOURCE}/.env.example" "$CONFIG_FILE"
    chmod 0600 -- "$CONFIG_FILE"
  fi
  warn "edite ${CONFIG_FILE} antes de usar o assistente"
fi
run chmod 0600 "$CONFIG_FILE" 2>/dev/null || true
load_env

# 7. brain -------------------------------------------------------------------
if [[ -f "${BRAIN_DIR}/INDEX.md" ]]; then
  log "brain existente preservado: ${BRAIN_DIR}"
else
  log "inicializando brain em ${BRAIN_DIR}"
  if is_dry_run; then
    log "[dry-run] bootstrap.sh ${BRAIN_DIR}"
  else
    "${SCRIPT_DIR}/bootstrap.sh" "$BRAIN_DIR" >/dev/null \
      || die "falha ao inicializar o brain"
    chown -R "${ASSISTANT_USER}:${ASSISTANT_USER}" -- "$BRAIN_DIR"
  fi
fi

# 8. arquivos gerenciados ----------------------------------------------------
log "sincronizando arquivos gerenciados"
sync_args=(--source "${REPO_SOURCE}/brain")
is_dry_run && sync_args+=(--dry-run)
set +e
"${SCRIPT_DIR}/sync.sh" "${sync_args[@]}"
sync_rc=$?
set -e
if [[ $sync_rc -eq 3 ]]; then
  die "sync reportou conflito em arquivo gerenciado; resolva antes de continuar"
elif [[ $sync_rc -ne 0 ]]; then
  die "sync falhou (código ${sync_rc})"
fi

# 9. runtime -----------------------------------------------------------------
RUNTIME="$(selected_runtime)"
log "runtime selecionado: ${RUNTIME}"
ensure_dir "$(runtime_state_dir)" 0750 "${ASSISTANT_USER}:${ASSISTANT_USER}" >/dev/null
ensure_dir "$(runtime_log_dir)" 0750 "${ASSISTANT_USER}:${ASSISTANT_USER}" >/dev/null
# TRUST BOUNDARY: o instalador oficial é código remoto de terceiro. Aqui ele é
# baixado para arquivo, verificado em dry-run e só então executado — nunca
# canalizado direto para o shell. Ver docs/INSTALL.md.
if [[ "$RUNTIME" != "nanobot" ]]; then
  # Adapter alternativo cuida da instalação do próprio runtime.
  adapter_install="$(runtime_adapter_dir)/install.sh"
  if [[ -x "$adapter_install" ]]; then
    install_args=(); is_dry_run && install_args+=(--dry-run)
    "$adapter_install" "${install_args[@]}" || die "instalação do runtime ${RUNTIME} falhou"
  else
    die "adapter de runtime não encontrado para ${RUNTIME}"
  fi
elif [[ "$SKIP_NANOBOT" == "1" ]]; then
  log "instalação do Nanobot pulada (--skip-nanobot)"
elif NB="$(nanobot_bin 2>/dev/null)"; then
  log "Nanobot já instalado: ${NB} ($("$NB" --version 2>/dev/null | head -n1 || echo '?'))"
else
  installer="$(mktemp /tmp/nanobot-install.XXXXXX.sh)"
  log "baixando instalador oficial do Nanobot"
  if is_dry_run; then
    log "[dry-run] curl -fsSL ${NANOBOT_INSTALLER_URL} -o ${installer}"
    log "[dry-run] sh ${installer} --dry-run   (como ${ASSISTANT_USER})"
    log "[dry-run] sh ${installer}             (como ${ASSISTANT_USER})"
  else
    curl -fsSL "$NANOBOT_INSTALLER_URL" -o "$installer" \
      || die "não foi possível baixar o instalador do Nanobot"
    [[ -s "$installer" ]] || die "instalador do Nanobot veio vazio"
    chmod 0755 -- "$installer"

    as_assistant() {
      # O instalador oficial não exige root e não deve rodar como root.
      runuser -u "$ASSISTANT_USER" -- env HOME="$HOME_DIR" NANOBOT_SKIP_WIZARD=1 "$@"
    }

    log "conferindo o instalador em dry-run"
    as_assistant sh "$installer" --dry-run \
      || die "o dry-run do instalador do Nanobot falhou; nada foi instalado"

    log "instalando Nanobot como ${ASSISTANT_USER}"
    as_assistant sh "$installer" || die "a instalação do Nanobot falhou"
    rm -f -- "$installer"

    if NB="$(nanobot_bin)"; then
      log "Nanobot instalado: ${NB} ($("$NB" --version 2>/dev/null | head -n1 || echo '?'))"
    else
      die "Nanobot não encontrado após a instalação; verifique ${HOME_DIR}/.local/bin"
    fi
  fi
fi

# NANOBOT_VERSION: o instalador oficial não faz pinning. Se a variável estiver
# definida, o pin é responsabilidade do operador (uv/pip). Ver docs/INSTALL.md.
if [[ -n "${NANOBOT_VERSION:-}" ]]; then
  warn "NANOBOT_VERSION=${NANOBOT_VERSION} definido, mas o instalador oficial não fixa versão."
  warn "Para fixar:  uv tool install 'nanobot-ai==${NANOBOT_VERSION}'  (como ${ASSISTANT_USER})"
fi

# 10. serviço ----------------------------------------------------------------
# Nenhuma unit systemd é criada aqui: o Nanobot já oferece execução persistente
# própria (nanobot gateway --background). Ver docs/OPERATIONS.md.
log "serviço: nenhuma unit criada (o Nanobot gerencia o próprio gateway)"

# 11. healthcheck ------------------------------------------------------------
health_rc=0
if is_dry_run; then
  log "dry-run: healthcheck pulado (o estado real ainda não existe)"
else
  log "executando healthcheck"
  "${SCRIPT_DIR}/healthcheck.sh" || health_rc=$?
fi

# 12. resumo -----------------------------------------------------------------
cat <<SUMMARY

Instalação concluída$(is_dry_run && printf ' (dry-run: nada foi gravado)')
  repo    ${REPO_DIR}
  brain   ${BRAIN_DIR}
  config  ${CONFIG_FILE}
  backups ${BACKUP_DIR}
  usuário ${ASSISTANT_USER}

Próximos passos:
  1) revise ${CONFIG_FILE}
  2) sudo ${SCRIPT_DIR}/healthcheck.sh
  3) configure o Nanobot como ${ASSISTANT_USER} (docs/INSTALL.md)
SUMMARY

[[ $health_rc -eq 1 ]] && die "healthcheck reprovou; veja as falhas acima"
exit 0
