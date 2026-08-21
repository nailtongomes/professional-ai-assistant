#!/usr/bin/env bash
#
# Inicializa uma nova instância operacional do brain a partir deste template.
#
#   ./scripts/bootstrap.sh /caminho/do/brain
#
# Nunca sobrescreve arquivos existentes: arquivos já presentes no destino são
# preservados e listados como "skipped" ao final.
set -euo pipefail

usage() {
  cat <<'USAGE'
Uso: scripts/bootstrap.sh <diretorio-destino> [--dry-run]

  <diretorio-destino>  onde o brain operacional será criado
  --dry-run            mostra o que seria feito, sem escrever nada
USAGE
}

TARGET=""
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
    -*) echo "Erro: opção desconhecida: $arg" >&2; usage; exit 1 ;;
    *)
      if [[ -n "$TARGET" ]]; then
        echo "Erro: informe apenas um diretório de destino." >&2
        exit 1
      fi
      TARGET="$arg"
      ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  usage
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_BRAIN="$REPO_ROOT/brain"

if [[ ! -d "$SOURCE_BRAIN" ]]; then
  echo "Erro: brain de origem não encontrado: $SOURCE_BRAIN" >&2
  exit 1
fi

if [[ -e "$TARGET" && ! -d "$TARGET" ]]; then
  echo "Erro: destino existe e não é um diretório: $TARGET" >&2
  exit 1
fi

# Impede inicializar o brain dentro do próprio template.
if [[ "$(cd "$(dirname "$TARGET")" 2>/dev/null && pwd)/$(basename "$TARGET")" == "$SOURCE_BRAIN" ]]; then
  echo "Erro: o destino não pode ser o brain do próprio template." >&2
  exit 1
fi

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

copied=0
skipped=0

run mkdir -p "$TARGET"

# Copia arquivo a arquivo, preservando o que já existir no destino.
while IFS= read -r -d '' src; do
  rel="${src#"$SOURCE_BRAIN"/}"
  dst="$TARGET/$rel"
  if [[ -e "$dst" ]]; then
    echo "skip   $rel (já existe)"
    skipped=$((skipped + 1))
    continue
  fi
  run mkdir -p "$(dirname "$dst")"
  run cp "$src" "$dst"
  copied=$((copied + 1))
done < <(find "$SOURCE_BRAIN" -type f -print0)

# Gera os arquivos operacionais de memória a partir dos exemplos.
for name in profile preferences decisions lessons; do
  src="$SOURCE_BRAIN/60-memory/${name}.example.md"
  dst="$TARGET/60-memory/${name}.md"
  if [[ ! -f "$src" ]]; then
    continue
  fi
  if [[ -e "$dst" ]]; then
    echo "skip   60-memory/${name}.md (já existe)"
    skipped=$((skipped + 1))
    continue
  fi
  run cp "$src" "$dst"
  copied=$((copied + 1))
done

echo
echo "Brain inicializado em: $TARGET"
echo "Arquivos criados: $copied | preservados: $skipped"
if [[ $DRY_RUN -eq 1 ]]; then
  echo "(dry-run: nenhuma alteração foi gravada)"
fi
echo
echo "Próximos passos:"
echo "  1) Leia    $TARGET/INDEX.md"
echo "  2) Ajuste  $TARGET/60-memory/*.md (sem secrets)"
echo "  3) Crie    Skills em $TARGET/70-skills/<categoria>/<nome>/SKILL.md e registre em INDEX.md"
echo "  4) Valide  python3 $REPO_ROOT/scripts/validate_structure.py --brain $TARGET"
