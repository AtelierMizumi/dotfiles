"""List capitalized names used in the forked QML that resolve to no file of the tree and no Qt / Quickshell type.

Usage: python3 -I -B unresolved.py <mizu dir> [--files NAME]   (prints counts per name, or the files using NAME)
"""

import re
import sys
from collections import defaultdict
from pathlib import Path

mizu = Path(sys.argv[1])
system_qml = Path("/usr/lib/qt6/qml")

builtins = set("Math JSON Date Object Array String Number Qt Boolean Promise Error RegExp Infinity NaN Symbol Map Set "
               "Intl TypeError ReferenceError SyntaxError RangeError Function Quickshell".split())
for base in (system_qml,):
    if not base.exists():
        continue
    for path in base.rglob("*"):
        if path.suffix == ".qmltypes":
            text = path.read_text(errors="replace")
            for exports in re.findall(r"exports:\s*\[([^\]]*)\]", text):
                for item in re.findall(r'"[\w.]+/(\w+)(?:\s+[\d.]+)?"', exports):
                    builtins.add(item)
            builtins.update(re.findall(r'\bname:\s*"([A-Z]\w+)"', text))
        elif path.name == "qmldir":
            for line in path.read_text(errors="replace").splitlines():
                m = re.match(r"(?:singleton\s+|internal\s+)?([A-Z]\w+)\s+[\d.]+", line)
                if m:
                    builtins.add(m.group(1))

local = {p.stem for p in mizu.rglob("*.qml")}
# Pragma-library JS modules are imported with `import "path/X.js" as X`.
aliases = defaultdict(set)
name_re = re.compile(r"(?<![\w.\"'])([A-Z][A-Za-z0-9_]*)\b(?=\s*[{.(]|\s*$)")
unresolved = defaultdict(lambda: defaultdict(int))
for path in sorted(mizu.rglob("*.qml")):
    text = path.read_text(errors="replace")
    declared = set(re.findall(r"import\s+\"[^\"]+\"\s+as\s+([A-Z]\w+)", text))
    declared |= set(re.findall(r"import\s+[\w.]+(?:\s+[\d.]+)?\s+as\s+([A-Z]\w+)", text))
    declared |= set(re.findall(r"(?:property|signal|enum|component)\s+(?:\w+\s+)?([A-Z]\w+)", text))
    declared |= set(re.findall(r"\benum\s+([A-Z]\w+)", text))
    declared |= set(re.findall(r"\bcomponent\s+([A-Z]\w+)\s*:", text))
    for number, line in enumerate(text.splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith(("//", "*", "/*")):
            continue
        code = re.sub(r"//.*$", "", re.sub(r'"(?:[^"\\]|\\.)*"', '""', line))
        for name in name_re.findall(code):
            if name in local or name in builtins or name in declared:
                continue
            unresolved[name][str(path.relative_to(mizu))] += 1

if len(sys.argv) > 3 and sys.argv[2] == "--files":
    for file, count in sorted(unresolved.get(sys.argv[3], {}).items()):
        print(f"{count:4d} {file}")
else:
    for name, files in sorted(unresolved.items(), key=lambda kv: -sum(kv[1].values())):
        print(f"{sum(files.values()):5d} {len(files):3d} files  {name}")
