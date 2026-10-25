"""Check that a Noctalia config keeps every theme template off and sync_color_scheme false.

Usage: check_noctalia.py <config_dir> <settings_toml> [<extra_config_dir>...]

The extra directories are the ones Noctalia really loads (the live config directory); they are skipped when missing.

Noctalia merges every *.toml in its config directory (sorted by name), then applies the GUI override file
settings.toml on top, so a toggle in the settings UI wins over the repo config. This script applies the same
merge and reports anything that would let Noctalia write outside its own directories:

- the built-in or community templates enabled, or any template id listed (the GTK/Qt/KColorScheme templates write
  gtk-*, kdeglobals and the niri config);
- a user template that is not explicitly disabled, unless it only renders a file under ~/.config/niri/ (which Plasma
  never reads) and runs no hook;
- sync_color_scheme not false (upstream default is true; it runs a user-wide gsettings color-scheme write);
- an [include] table in any layer, which this checker cannot expand (UNSUPPORTED INCLUDE).

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


NIRI_DIRS = ("~/.config/niri/", "$XDG_CONFIG_HOME/niri/")
SAFE_TEMPLATE_KEYS = {"input_path", "output_path", "enabled"}


def _renders_into_niri_only(table: dict[str, Any]) -> bool:
    """True for a user template that only writes one file inside the niri config directory and runs no hook.

    Plasma never reads ~/.config/niri, so the wallpaper colors for niri's focus ring may be rendered there. Any other
    key (post_hook, undo_hook, output_path_dynamic, ...) or target fails closed.
    """
    if not set(table) <= SAFE_TEMPLATE_KEYS:
        return False
    output = table.get("output_path")
    if not isinstance(output, str):
        return False
    for prefix in NIRI_DIRS:
        rest = output[len(prefix):] if output.startswith(prefix) else None
        # config.kdl is a stow symlink into the repo; rendering over it would rewrite the repo file.
        if rest and ".." not in Path(rest).parts and rest != "config.kdl":
            return True
    return False


def check(config_dir: Path, settings_toml: Path) -> list[str]:
    """Return one line per violation; an empty list means the merged config is safe for Plasma."""
    merged: dict[str, Any] = {}
    origins: dict[str, str] = {}
    problems: list[str] = []

    # Noctalia only reads regular files, so a directory called x.toml is not a config layer.
    layers = sorted(path for path in config_dir.glob("*.toml") if path.is_file())
    if settings_toml.is_file():
        layers.append(settings_toml)
    for layer in layers:
        try:
            data = _load(layer)
        except _Unreadable:
            problems.append(f"UNREADABLE TOML: {layer}")
            continue
        # Noctalia expands [include] files and `autoload = false` can drop other config files. This checker
        # does not model either, so it fails closed instead of reporting a config it cannot fully see.
        if "include" in data:
            problems.append(f"UNSUPPORTED INCLUDE: {layer}")
        _merge(merged, data, origins, str(layer))

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
            if isinstance(table, dict) and (table.get("enabled") is False or _renders_into_niri_only(table)):
                continue
            prefix = f"theme.templates.user.{name}."
            source = next((src for key, src in origins.items() if key.startswith(prefix)), "unknown")
            problems.append(f"TEMPLATE ENABLED: theme.templates.user.{name} ({source})")

    return problems


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print("usage: check_noctalia.py <config_dir> <settings_toml> [<extra_config_dir>...]", file=sys.stderr)
        return 2
    settings = Path(argv[2])
    problems = check(Path(argv[1]), settings)
    # Extra directories (the live ~/.config/noctalia) are checked too, but only when they exist: a directory that
    # is not stowed yet is not loaded by Noctalia either.
    for extra in argv[3:]:
        if Path(extra).is_dir():
            found = [line for line in check(Path(extra), settings) if line not in problems]
            problems.extend(found)
    for line in problems:
        print(line)
    if problems:
        return 1
    print("OK: all Noctalia templates are off and sync_color_scheme is false")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
