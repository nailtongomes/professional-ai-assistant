#!/usr/bin/env python3
"""Aponta o Hermes para o brain canônico. Idempotente, somente derivados.

    python3 configure.py --dry-run
    python3 configure.py

Gera três coisas, todas reconstrutíveis:

    brain/00-system/PHILOSOPHY.md  →  ~/.hermes/SOUL.md          (derivado)
    brain/70-skills/<cat>/<skill>  →  ~/.hermes/skills/pai-<n>    (symlink)
    OWNER_* + ASSISTANT_MODEL      →  ~/.hermes/gateway.yaml      (acesso/modelo)

Nunca escreve em brain/. Nunca lê memória nativa do Hermes de volta.
FAIL CLOSED: sem identidade de owner, o canal não é habilitado.
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

GENERATED_HEADER = """<!--
ARQUIVO GERADO — NÃO EDITE.

Fonte canônica: brain/00-system/PHILOSOPHY.md
Regenerar:      python3 runtime-adapters/hermes/configure.py

Editar este arquivo é perder a edição no próximo configure. A filosofia do
assistente vive no brain, não no runtime.
-->
"""


def load_env(path: Path) -> dict[str, str]:
    """Lê o assistant.env sem executar shell. Valores nunca são impressos."""
    env: dict[str, str] = {}
    if path.is_file():
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            env[key.strip()] = value.strip().strip('"').strip("'")
    # O ambiente do processo tem precedência (útil em teste e em dispatch).
    for key in ("ASSISTANT_RUNTIME", "OWNER_TELEGRAM_ID", "OWNER_WHATSAPP_ID",
                "OWNER_EMAIL", "ASSISTANT_MODEL", "ASSISTANT_PROVIDER",
                "HERMES_HOME", "BRAIN_DIR"):
        if os.environ.get(key):
            env[key] = os.environ[key]
    return env


def mask(value: str) -> str:
    if "@" in value:
        user, _, domain = value.partition("@")
        return f"{user[:1]}***@{domain}"
    return f"(...{value[-4:]})" if len(value) > 4 else "(curto)"


def skill_name(skill_md: Path) -> str:
    """Nome declarado no frontmatter; cai para o diretório."""
    text = skill_md.read_text(encoding="utf-8")
    m = re.search(r"^name:\s*(.+)$", text, re.MULTILINE)
    return (m.group(1).strip() if m else skill_md.parent.name)


def main() -> int:
    ap = argparse.ArgumentParser(description="Configura o Hermes a partir do brain")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--brain", type=Path)
    ap.add_argument("--hermes-home", type=Path)
    ap.add_argument("--env-file", type=Path,
                    default=Path("/etc/professional-ai-assistant/assistant.env"))
    args = ap.parse_args()

    env = load_env(args.env_file)

    runtime = env.get("ASSISTANT_RUNTIME", "nanobot")
    if runtime != "hermes":
        print(f"ASSISTANT_RUNTIME={runtime}; este adapter só roda com 'hermes'",
              file=sys.stderr)
        return 2

    brain = args.brain or Path(env.get("BRAIN_DIR",
                                       "/srv/professional-ai-assistant/brain"))
    hermes = args.hermes_home or Path(env.get("HERMES_HOME",
                                              Path.home() / ".hermes"))
    if not brain.is_dir():
        print(f"brain não encontrado: {brain}", file=sys.stderr)
        return 2

    dry = args.dry_run
    changed: list[str] = []
    problems: list[str] = []
    if dry:
        print("modo dry-run: nada será gravado")

    # --- 1. SOUL.md derivado da filosofia ---------------------------------
    philosophy = brain / "00-system" / "PHILOSOPHY.md"
    if philosophy.is_file():
        soul = GENERATED_HEADER + "\n" + philosophy.read_text(encoding="utf-8")
        target = hermes / "SOUL.md"
        if not target.is_file() or target.read_text(encoding="utf-8") != soul:
            changed.append("SOUL.md gerado a partir de PHILOSOPHY.md")
            if not dry:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(soul, encoding="utf-8")
    else:
        problems.append("PHILOSOPHY.md ausente no brain")

    # --- 2. Skills por symlink -------------------------------------------
    # Preferimos symlink a cópia: cópia vira fonte divergente no primeiro
    # momento em que alguém editar o lugar errado. O gap que impede a opção
    # ideal (apontar o Hermes para um diretório externo) está no README.
    skills_dir = hermes / "skills"
    canonical = sorted((brain / "70-skills").rglob("SKILL.md"))
    wanted: dict[str, Path] = {}
    for skill_md in canonical:
        wanted[f"pai-{skill_name(skill_md)}"] = skill_md.parent

    existing = {}
    if skills_dir.is_dir():
        existing = {p.name: p for p in skills_dir.iterdir() if p.name.startswith("pai-")}

    for link_name, source in wanted.items():
        link = skills_dir / link_name
        if link.is_symlink() and link.resolve() == source.resolve():
            continue
        changed.append(f"symlink {link_name} → brain")
        if not dry:
            skills_dir.mkdir(parents=True, exist_ok=True)
            if link.is_symlink() or link.exists():
                if not link.is_symlink():
                    problems.append(f"{link_name} existe e não é symlink; preservado")
                    continue
                link.unlink()
            link.symlink_to(source)

    # Symlinks nossos que não correspondem mais a Skill nenhuma.
    for stale in sorted(set(existing) - set(wanted)):
        link = existing[stale]
        if link.is_symlink():
            changed.append(f"symlink obsoleto removido: {stale}")
            if not dry:
                link.unlink()

    # --- 3. Acesso owner-only e modelo -----------------------------------
    # dm_policy é gravado SEMPRE de forma explícita: o default do Hermes quando
    # o campo está ausente não é documentado, e não confiamos em default.
    owner_map = [("telegram", env.get("OWNER_TELEGRAM_ID", "")),
                 ("whatsapp", env.get("OWNER_WHATSAPP_ID", "")),
                 ("email", env.get("OWNER_EMAIL", ""))]
    lines = ["# GERADO por runtime-adapters/hermes/configure.py — não edite.",
             "# Identidades vêm de /etc/professional-ai-assistant/assistant.env.",
             ""]
    enabled_any = False
    for platform, owner in owner_map:
        owner = owner.strip()
        lines.append(f"{platform}:")
        if owner:
            enabled_any = True
            lines += ["  enabled: true",
                      "  dm_policy: allowlist",
                      f"  allow_from: [\"{owner}\"]",
                      "  group_policy: disabled"]
            print(f"  {platform}: owner {mask(owner)}")
        else:
            # FAIL CLOSED: sem owner o canal não sobe. Nunca dm_policy: open.
            lines += ["  enabled: false",
                      "  dm_policy: disabled",
                      "  allow_from: []"]
            problems.append(f"{platform}: sem identidade de owner; canal desabilitado")
        lines.append("")

    model = env.get("ASSISTANT_MODEL", "").strip()
    provider = env.get("ASSISTANT_PROVIDER", "").strip()
    if model or provider:
        lines.append("model:")
        if provider:
            lines.append(f"  provider: {provider}")
        if model:
            lines.append(f"  name: {model}")
        lines.append("")

    gateway_yaml = "\n".join(lines)
    gw_path = hermes / "gateway.yaml"
    if not gw_path.is_file() or gw_path.read_text(encoding="utf-8") != gateway_yaml:
        changed.append("gateway.yaml atualizado (acesso e modelo)")
        if not dry:
            gw_path.parent.mkdir(parents=True, exist_ok=True)
            gw_path.write_text(gateway_yaml, encoding="utf-8")
            gw_path.chmod(0o600)

    if not enabled_any:
        problems.append("nenhum canal habilitado: defina ao menos OWNER_TELEGRAM_ID")

    # --- resultado --------------------------------------------------------
    for item in changed:
        print(f"  altera  {item}")
    if not changed:
        print("  nenhuma alteração necessária (já convergido)")

    print("\nLembrete: o gateway.yaml gerado cobre o que confirmamos na "
          "documentação do Hermes.\nConfira a chave de allowlist da sua versão "
          "com 'hermes gateway setup' antes de expor o canal.")

    for item in problems:
        print(f"AVISO: {item}", file=sys.stderr)
    return 3 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
