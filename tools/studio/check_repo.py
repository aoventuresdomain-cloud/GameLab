#!/usr/bin/env python3
"""Repository checks for GameLab: layout, board format, the kit boundary and no money figures.

Exits non-zero with one line per problem. Run from anywhere: python3 tools/studio/check_repo.py
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

REQUIRED_PATHS = [
    "README.md",
    "CLAUDE.md",
    "studio/board.md",
    "studio/slate.md",
    "studio/handoffs",
    "studio/playbook",
    "kit/plugin.cfg",
    "kit/sim",
    "kit/packs",
    "kit/services",
    "kit/schema",
    "kit/tests",
    "agents",
    "tools/botplay",
    "tools/release",
    "games",
]

ITEM_HEADING = re.compile(r"^### ([A-Z]+(?:-[A-Z0-9]+)+) \S")
OWNER_LINE = re.compile(r"^- \*\*Owner:\*\* \S")
DONE_WHEN_LINE = re.compile(r"^- \*\*Done when:\*\*\s*$")
CHECKBOX_LINE = re.compile(r"^\s+- \[[ x]\] \S")
# Files in kit/ that are scanned for game names.
# The repository is public: no prices or money figures in committed text.
MONEY = re.compile(r"[£€]\s?\d")
SCANNED_SUFFIXES = {".md", ".gd", ".cfg", ".json", ".tscn", ".tres", ".py", ".yml", ".yaml", ".txt"}
KIT_TEXT_SUFFIXES = {".gd", ".cfg", ".json", ".md", ".tscn", ".tres", ".gdshader"}


def check_layout(problems):
    for rel in REQUIRED_PATHS:
        if not (ROOT / rel).exists():
            problems.append(f"layout: missing {rel}")
    for game in game_dirs():
        if not (game / "plan.md").is_file():
            problems.append(f"layout: games/{game.name} has no plan.md")


def game_dirs():
    games = ROOT / "games"
    return sorted(p for p in games.iterdir() if p.is_dir()) if games.is_dir() else []


def parse_items(text):
    """Return {item_id: [lines]} for every ### item heading in the board."""
    items, current, seen = {}, None, []
    for line in text.splitlines():
        if line.startswith("#"):
            current = None
            match = ITEM_HEADING.match(line)
            if match:
                current = match.group(1)
                seen.append(current)
                items[current] = []
            continue
        if current:
            items[current].append(line)
    return items, seen


def check_board(problems):
    board = ROOT / "studio/board.md"
    if not board.is_file():
        return
    items, seen = parse_items(board.read_text(encoding="utf-8"))
    if not items:
        problems.append("board: no items found")
    for item_id in {i for i in seen if seen.count(i) > 1}:
        problems.append(f"board: {item_id} appears more than once")
    for item_id, lines in items.items():
        owners = [l for l in lines if OWNER_LINE.match(l)]
        if len(owners) != 1:
            problems.append(f"board: {item_id} needs exactly one Owner line, found {len(owners)}")
        try:
            start = next(i for i, l in enumerate(lines) if DONE_WHEN_LINE.match(l))
        except StopIteration:
            problems.append(f"board: {item_id} has no Done when list")
            continue
        count = 0
        for line in lines[start + 1:]:
            if CHECKBOX_LINE.match(line):
                count += 1
            elif line.strip():
                break
        if not 2 <= count <= 5:
            problems.append(f"board: {item_id} has {count} Done when lines (needs 2-5)")


def check_kit_boundary(problems):
    names = [g.name.lower() for g in game_dirs()]
    kit = ROOT / "kit"
    if not names or not kit.is_dir():
        return
    pattern = re.compile(r"\b(" + "|".join(map(re.escape, names)) + r")\b", re.IGNORECASE)
    for path in sorted(kit.rglob("*")):
        if not path.is_file() or path.suffix not in KIT_TEXT_SUFFIXES:
            continue
        rel = path.relative_to(ROOT)
        if pattern.search(str(rel)):
            problems.append(f"kit boundary: {rel} names a game")
        for n, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            if pattern.search(line):
                problems.append(f"kit boundary: {rel}:{n} names a game")


def check_no_money(problems):
    for path in sorted(ROOT.rglob("*")):
        if ".git" in path.parts or not path.is_file() or path.suffix not in SCANNED_SUFFIXES:
            continue
        rel = path.relative_to(ROOT)
        for n, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            if MONEY.search(line):
                problems.append(f"public repo: {rel}:{n} has a money figure")


def main():
    problems = []
    check_layout(problems)
    check_board(problems)
    check_kit_boundary(problems)
    check_no_money(problems)
    for problem in problems:
        print(problem)
    if problems:
        print(f"{len(problems)} problem(s) found")
        return 1
    print("Repository checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
