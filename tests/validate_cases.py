#!/usr/bin/env python3
"""Valida os casos conceituais das Skills.

Só biblioteca padrão, e deliberadamente burro: confere schema, coerência com o
índice de Skills e higiene dos casos. **Não simula raciocínio de LLM** — ver
tests/README.md.

    python3 tests/validate_cases.py
    python3 tests/validate_cases.py --cases tests/cases --brain brain
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REQUIRED_KEYS = {"name", "input", "expected_skill", "expected_action", "must_not"}
OPTIONAL_KEYS = {"expected_target"}

# Ações que um caso pode esperar. Lista fechada de propósito: uma ação nova
# exige pensar se ela realmente existe no contrato das Skills.
ACTIONS = {
    "create",    # cria arquivo novo
    "append",    # acrescenta a arquivo existente
    "update",    # altera trecho pontual
    "read",      # apenas consulta
    "http",      # invoca workflow externo
    "confirm",   # pede confirmação antes de agir
    "ask",       # pede informação faltante
    "refuse",    # não executa
    "report",    # apenas relata estado
    "noop",      # nada a fazer (ex.: duplicata)
}

# Casos sensíveis precisam declarar o que NÃO pode acontecer.
SENSITIVE = re.compile(
    r"(?i)(secret|senha|password|token|api[_-]?key|credencial|apag|delet|exclu|"
    r"ignore suas regras|cpf|cnpj|oab)"
)

SECRET_LIKE = (
    re.compile(r"AKIA[0-9A-Z]{16}"),
    re.compile(r"gh[pousr]_[A-Za-z0-9]{20,}"),
    re.compile(r"-----BEGIN .*PRIVATE KEY-----"),
    re.compile(r"(?i)\b(sk|pk)-[A-Za-z0-9]{20,}"),
)

# Valores usados de propósito nos exemplos, que não são credenciais reais.
FAKE_VALUES = {"abc123", "abc", "123"}


def indexed_skills(brain: Path) -> set[str]:
    index = brain / "70-skills" / "INDEX.md"
    if not index.is_file():
        return set()
    text = re.sub(r"<!--.*?-->", "", index.read_text(encoding="utf-8"), flags=re.DOTALL)
    # Entradas registradas: "## nome" seguido, adiante, de um Path terminando em SKILL.md
    names = set()
    for m in re.finditer(r"^## ([a-z0-9][a-z0-9-]*)\s*$", text, flags=re.MULTILINE):
        names.add(m.group(1))
    return names


def skill_paths(brain: Path) -> set[str]:
    root = brain / "70-skills"
    return {p.parent.name for p in root.rglob("SKILL.md")} if root.is_dir() else set()


def validate(cases_dir: Path, brain: Path) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []

    registered = indexed_skills(brain)
    on_disk = skill_paths(brain)
    files = sorted(cases_dir.glob("*.json"))
    if not files:
        return [f"nenhum caso encontrado em {cases_dir}"], []

    covered: set[str] = set()
    for path in files:
        rel = path.name
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errors.append(f"{rel}: JSON inválido — {exc}")
            continue

        skill = data.get("skill")
        if not skill:
            errors.append(f"{rel}: chave 'skill' ausente")
            continue
        covered.add(skill)

        if skill not in on_disk:
            errors.append(f"{rel}: Skill '{skill}' não existe em brain/70-skills/")
        if registered and skill not in registered:
            errors.append(f"{rel}: Skill '{skill}' não está registrada no INDEX.md")

        cases = data.get("cases")
        if not isinstance(cases, list) or not cases:
            errors.append(f"{rel}: 'cases' vazio ou ausente")
            continue

        seen_names: set[str] = set()
        seen_inputs: set[str] = set()
        kinds: set[str] = set()

        for i, case in enumerate(cases):
            tag = f"{rel}[{i}]"
            if not isinstance(case, dict):
                errors.append(f"{tag}: caso não é um objeto")
                continue

            missing = REQUIRED_KEYS - case.keys()
            if missing:
                errors.append(f"{tag}: chaves ausentes: {', '.join(sorted(missing))}")
                continue
            extra = case.keys() - REQUIRED_KEYS - OPTIONAL_KEYS
            if extra:
                errors.append(f"{tag}: chaves desconhecidas: {', '.join(sorted(extra))}")

            name = case["name"]
            if name in seen_names:
                errors.append(f"{tag}: nome duplicado: {name!r}")
            seen_names.add(name)

            text = str(case["input"])
            if text in seen_inputs:
                errors.append(f"{tag}: input duplicado: {text[:50]!r}")
            seen_inputs.add(text)

            action = case["expected_action"]
            if action not in ACTIONS:
                errors.append(f"{tag}: ação desconhecida: {action!r}")
            kinds.add(action)

            target = case.get("expected_target")
            if action in {"create", "append", "update", "read"} and not target:
                errors.append(f"{tag}: ação '{action}' exige expected_target")
            if target and isinstance(target, str) and target.startswith("/"):
                errors.append(f"{tag}: expected_target absoluto: {target}")

            expected = case["expected_skill"]
            if expected not in on_disk:
                errors.append(f"{tag}: expected_skill inexistente: {expected!r}")

            must_not = case["must_not"]
            if not isinstance(must_not, list):
                errors.append(f"{tag}: 'must_not' deve ser lista")
            elif SENSITIVE.search(f"{name} {text}") and not must_not:
                errors.append(f"{tag}: caso sensível sem 'must_not'")

            blob = json.dumps(case, ensure_ascii=False)
            for pattern in SECRET_LIKE:
                m = pattern.search(blob)
                if m and m.group(0) not in FAKE_VALUES:
                    errors.append(f"{tag}: possível secret real no caso")
                    break

        # Cobertura mínima por Skill.
        if "ask" not in kinds and "refuse" not in kinds:
            warnings.append(f"{rel}: nenhum caso de informação ausente ou recusa")
        if not any(c.get("expected_skill") != data["skill"] for c in cases if isinstance(c, dict)):
            warnings.append(f"{rel}: nenhum caso apontando para outra Skill mais adequada")
        if len(cases) < 4:
            warnings.append(f"{rel}: só {len(cases)} caso(s); o mínimo recomendado é 4")

    for skill in sorted(on_disk - covered):
        warnings.append(f"Skill sem arquivo de casos: {skill}")

    return errors, warnings


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    ap = argparse.ArgumentParser(description="Valida os casos conceituais das Skills")
    ap.add_argument("--cases", type=Path, default=root / "tests" / "cases")
    ap.add_argument("--brain", type=Path, default=root / "brain")
    ap.add_argument("--strict", action="store_true", help="trata avisos como erro")
    args = ap.parse_args()

    errors, warnings = validate(args.cases, args.brain)
    for w in warnings:
        print(f"aviso: {w}")
    if errors:
        print(f"FALHA: {len(errors)} problema(s) nos casos")
        for e in errors:
            print(f"  - {e}")
        return 1
    if warnings and args.strict:
        print(f"FALHA (--strict): {len(warnings)} aviso(s)")
        return 1

    total = sum(len(json.loads(f.read_text(encoding='utf-8'))["cases"])
                for f in sorted(args.cases.glob("*.json")))
    print(f"OK: {total} casos conceituais válidos")
    return 0


if __name__ == "__main__":
    sys.exit(main())
