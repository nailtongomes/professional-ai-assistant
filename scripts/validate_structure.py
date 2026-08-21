#!/usr/bin/env python3
"""Valida a integridade mínima de um brain.

Somente biblioteca padrão. Verifica diretórios essenciais, arquivos de sistema
obrigatórios, os índices, o diretório de Skills e a ausência evidente de secrets.

    python3 scripts/validate_structure.py
    python3 scripts/validate_structure.py --brain /caminho/do/brain
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REQUIRED_DIRS = (
    "00-system",
    "10-inbox",
    "20-projects",
    "30-areas",
    "40-resources",
    "50-people",
    "60-memory",
    "70-skills",
    "90-archive",
)

REQUIRED_FILES = (
    "INDEX.md",
    "00-system/README.md",
    "00-system/agent-rules.md",
    "00-system/PHILOSOPHY.md",
    "00-system/conventions.md",
    "00-system/taxonomy.md",
    "00-system/runtime-contract.md",
    "60-memory/README.md",
    "70-skills/README.md",
    "70-skills/INDEX.md",
)

# Nomes de arquivo que nunca deveriam existir dentro do brain.
SECRET_FILENAME_PATTERNS = (
    re.compile(r"^\.env(\..+)?$", re.IGNORECASE),
    re.compile(r"\.(key|pem|p12|pfx|jks|keystore)$", re.IGNORECASE),
    re.compile(r"^id_(rsa|ed25519|ecdsa)$", re.IGNORECASE),
)

# Conteúdo com cara de credencial real.
SECRET_CONTENT_PATTERNS = (
    ("chave AWS", re.compile(r"AKIA[0-9A-Z]{16}")),
    ("chave privada", re.compile(r"-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----")),
    ("token GitHub", re.compile(r"gh[pousr]_[A-Za-z0-9]{20,}")),
    ("token Slack", re.compile(r"xox[baprs]-[A-Za-z0-9-]{10,}")),
    ("token Telegram", re.compile(r"\b\d{8,10}:AA[A-Za-z0-9_-]{30,}\b")),
    (
        "credencial atribuída",
        re.compile(
            r"(?i)\b(api[_-]?key|apikey|access[_-]?token|auth[_-]?token|password|senha|secret)\b"
            r"\s*[:=]\s*[\"']?(?!<|\{\{|\.\.\.|xxx|your|seu|\s*$)[A-Za-z0-9_\-\.]{12,}"
        ),
    ),
)

# Placeholders legítimos: {{N8N_URL}}, <valor>, ..., ***
PLACEHOLDER = re.compile(r"\{\{[A-Z0-9_]+\}\}|<[^>\n]{1,40}>|\*{3,}")

MAX_SCAN_BYTES = 1_000_000
SKILL_CATEGORY_SKIP = {"README.md", "INDEX.md"}

# Nomes convencionais em maiúsculas, aceitos por exceção.
RESERVED_NAMES = {"README.md", "INDEX.md", "SKILL.md", "PHILOSOPHY.md", ".gitkeep"}


def _iter_files(brain: Path):
    for path in sorted(brain.rglob("*")):
        if path.is_file() and ".git" not in path.parts:
            yield path


def check_required(brain: Path) -> list[str]:
    errors = []
    for rel in REQUIRED_DIRS:
        if not (brain / rel).is_dir():
            errors.append(f"diretório obrigatório ausente: {rel}/")
    for rel in REQUIRED_FILES:
        path = brain / rel
        if not path.is_file():
            errors.append(f"arquivo obrigatório ausente: {rel}")
        elif not path.read_text(encoding="utf-8", errors="ignore").strip():
            errors.append(f"arquivo obrigatório vazio: {rel}")
    return errors


def check_secrets(brain: Path) -> list[str]:
    errors = []
    for path in _iter_files(brain):
        rel = path.relative_to(brain)
        if any(p.search(path.name) for p in SECRET_FILENAME_PATTERNS):
            errors.append(f"arquivo com cara de secret dentro do brain: {rel}")
            continue
        if path.stat().st_size > MAX_SCAN_BYTES:
            continue
        try:
            content = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            errors.append(f"não foi possível ler: {rel}")
            continue
        for label, pattern in SECRET_CONTENT_PATTERNS:
            match = pattern.search(content)
            if match and not PLACEHOLDER.search(match.group(0)):
                line = content[: match.start()].count("\n") + 1
                errors.append(f"possível secret ({label}) em {rel}:{line}")
                break
    return errors


def check_skills(brain: Path) -> list[str]:
    """Toda Skill deve estar em <categoria>/<nome>/SKILL.md e indexada."""
    errors = []
    skills_dir = brain / "70-skills"
    if not skills_dir.is_dir():
        return errors

    index_path = skills_dir / "INDEX.md"
    index_text = index_path.read_text(encoding="utf-8") if index_path.is_file() else ""
    # Ignora o bloco de exemplo comentado ao procurar registros.
    index_active = re.sub(r"<!--.*?-->", "", index_text, flags=re.DOTALL)

    for skill_file in sorted(skills_dir.rglob("SKILL.md")):
        rel = skill_file.relative_to(skills_dir)
        if len(rel.parts) != 3:
            errors.append(
                f"Skill fora do padrão <categoria>/<nome>/SKILL.md: 70-skills/{rel}"
            )
            continue
        if rel.as_posix() not in index_active:
            errors.append(f"Skill não registrada em 70-skills/INDEX.md: {rel.as_posix()}")

    for entry in sorted(skills_dir.iterdir()):
        if entry.is_file() and entry.name not in SKILL_CATEGORY_SKIP:
            errors.append(f"arquivo solto em 70-skills/: {entry.name}")
    return errors


def check_workflows(brain: Path) -> list[str]:
    """Se houver catálogo de workflows, ele precisa de índice e de registro."""
    errors = []
    wf_dir = brain / "40-resources" / "automation" / "workflows"
    if not wf_dir.is_dir():
        return errors

    index_path = wf_dir / "INDEX.md"
    if not index_path.is_file():
        return [f"catálogo de workflows sem índice: {index_path.relative_to(brain)}"]

    index_text = index_path.read_text(encoding="utf-8")
    for wf in sorted(wf_dir.glob("*.md")):
        if wf.name == "INDEX.md":
            continue
        declared_example = "status: example" in wf.read_text(encoding="utf-8")
        listed = wf.name in index_text
        if not listed and not declared_example:
            errors.append(
                f"workflow não registrado em INDEX.md e não marcado como exemplo: {wf.name}"
            )
    return errors


def check_paths(brain: Path) -> list[str]:
    """Convenções básicas: kebab-case e ausência de paths absolutos do host."""
    warnings = []
    kebab = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
    for path in _iter_files(brain):
        rel = path.relative_to(brain)
        for part in rel.parts:
            if not kebab.match(part) and part not in RESERVED_NAMES:
                warnings.append(f"nome fora de kebab-case: {rel}")
                break
    return warnings


def validate(brain: Path) -> tuple[list[str], list[str]]:
    if not brain.is_dir():
        return [f"diretório do brain não encontrado: {brain}"], []
    errors = (check_required(brain) + check_secrets(brain)
              + check_skills(brain) + check_workflows(brain))
    return errors, check_paths(brain)


def main() -> int:
    default_brain = Path(__file__).resolve().parents[1] / "brain"
    parser = argparse.ArgumentParser(description="Valida a estrutura do brain")
    parser.add_argument("--brain", type=Path, default=default_brain,
                        help=f"caminho do brain (padrão: {default_brain})")
    parser.add_argument("--strict", action="store_true",
                        help="trata avisos como erro")
    args = parser.parse_args()

    brain = args.brain.resolve()
    errors, warnings = validate(brain)

    for warning in warnings:
        print(f"aviso: {warning}")
    if errors:
        print(f"FALHA: estrutura inválida em {brain}")
        for err in errors:
            print(f"  - {err}")
        return 1
    if warnings and args.strict:
        print(f"FALHA (--strict): {len(warnings)} aviso(s) em {brain}")
        return 1

    print(f"OK: estrutura válida em {brain}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
