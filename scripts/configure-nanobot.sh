#!/usr/bin/env bash
#
# Aplica a allowlist owner-only nativa do Nanobot ao config.json existente.
#
#   ./scripts/configure-nanobot.sh --dry-run
#   ./scripts/configure-nanobot.sh
#
# Idempotente. Preserva toda configuração não relacionada a acesso.
# FAIL CLOSED: sem o ID do owner, o canal não é habilitado.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

CONFIG_JSON=""
ENABLE_WHATSAPP=0
ENABLE_EMAIL=0

usage() {
  cat <<'USAGE'
Uso: configure-nanobot.sh [--dry-run] [--config PATH]
                          [--enable-whatsapp] [--enable-email]

  --dry-run           mostra o resultado sem gravar
  --config PATH       config.json do Nanobot (padrão: ~/.nanobot/config.json
                      do usuário de serviço)
  --enable-whatsapp   também aplica allowlist ao WhatsApp
  --enable-email      também aplica allowlist ao Email

Telegram é sempre considerado. Um canal só é habilitado quando o ID do owner
correspondente estiver definido: sem ID, o canal é desabilitado (fail closed).
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=1 ;;
    --config) CONFIG_JSON="${2:?--config exige um path}"; shift ;;
    --enable-whatsapp) ENABLE_WHATSAPP=1 ;;
    --enable-email) ENABLE_EMAIL=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; die "argumento desconhecido: $1" ;;
  esac
  shift
done

require_command python3 "necessário para editar JSON com segurança"
load_env

if [[ -z "$CONFIG_JSON" ]]; then
  CONFIG_JSON="${NANOBOT_CONFIG:-$(assistant_home)/.nanobot/config.json}"
fi

log "config do Nanobot: ${CONFIG_JSON}"
is_dry_run && log "modo dry-run: nada será gravado"

# O trabalho de JSON fica em Python (stdlib): editar JSON com sed é como o
# projeto ganha um bug silencioso. Sem dependência de jq.
CHANNELS_SPEC="telegram:${OWNER_TELEGRAM_ID:-}:1"
CHANNELS_SPEC+=$'\n'"whatsapp:${OWNER_WHATSAPP_ID:-}:${ENABLE_WHATSAPP}"
CHANNELS_SPEC+=$'\n'"email:${OWNER_EMAIL:-}:${ENABLE_EMAIL}"

set +e
CONFIG_PATH="$CONFIG_JSON" DRY_RUN="$DRY_RUN" SPEC="$CHANNELS_SPEC" python3 - <<'PY'
import json, os, sys, tempfile
from pathlib import Path

path = Path(os.environ["CONFIG_PATH"])
dry = os.environ.get("DRY_RUN") == "1"
changed, problems = [], []

if path.exists():
    try:
        config = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"ERRO: config.json inválido ({exc}); nada foi alterado", file=sys.stderr)
        sys.exit(2)
    if not isinstance(config, dict):
        print("ERRO: config.json não é um objeto JSON", file=sys.stderr)
        sys.exit(2)
else:
    config = {}
    print(f"config ainda não existe; será criado: {path}")

channels = config.setdefault("channels", {})
if not isinstance(channels, dict):
    print("ERRO: 'channels' não é um objeto; nada foi alterado", file=sys.stderr)
    sys.exit(2)


def mask(value: str) -> str:
    """Nunca imprime o identificador inteiro."""
    if "@" in value:                       # e-mail
        user, _, domain = value.partition("@")
        head = user[:1] if user else ""
        return f"{head}***@{domain}"
    return f"(...{value[-4:]})" if len(value) > 4 else "(curto)"


for line in os.environ["SPEC"].strip().splitlines():
    name, owner_id, wanted = line.split(":", 2)
    owner_id = owner_id.strip()
    wanted = wanted.strip() == "1"
    section = channels.get(name)
    section = section if isinstance(section, dict) else {}

    if not wanted:
        # Canal não pedido nesta execução. Não habilita; não mexe no que existe,
        # salvo para fechar um wildcard, que nunca é aceitável em canal pessoal.
        if section.get("allowFrom") == ["*"]:
            problems.append(f"{name}: wildcard encontrado em canal não gerenciado")
        continue

    if not owner_id:
        # FAIL CLOSED. A semântica de allowFrom == [] não está documentada na
        # versão atual do Nanobot, então não confiamos nela como bloqueio:
        # desabilitamos o canal, e a lista vazia fica só como reforço.
        if section.get("enabled") is True or section.get("allowFrom") not in (None, []):
            changed.append(f"{name}: desabilitado (owner não configurado)")
        section["enabled"] = False
        section["allowFrom"] = []
        channels[name] = section
        problems.append(f"{name}: ID do owner ausente; canal desabilitado")
        continue

    desired = [owner_id]
    if section.get("allowFrom") != desired or section.get("enabled") is not True:
        changed.append(f"{name}: allowFrom = owner {mask(owner_id)}, enabled = true")
    section["enabled"] = True
    section["allowFrom"] = desired
    channels[name] = section

# Nenhum canal pessoal pode terminar com wildcard.
for name, section in channels.items():
    if isinstance(section, dict) and section.get("allowFrom") == ["*"]:
        print(f"ERRO: wildcard em channels.{name}.allowFrom; recusado", file=sys.stderr)
        sys.exit(2)

serialized = json.dumps(config, indent=2, ensure_ascii=False) + "\n"
try:
    json.loads(serialized)
except json.JSONDecodeError:
    print("ERRO: JSON resultante inválido; nada foi gravado", file=sys.stderr)
    sys.exit(2)

for item in changed:
    print(f"  altera  {item}")
if not changed:
    print("  nenhuma alteração necessária (já convergido)")

if not dry:
    path.parent.mkdir(parents=True, exist_ok=True)
    # Escrita atômica: um config.json truncado deixaria o Nanobot sem subir.
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent,
                                     delete=False) as tmp:
        tmp.write(serialized)
        tmp_path = Path(tmp.name)
    tmp_path.replace(path)
    path.chmod(0o600)

for item in problems:
    print(f"AVISO: {item}", file=sys.stderr)
sys.exit(3 if problems else 0)
PY
rc=$?
set -e

case "$rc" in
  0) log "acesso owner-only aplicado" ;;
  3) warn "canal sem owner configurado foi desabilitado (fail closed)"
     warn "defina OWNER_TELEGRAM_ID em ${CONFIG_FILE} e rode de novo" ;;
  *) die "falha ao configurar o Nanobot (código ${rc}); config preservado" ;;
esac

is_dry_run || log "config gravado com permissão 600"
exit "$rc"
