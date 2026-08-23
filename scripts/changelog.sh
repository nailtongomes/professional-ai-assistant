#!/usr/bin/env bash
#
# Registra uma mudança de infraestrutura no changelog da VPS.
#
#   changelog.sh "runtime nanobot 0.4.2 no ar; brain intocado"
#   changelog.sh --list                 # últimas 20 entradas
#
# Instalado em /opt/files/changelog.sh. Append-only: nunca reescreve o
# histórico, nunca apaga linha.
set -Eeuo pipefail

CHANGELOG="${CHANGELOG_FILE:-/opt/files/changelog.md}"

usage() {
  cat <<'USAGE'
Uso: changelog.sh "o que mudou"
     changelog.sh --list [n]

Registra depois da mudança dar certo, não antes. Uma linha por mudança:
o que mudou e, quando importar, por quê.
USAGE
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --list)
    [[ -f "$CHANGELOG" ]] || { echo "changelog ainda não existe: $CHANGELOG"; exit 0; }
    tail -n "$(( ${2:-20} * 2 ))" "$CHANGELOG"
    exit 0 ;;
  "") usage; exit 1 ;;
esac

entry="$*"
[[ ${#entry} -ge 10 ]] || { echo "erro: descreva a mudança (mín. 10 caracteres)" >&2; exit 1; }

dir="$(dirname "$CHANGELOG")"
[[ -d "$dir" ]] || mkdir -p "$dir"

if [[ ! -f "$CHANGELOG" ]]; then
  cat > "$CHANGELOG" <<'HEADER'
# Changelog de infraestrutura

Append-only. Uma entrada por mudança relevante: data UTC, autor e o que mudou.
Nada aqui é editado ou removido — histórico serve para explicar o presente.

HEADER
fi

printf -- '- %s — %s — %s\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${CHANGELOG_AUTHOR:-${SUDO_USER:-$(id -un)}}" "$entry" \
  >> "$CHANGELOG"

echo "registrado em ${CHANGELOG}"
tail -n1 "$CHANGELOG"
