#!/usr/bin/env python3
"""Asserções sobre o config.json do Nanobot, para a suíte local.

    assert_config.py <config.json> <assertion>

Exit 0 quando a asserção vale.
"""
import json
import sys
from pathlib import Path

path, what = Path(sys.argv[1]), sys.argv[2]
OWNER = "123456789"

if what == "set-wildcard":
    cfg = json.loads(path.read_text())
    cfg["channels"]["telegram"]["allowFrom"] = ["*"]
    path.write_text(json.dumps(cfg, indent=2))
    sys.exit(0)

cfg = json.loads(path.read_text())
tg = cfg.get("channels", {}).get("telegram", {})

if what == "owner-applied":
    ok = tg.get("allowFrom") == [OWNER] and tg.get("enabled") is True
elif what == "preserved":
    ok = (cfg.get("outraOpcao") is True
          and cfg["providers"]["groq"]["apiKey"] == "${GROQ_KEY}"
          and tg.get("token") == "${TELEGRAM_TOKEN}"
          and cfg["channels"]["slack"] == {"enabled": False})
elif what == "fail-closed":
    ok = tg.get("enabled") is False and tg.get("allowFrom") == []
elif what == "only-owner":
    allow = tg.get("allowFrom")
    ok = allow == [OWNER] and "987654321" not in allow and "*" not in allow
else:
    print(f"asserção desconhecida: {what}", file=sys.stderr)
    sys.exit(2)

sys.exit(0 if ok else 1)
