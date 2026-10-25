"""Properties read as mt.X / Theme.X / theme.X in the forked tree that ThemeSet.qml does not define."""

import re
import sys
from collections import Counter
from pathlib import Path

mizu = Path(sys.argv[1])
defined = set()
text = (mizu / "modules/common/ThemeSet.qml").read_text()
defined |= set(re.findall(r"(?:readonly\s+)?property\s+\w+\s+(\w+)", text))
defined |= set(re.findall(r"function\s+(\w+)", text))
defined |= {"of"}
used = Counter()
where = {}
for path in mizu.rglob("*.qml"):
    if path.name in ("ThemeSet.qml", "Theme.qml"):
        continue
    for number, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
        for name in re.findall(r"\b(?:mt|Theme|theme|mtheme|tm)\.([A-Za-z_]\w*)", line):
            used[name] += 1
            where.setdefault(name, f"{path.relative_to(mizu)}:{number}")
for name, count in used.most_common():
    if name not in defined:
        print(f"{count:4d} {name:28s} e.g. {where[name]}")
