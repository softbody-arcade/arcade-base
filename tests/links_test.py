import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LINK = re.compile(r"\]\(([^)\s]+)\)")
failures = []
files = [ROOT / "AGENTS.md", ROOT / "CONTRIBUTING.md", ROOT / "README.md", ROOT / "SECURITY.md", *sorted((ROOT / "docs").rglob("*.md"))]
for path in files:
    if ".obsidian" in path.parts:
        continue
    for target in LINK.findall(path.read_text(encoding="utf-8")):
        if re.match(r"^[a-z][a-z0-9+.-]*:", target) or target.startswith("#"):
            continue
        local = (path.parent / target.split("#", 1)[0]).resolve()
        if not local.is_relative_to(ROOT):
            failures.append(f"{path.relative_to(ROOT)}: {target} leaves the repo")
        elif not local.exists():
            failures.append(f"{path.relative_to(ROOT)}: {target} not found")
print(f"links: {len(files)} files, {len(failures)} broken")
for failure in failures:
    print(failure)
sys.exit(1 if failures else 0)
