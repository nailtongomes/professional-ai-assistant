#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REQUIRED_DIRS = [
    "00-system",
    "10-inbox",
    "20-projects",
    "30-areas",
    "40-resources",
    "50-people",
    "60-memory",
    "70-skills",
    "90-archive",
]

REQUIRED_FILES = [
    "INDEX.md",
    "00-system/README.md",
    "00-system/conventions.md",
    "00-system/taxonomy.md",
    "00-system/agent-rules.md",
    "60-memory/README.md",
    "70-skills/README.md",
    "70-skills/INDEX.md",
]

SUSPECT_FILE_PATTERNS = (
    re.compile(r"\.env$", re.IGNORECASE),
    re.compile(r"\.(key|pem|p12|pfx)$", re.IGNORECASE),
)

SUSPECT_CONTENT_PATTERNS = (
    re.compile(r"AKIA[0-9A-Z]{16}"),
    re.compile(r"-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    re.compile(r"(?i)(api[_-]?key|token|password|secret)\s*[:=]\s*['\"]?[A-Za-z0-9_\-]{12,}"),
)


def validate_structure(brain_dir: Path) -> list[str]:
    errors: list[str] = []

    if not brain_dir.exists() or not brain_dir.is_dir():
        return [f"Brain directory not found: {brain_dir}"]

    for rel in REQUIRED_DIRS:
        path = brain_dir / rel
        if not path.is_dir():
            errors.append(f"Missing required directory: {rel}")

    for rel in REQUIRED_FILES:
        path = brain_dir / rel
        if not path.is_file():
            errors.append(f"Missing required file: {rel}")

    for path in brain_dir.rglob("*"):
        if path.is_file():
            if any(p.search(path.name) for p in SUSPECT_FILE_PATTERNS):
                errors.append(f"Suspicious file in brain/: {path.relative_to(brain_dir)}")
                continue

            # Skip huge files if any appear unexpectedly.
            if path.stat().st_size > 1_000_000:
                continue

            try:
                content = path.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                errors.append(f"Could not read file: {path.relative_to(brain_dir)}")
                continue

            for pattern in SUSPECT_CONTENT_PATTERNS:
                if pattern.search(content):
                    errors.append(
                        f"Suspicious secret-like content in: {path.relative_to(brain_dir)}"
                    )
                    break

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate second-brain structure")
    default_brain = Path(__file__).resolve().parents[1] / "brain"
    parser.add_argument(
        "--brain",
        type=Path,
        default=default_brain,
        help=f"Path to brain directory (default: {default_brain})",
    )
    args = parser.parse_args()

    errors = validate_structure(args.brain)
    if errors:
        print("❌ Structure validation failed:")
        for err in errors:
            print(f"- {err}")
        return 1

    print(f"✅ Structure is valid: {args.brain}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
