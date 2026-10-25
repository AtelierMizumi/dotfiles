"""List files of the mizu shell that nothing refers to.

A QML file is used when its type name (the file name without .qml) appears as a word in another QML or JS file; a JS
library, a script under scripts/ and an asset are used when their file name appears in any text file of the tree.
shell.qml is the entry point. Usage: orphans.py <mizu dir>   (prints one path per line, nothing when all are used)
"""

import re
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
TEXT = {".qml", ".js", ".sh", ".py", ".json", ".conf", ".txt", ".md"}
SKIP_DIRS = {"palette"}  # the python tool has its own tests; its files refer to each other by import

files = [p for p in root.rglob("*") if p.is_file() and not (set(p.relative_to(root).parts) & SKIP_DIRS)]
texts = {p: p.read_text(errors="replace") for p in files if p.suffix in TEXT}
words = {}
for path, text in texts.items():
    for word in set(re.findall(r"[A-Za-z_][A-Za-z0-9_]*", text)):
        words.setdefault(word, set()).add(path)

orphans = []
for path in sorted(files):
    if path.name in {"shell.qml", "UPSTREAM.md", "LICENSE", "CLAUDE-SESSION-LIMIT.txt"}:
        continue
    users = set()
    if path.suffix == ".qml":
        users = words.get(path.stem, set()) - {path}
    else:
        # by file name; paths are written as "dir/name.ext" or built from a dir plus the name
        users = {p for p, t in texts.items() if path.name in t and p != path}
    if not users:
        orphans.append(path.relative_to(root))

for orphan in orphans:
    print(orphan)
