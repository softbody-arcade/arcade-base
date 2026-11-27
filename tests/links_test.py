import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LINK = re.compile(r"\]\(([^)\s]+)\)")
HEADING = re.compile(r"^#{1,6}\s+(.*?)\s*#*\s*$", re.M)


def anchors(path):
    seen = {}
    out = set()
    text = re.sub(r"```.*?```", "", path.read_text(encoding="utf-8"), flags=re.S)
    for title in HEADING.findall(text):
        slug = re.sub(r"[^\w\- ]", "", title.lower().replace("`", "")).replace(" ", "-")
        n = seen.get(slug, 0)
        seen[slug] = n + 1
        out.add(slug if n == 0 else f"{slug}-{n}")
    return out


def check(files):
    failures = []
    for path in files:
        for target in LINK.findall(path.read_text(encoding="utf-8")):
            if re.match(r"^[a-z][a-z0-9+.-]*:", target):
                continue
            file_part, _, fragment = target.partition("#")
            local = (path.parent / file_part).resolve() if file_part else path
            name = path.relative_to(ROOT)
            if not local.is_relative_to(ROOT):
                failures.append(f"{name}: {target} leaves the repo")
            elif not local.exists():
                failures.append(f"{name}: {target} not found")
            elif fragment and local.suffix == ".md" and fragment not in anchors(local):
                failures.append(f"{name}: {target} has no heading #{fragment}")
    return failures


if __name__ == "__main__":
    files = [ROOT / n for n in ("AGENTS.md", "CONTRIBUTING.md", "README.md", "SECURITY.md")]
    files += [p for p in sorted((ROOT / "docs").rglob("*.md")) if ".obsidian" not in p.parts]
    failures = check(files)
    print(f"links: {len(files)} files, {len(failures)} broken")
    for failure in failures:
        print(failure)
    sys.exit(1 if failures else 0)
