#!/usr/bin/env python3
"""Generate an explicit Table of Contents markdown file.

Usage:
    python3 scripts/gen_toc.py <section1.md> <section2.md> ...

The script scans provided markdown files for headings (#, ##) and outputs
`docs/00-table-of-contents.md` with anchor links that match Pandoc's
identifier generation (basic approximation).
"""
from __future__ import annotations
import re
import sys
from pathlib import Path

OUTFILE = Path("docs/00-table-of-contents.md")

HEADING_PATTERN = re.compile(r"^(#{1,6})\s+(.+?)\s*$")

# Simplified slugification mimicking Pandoc's default behavior for most cases.
def slugify(text: str) -> str:
    text = text.strip().lower()
    # Remove anything that's not alphanumeric, space, or hyphen
    text = re.sub(r"[^a-z0-9\s-]", "", text)
    # Collapse whitespace to single hyphen
    text = re.sub(r"[\s-]+", "-", text)
    return text


def parse_headings(path: Path):
    headings = []
    with path.open("r", encoding="utf-8") as f:
        for line in f:
            m = HEADING_PATTERN.match(line)
            if not m:
                continue
            hashes, title = m.groups()
            level = len(hashes)
            headings.append((level, title.strip()))
    return headings


def main(files: list[str]):
    if not files:
        print("No input files provided", file=sys.stderr)
        return 1

    toc_lines = ["# Table of Contents", ""]

    for file in files:
        path = Path(file)
        if not path.exists():
            print(f"Warning: {file} does not exist; skipping", file=sys.stderr)
            continue
        headings = parse_headings(path)
        for level, title in headings:
            if level > 3:
                continue  # Keep TOC concise
            anchor = slugify(title)
            indent = "  " * (level - 1)
            toc_lines.append(f"{indent}- [{title}](#{anchor})")

    toc_lines.append("\n<div class=\"page-break\"></div>")

    OUTFILE.parent.mkdir(parents=True, exist_ok=True)
    OUTFILE.write_text("\n".join(toc_lines) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
