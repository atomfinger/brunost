#!/usr/bin/env python3
"""
Extract and run all Brunost code snippets from README.md.

Snippets are fenced code blocks tagged ```python (GitHub renders them with
Python highlighting, but the content is valid Brunost). Blocks tagged with
'skip' or 'ignore' are excluded.

Usage:
    python3 scripts/run_readme_snippets.py [options]

Options:
    --readme PATH     Path to README file  (default: README.md)
    --brunost PATH    Path to brunost binary (default: ./zig-out/bin/brunost)
    --out-dir DIR     Directory for extracted snippets (default: readme-snippets)
    --extract-only    Extract snippets without running them
    --help            Show this message and exit
"""

import argparse
import os
import re
import subprocess
import sys


FENCE_RE = re.compile(r'^```python(?:\s+(.+))?$')
CLOSE_RE = re.compile(r'^```\s*$')
SKIP_TAGS = {"skip", "ignore"}


def extract_snippets(readme_path: str) -> list[tuple[int, str]]:
    """
    Return a list of (line_number, code) for each non-skipped snippet.
    line_number is the 1-based line of the opening fence.
    """
    snippets = []
    with open(readme_path, encoding="utf-8") as f:
        lines = f.readlines()

    inside = False
    skip = False
    start_line = 0
    current: list[str] = []

    for i, line in enumerate(lines, start=1):
        stripped = line.rstrip("\n")
        m = FENCE_RE.match(stripped)
        if m and not inside:
            inside = True
            tags = set((m.group(1) or "").split())
            skip = bool(tags & SKIP_TAGS)
            start_line = i
            current = []
            continue

        if CLOSE_RE.match(stripped) and inside:
            inside = False
            if not skip and current:
                snippets.append((start_line, "".join(current)))
            skip = False
            current = []
            continue

        if inside and not skip:
            current.append(line)

    return snippets


def write_snippets(snippets: list[tuple[int, str]], out_dir: str) -> list[str]:
    """Write snippets to files and return the list of file paths."""
    os.makedirs(out_dir, exist_ok=True)

    # Remove old snippets so stale files don't linger
    for entry in os.scandir(out_dir):
        if entry.name.endswith(".brunost"):
            os.remove(entry.path)

    paths = []
    for idx, (line_no, code) in enumerate(snippets, start=1):
        path = os.path.join(out_dir, f"snippet-{idx:02d}.brunost")
        with open(path, "w", encoding="utf-8") as f:
            f.write(code)
        paths.append((path, line_no))
        print(f"  Skreiv {path}  (frå linje {line_no})")

    return paths


def run_snippets(paths: list[tuple[str, int]], brunost: str) -> bool:
    """Run each snippet. Returns True if all passed."""
    all_ok = True
    for path, line_no in paths:
        result = subprocess.run(
            [brunost, path],
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            print(f"  ✓  {path}")
        else:
            print(f"  ✗  {path}  (frå linje {line_no})")
            if result.stdout:
                for l in result.stdout.splitlines():
                    print(f"       {l}")
            if result.stderr:
                for l in result.stderr.splitlines():
                    print(f"       {l}")
            all_ok = False

    return all_ok


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Extract and run Brunost snippets from README.md",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--readme",  default="README.md", help="Path to README file")
    parser.add_argument("--brunost", default="./zig-out/bin/brunost", help="Path to brunost binary")
    parser.add_argument("--out-dir", default="readme-snippets", help="Output directory for snippets")
    parser.add_argument("--extract-only", action="store_true", help="Only extract, do not run")
    args = parser.parse_args()

    if not os.path.isfile(args.readme):
        print(f"Feil: finn ikkje README-fila '{args.readme}'", file=sys.stderr)
        return 1

    if not args.extract_only and not os.path.isfile(args.brunost):
        print(f"Feil: finn ikkje brunost-binærfila '{args.brunost}'", file=sys.stderr)
        print("Tips: køyr 'zig build' fyrst", file=sys.stderr)
        return 1

    print(f"Hentar snutter frå {args.readme} …")
    snippets = extract_snippets(args.readme)
    print(f"  Fann {len(snippets)} snutter")

    print(f"\nSkriv til {args.out_dir}/ …")
    paths = write_snippets(snippets, args.out_dir)

    if args.extract_only:
        print("\nFerdig (berre uttrekk, køyrer ikkje).")
        return 0

    print(f"\nKøyrer snutter med {args.brunost} …")
    ok = run_snippets(paths, args.brunost)

    if ok:
        print(f"\nAlle {len(paths)} snutter gjekk gjennom ✓")
        return 0
    else:
        print(f"\nFeil: nokre snutter feila", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
