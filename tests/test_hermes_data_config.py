#!/usr/bin/env python3
"""Cross-file consistency checks for the hermes-data module.

Plain-python (pytest not installed). Exits nonzero on any check that fails,
which is how a failing suite is surfaced. Run:

    python3 tests/test_hermes_data_config.py
"""
import os
import re
import sys

import yaml

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
CONFIG = os.path.join(ROOT, "hermes-data", "config.yaml")
MEMORY = os.path.join(ROOT, "hermes-data", "memories", "MEMORY.md")


def load():
    with open(CONFIG) as f:
        return yaml.safe_load(f)


def main():
    failures = []
    cfg = load()

    custom = {p["name"]: p for p in cfg["custom_providers"]}

    # 1. Primary provider must resolve to a defined custom provider.
    primary = cfg["provider"]
    assert primary.startswith("custom:"), primary
    pname = primary.split(":", 1)[1]
    if pname not in custom:
        failures.append(f"primary provider {primary!r} names undefined custom provider")

    # 2. Every fallback must resolve to a defined custom provider.
    for fb in cfg["fallback_providers"]:
        fname = fb["provider"].split(":", 1)[1]
        if fname not in custom:
            failures.append(f"fallback {fb['provider']!r} names undefined custom provider")

    # 3. Documented fallback chain (AGENTS.md / MEMORY.md) must be present:
    #    Z.AI -> Groq -> Gemini -> OpenRouter -> local last-resort.
    chain = [fb["provider"].split(":", 1)[1] for fb in cfg["fallback_providers"]]
    for expected in ["zai", "groq", "gemini", "openrouter", "local"]:
        if expected not in chain:
            failures.append(
                f"documented provider {expected!r} is missing from fallback_providers "
                f"(actual chain: {chain})"
            )

    if len(chain) < 3:
        failures.append(f"fallback chain has only {len(chain)} provider(s); "
                        f"any single outage kills the service")

    # 4. Primary must be reachable in the deployed environment (HF Spaces).
    mlx = custom.get("mlx", {})
    if "host.docker.internal" in mlx.get("base_url", ""):
        failures.append(
            "primary custom:mlx base_url is http://host.docker.internal:8090/v1, "
            "which does not resolve on HF Spaces (no Docker-for-Mac host)"
        )

    # 5. Local/keyless providers must not be gated on an unrelated cloud key.
    #    Deploy-per-docs only guarantees API_SERVER_KEY/DATABASE_URL/GROQ_API_KEY,
    #    so a local last-resort pinned to a cloud key silently breaks the chain.
    cloud_keys = ("OPENROUTER_API_KEY", "ZAI_API_KEY", "GROQ_API_KEY", "GEMINI_API_KEY")
    local_hosts = ("http://127.0.0.1", "http://localhost", "http://host.docker.internal")
    for name, p in custom.items():
        if p.get("key_env") in cloud_keys and p.get("base_url", "").startswith(local_hosts):
            failures.append(
                f"provider {name!r} is a keyless local endpoint but is gated on "
                f"{p['key_env']}; cloud secrets must not gate local providers"
            )

    # 6. Memory must be enabled for a 'second brain' (product point).
    if not cfg.get("honcho", {}).get("enabled", False):
        failures.append("honcho.enabled is false; Honcho memory backend is inactive")
    if not cfg.get("memory", {}).get("enabled", False):
        failures.append("memory.enabled is false; agent has no active memory provider")

    # 7. Skills that require mcp-github must have github MCP enabled.
    mcp = cfg.get("mcp_servers", {})
    github_gated = []
    for root, _dirs, files in os.walk(os.path.join(ROOT, "hermes-data", "skills")):
        for fn in files:
            if fn != "SKILL.md":
                continue
            path = os.path.join(root, fn)
            txt = open(path).read()
            if "mcp-github" in txt or "mcp__github" in txt:
                github_gated.append(os.path.relpath(path, os.path.join(ROOT, "hermes-data")))
    if github_gated and not mcp.get("github", {}).get("enabled", False):
        failures.append(
            f"github MCP is disabled but skills require it: {github_gated}"
        )

    # 8. Baked memory claims must match config.
    mem = open(MEMORY).read()
    if "Honcho" in mem and not cfg.get("honcho", {}).get("enabled", False):
        failures.append("MEMORY.md claims self-hosted Honcho but honcho.enabled is false")
    if "Z.AI" in mem and "zai" not in chain:
        failures.append("MEMORY.md claims Z.AI fallback but zai provider is unused")
    if "local" in chain:
        local_model = next(
            fb["model"] for fb in cfg["fallback_providers"] if fb["provider"] == "custom:local"
        )
        if local_model.casefold() not in mem.casefold():
            failures.append(
                f"MEMORY.md names a local last-resort model that is not "
                f"config.yaml's custom:local model '{local_model}'"
            )
    elif "local" in mem:
        failures.append("MEMORY.md claims a local last-resort but 'local' provider is unused")

    # 9. No real secrets committed to the module.
    banned = re.compile(r"(\bsk-[A-Za-z0-9]{16,})|(ghp_[A-Za-z0-9]{20,})|(Bearer\s+[A-Za-z0-9]{10,})")
    for root, _dirs, files in os.walk(os.path.join(ROOT, "hermes-data")):
        for fn in files:
            txt = open(os.path.join(root, fn), errors="ignore").read()
            if banned.search(txt):
                failures.append(f"possible secret literal in {os.path.join(root, fn)}")

    if failures:
        print(f"hermes-data config checks FAILED ({len(failures)}):")
        for f in failures:
            print(f"  - {f}")
        return 1
    print("hermes-data config checks OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())