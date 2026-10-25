"""Print the safety scan's findings per category: python3 -I -B safety-list.py <repo root> [category] """

import importlib.util
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
want = sys.argv[2] if len(sys.argv) > 2 else None
spec = importlib.util.spec_from_file_location("safety", root / "tests/test_mizu_safety.py")
s = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s)

cats = {
    "writes": s.findings(s.FORBIDDEN_WRITES),
    "hypr": s.findings(s.HYPRLAND_ONLY),
    "sekai": s.findings([r"(?i)sekaipop"], skip_comments=True),
}
programs = []
regex = re.compile(r'(?:command:\s*\[|execDetached\(\s*\[|execDetached\(\s*\{\s*command:\s*\[)\s*"([^"]+)"')
for path, relative in s.scanned_files():
    if path.suffix != ".qml":
        continue
    for number, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
        for program in regex.findall(line):
            if program not in s.ALLOWED_PROGRAMS:
                programs.append(f"{relative}:{number}: starts {program!r}")
cats["programs"] = programs
for name, found in cats.items():
    if want and name != want:
        continue
    print(f"== {name}: {len(found)}")
    for line in found:
        print("  ", line)
