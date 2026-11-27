import pathlib
import re
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
FENCE = re.compile(r"^(`{3,}|~{3,}).*?^\1[ \t]*$", re.M | re.S)
CODE = re.compile(r"(`+)(?:(?!\1).)+?\1", re.S)
INLINE = re.compile(r"!?\[(?:[^\[\]]|\[[^\]]*\])*\]\(\s*(<[^>]*>|[^\s)]+)(?:\s+(?:\"[^\"]*\"|'[^']*'|\([^)]*\)))?\s*\)")
REFERENCE = re.compile(r"^ {0,3}\[[^\]]+\]:\s*(<[^>]*>|\S+)", re.M)
HEADING = re.compile(r"^#{1,6}\s+(.*?)\s*#*\s*$", re.M)


def prose(text):
    return CODE.sub("", FENCE.sub("", text))


def targets(text):
    text = prose(text)
    found = INLINE.findall(text) + REFERENCE.findall(text)
    return [t[1:-1] if t.startswith("<") else t for t in found]


def anchors(path):
    seen = {}
    out = set()
    for title in HEADING.findall(FENCE.sub("", path.read_text(encoding="utf-8"))):
        slug = re.sub(r"[^\w\- ]", "", title.lower().replace("`", "")).replace(" ", "-")
        n = seen.get(slug, 0)
        seen[slug] = n + 1
        out.add(slug if n == 0 else f"{slug}-{n}")
    return out


def check(files, root=ROOT):
    failures = []
    for path in files:
        for target in targets(path.read_text(encoding="utf-8")):
            if re.match(r"^[a-z][a-z0-9+.-]*:", target):
                continue
            file_part, _, fragment = target.partition("#")
            local = (path.parent / file_part).resolve() if file_part else path
            name = path.relative_to(root)
            if not local.is_relative_to(root):
                failures.append(f"{name}: {target} leaves the repo")
            elif not local.exists():
                failures.append(f"{name}: {target} not found")
            elif fragment and local.suffix == ".md" and fragment not in anchors(local):
                failures.append(f"{name}: {target} has no heading #{fragment}")
    return failures


def selftest():
    cases = [
        ("[a](missing.md)", 1),
        ('[a](missing.md "Title")', 1),
        ("[a](<missing.md>)", 1),
        ("[a]: missing.md", 1),
        ('[a]: missing.md "Title"', 1),
        ("![img](missing.png)", 1),
        ("[a](ok.md)", 0),
        ("[a](ok.md#real-heading)", 0),
        ("[a](ok.md#no-such-heading)", 1),
        ("[a](#local)\n\n## Local", 0),
        ("[a](#nope)", 1),
        ("`[a](missing.md)`", 0),
        ("```\n[a](missing.md)\n```", 0),
        ("[a](https://example.com/missing.md)", 0),
        ("[a](../outside.md)", 1),
    ]
    errors = []
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp).resolve() / "repo"
        root.mkdir()
        (root / "ok.md").write_text("# Real heading\n", encoding="utf-8")
        (pathlib.Path(tmp) / "outside.md").write_text("x\n", encoding="utf-8")
        for i, (text, expected) in enumerate(cases):
            doc = root / f"case{i}.md"
            doc.write_text(text + "\n", encoding="utf-8")
            got = len(check([doc], root))
            if got != expected:
                errors.append(f"selftest {text!r}: {got} broken, expected {expected}")
    return errors


if __name__ == "__main__":
    errors = selftest()
    files = [ROOT / n for n in ("AGENTS.md", "CONTRIBUTING.md", "README.md", "SECURITY.md")]
    files += [p for p in sorted((ROOT / "docs").rglob("*.md")) if ".obsidian" not in p.parts]
    failures = check(files)
    print(f"links: {len(files)} files, {len(failures)} broken, {len(errors)} self-test failures")
    for line in errors + failures:
        print(line)
    sys.exit(1 if errors or failures else 0)
