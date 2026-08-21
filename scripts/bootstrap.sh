#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 /path/to/new-brain"
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

TARGET="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_BRAIN="$REPO_ROOT/brain"

if [[ -e "$TARGET" && ! -d "$TARGET" ]]; then
  echo "Error: target exists and is not a directory: $TARGET" >&2
  exit 1
fi

if [[ ! -d "$SOURCE_BRAIN" ]]; then
  echo "Error: source brain directory not found: $SOURCE_BRAIN" >&2
  exit 1
fi

mkdir -p "$TARGET"

# Ensure we do not silently overwrite key files.
for protected in INDEX.md 00-system/agent-rules.md 00-system/conventions.md 70-skills/INDEX.md; do
  if [[ -e "$TARGET/$protected" ]]; then
    echo "Error: target already contains '$protected'. Aborting to avoid overwrite." >&2
    exit 1
  fi
done

cp -R "$SOURCE_BRAIN/." "$TARGET/"

# Create initial operational memory files from examples when not present.
for name in profile preferences decisions lessons; do
  src="$TARGET/60-memory/${name}.example.md"
  dst="$TARGET/60-memory/${name}.md"
  if [[ -f "$src" && ! -e "$dst" ]]; then
    cp "$src" "$dst"
  fi
done

echo "Brain initialized at: $TARGET"
echo "Next steps:"
echo "1) Review $TARGET/INDEX.md"
echo "2) Edit $TARGET/60-memory/*.md"
echo "3) Start adding Skills under $TARGET/70-skills/"
