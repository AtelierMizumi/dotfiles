"""Check that a Noctalia config keeps every theme template off and sync_color_scheme false.

Usage: check_noctalia.py <config_dir> <settings_toml>

Noctalia merges every *.toml in its config directory (sorted by name), then applies the GUI override file
settings.toml on top, so a toggle in the settings UI wins over the repo config. This script applies the same
merge and reports anything that would let Noctalia write outside its own directories:

- the built-in or community templates enabled, or any template id listed (the GTK/Qt/KColorScheme templates write
  gtk-*, kdeglobals and the niri config);
- a user template that is not explicitly disabled;
- sync_color_scheme not false (upstream default is true; it runs a user-wide gsettings color-scheme write).

Exit codes: 0 no violation, 1 violation found, 2 usage error.
"""

from __future__ import annotations

import sys
import tomllib
from pathlib import Path
from typing import Any

UPSTREAM_DEFAULT = "upstream default"
FLAG_KEYS = ("enable_builtin_templates", "enable_community_templates")
ID_KEYS = ("builtin_ids", "community_ids")


class _Unreadable(Exception):
    pass


def _load(path: Path) -> dict[str, Any]:
    try:
        with path.open("rb") as handle:
            return tomllib.load(handle)
    except (OSError, tomllib.TOMLDecodeError) as exc:
        raise _Unreadable(str(path)) from exc


def _record(origins: dict[str, str], dotted: str, value: Any, source: str) -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            _record(origins, f"{dotted}.{key}", child, source)
    else:
        origins[dotted] = source


def _merge(base: dict[str, Any], extra: dict[str, Any], origins: dict[str, str], source: str, prefix: str = "") -> None:
    for key, value in extra.items():
        dotted = f"{prefix}{key}"
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            _merge(base[key], value, origins, source, f"{dotted}.")
        else:
            base[key] = value
            _record(origins, dotted, value, source)


def _get(config: dict[str, Any], *path: str) -> Any:
    node: Any = config
    for key in path:
        if not isinstance(node, dict) or key not in node:
            return None
        node = node[key]
    return node


def _where(origins: dict[str, str], dotted: str) -> str:
    return origins.get(dotted, UPSTREAM_DEFAULT)


def check(config_dir: Path, settings_toml: Path) -> list[str]:
    """Return one line per violation; an empty list means the merged config is safe for Plasma."""
    merged: dict[str, Any] = {}
    origins: dict[str, str] = {}
    problems: list[str] = []

    layers = sorted(config_dir.glob("*.toml"))
    if settings_toml.exists():
        layers.append(settings_toml)
    for layer in layers:
        try:
            _merge(merged, _load(layer), origins, str(layer))
        except _Unreadable:
            problems.append(f"UNREADABLE TOML: {layer}")

    if _get(merged, "theme", "sync_color_scheme") is not False:
        key = "theme.sync_color_scheme"
        problems.append(f"SYNC_COLOR_SCHEME NOT FALSE: {key} ({_where(origins, key)})")

    for name in FLAG_KEYS:
        if _get(merged, "theme", "templates", name) is not False:
            key = f"theme.templates.{name}"
            problems.append(f"TEMPLATE ENABLED: {key} ({_where(origins, key)})")

    for name in ID_KEYS:
        if _get(merged, "theme", "templates", name):
            key = f"theme.templates.{name}"
            problems.append(f"TEMPLATE ENABLED: {key} ({_where(origins, key)})")

    user_templates = _get(merged, "theme", "templates", "user")
    if isinstance(user_templates, dict):
        for name, table in user_templates.items():
            if isinstance(table, dict) and table.get("enabled") is False:
                continue
            prefix = f"theme.templates.user.{name}."
            source = next((src for key, src in origins.items() if key.startswith(prefix)), "unknown")
            problems.append(f"TEMPLATE ENABLED: theme.templates.user.{name} ({source})")

    return problems


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("usage: check_noctalia.py <config_dir> <settings_toml>", file=sys.stderr)
        return 2
    problems = check(Path(argv[1]), Path(argv[2]))
    for line in problems:
        print(line)
    if problems:
        return 1
    print("OK: all Noctalia templates are off and sync_color_scheme is false")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
