#!/usr/bin/env python3
"""Inspeciona o controle de acesso por canal no config.json do Nanobot.

Somente leitura. Nunca imprime identificador completo.

    python3 check_access.py <config.json>

Saída: uma linha por canal — "<canal>\t<estado>\t<detalhe>"
Exit: 0 tudo fechado | 1 avisos | 2 acesso aberto ou config ilegível
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

PERSONAL_CHANNELS = ("telegram", "whatsapp", "email", "slack", "discord",
                     "matrix", "signal", "wechat", "dingtalk", "qq", "feishu")


def mask(value: str) -> str:
    if not isinstance(value, str) or not value:
        return "(vazio)"
    if "@" in value:
        user, _, domain = value.partition("@")
        return f"{user[:1]}***@{domain}"
    return f"(...{value[-4:]})" if len(value) > 4 else "(curto)"


def main() -> int:
    if len(sys.argv) != 2:
        print("uso: check_access.py <config.json>", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    if not path.exists():
        print("config\tMISSING\tconfig.json não encontrado")
        return 1
    try:
        config = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as exc:
        print(f"config\tERROR\tconfig.json ilegível: {type(exc).__name__}")
        return 2
    if not isinstance(config, dict):
        print("config\tERROR\tconfig.json não é um objeto")
        return 2

    channels = config.get("channels")
    if not isinstance(channels, dict) or not channels:
        print("channels\tNONE\tnenhum canal configurado")
        return 1

    worst = 0
    for name in PERSONAL_CHANNELS:
        section = channels.get(name)
        if not isinstance(section, dict):
            continue
        enabled = section.get("enabled") is True
        allow = section.get("allowFrom")

        if not enabled:
            print(f"{name}\tDISABLED\tcanal desabilitado")
            continue
        if allow == ["*"]:
            # Acesso aberto em canal pessoal: qualquer um alcança o agente.
            print(f"{name}\tERROR\tallowFrom wildcard: acesso aberto")
            worst = max(worst, 2)
            continue
        if allow is None:
            # Sem allowFrom o Nanobot entra em modo pairing. Não é aberto, mas
            # também não é o determinismo que este MVP pede.
            print(f"{name}\tWARN\tsem allowFrom: modo pairing, não owner-only")
            worst = max(worst, 1)
            continue
        if not isinstance(allow, list) or not allow:
            print(f"{name}\tWARN\tallowFrom vazio com canal habilitado")
            worst = max(worst, 1)
            continue
        if any(not isinstance(x, str) or not x.strip() for x in allow):
            print(f"{name}\tWARN\tallowFrom com entrada vazia ou inválida")
            worst = max(worst, 1)
            continue
        if len(allow) == 1:
            print(f"{name}\tOK\towner-only {mask(allow[0])}")
        else:
            print(f"{name}\tWARN\t{len(allow)} identidades autorizadas")
            worst = max(worst, 1)

    return worst


if __name__ == "__main__":
    sys.exit(main())
