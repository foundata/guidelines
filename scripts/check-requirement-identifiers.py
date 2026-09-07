#!/usr/bin/env python3
"""Check, assign and list the stable requirement identifiers of a guide.

A normative statement is a top-level list item that either contains an RFC 2119
keyword or follows a lead-in paragraph that ends with a colon and carries one,
such as ``**You MUST:**``. Every such item ends with an identifier token:

    `IG0042`<a id="ig0042"></a>

The token is the last thing in the item. Identifiers are sequential, never
reused and independent of the item's position. Retired identifiers are listed
under the heading "Retired requirement identifiers".

Usage:

    check-requirement-identifiers.py [GUIDE]           # verify, exit 1 on error
    check-requirement-identifiers.py --fix [GUIDE]     # assign missing identifiers
    check-requirement-identifiers.py --list [GUIDE]    # print requirements as JSON
    check-requirement-identifiers.py --unlabeled GUIDE # list items without identifier

The exit status is 0 when no error was found and 1 otherwise.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

DEFAULT_GUIDE = Path(__file__).resolve().parent.parent / "oci-container-image-guide.md"
DEFAULT_PREFIX = "IG"
RETIRED_HEADING = "Retired requirement identifiers"

# Sections whose list items are definitions, aims or explanations rather than
# requirements. They carry no identifiers and their keywords are not checked.
EXCLUDED_HEADINGS = frozenset(
    {
        "Table of contents",
        "Goals and scope",
        "Terminology",
        "Requirement identifiers",
        RETIRED_HEADING,
        "Reasoning",
        "Author information",
    }
)

KEYWORD_RE = re.compile(r"\b(MUST NOT|MUST|SHOULD NOT|SHOULD|MAY)\b")
KEYWORD_RANK = {"MUST NOT": 3, "MUST": 3, "SHOULD NOT": 2, "SHOULD": 2, "MAY": 1}
CODE_SPAN_RE = re.compile(r"`[^`]*`")
HEADING_RE = re.compile(
    r"^(#{1,6})\s+(?P<title>.*?)(?:<a id=\"(?P<anchor>[^\"]+)\"></a>)?\s*$"
)
FENCE_RE = re.compile(r"^\s*(`{3,}|~{3,})")
TOP_ITEM_RE = re.compile(r"^(-|\d+\.)\s+(?P<text>.*)$")
NESTED_ITEM_RE = re.compile(r"^\s+(-|\d+\.)\s+")
CONTINUATION_RE = re.compile(r"^\s+\S")
TOKEN_RE = re.compile(
    r"\s*`(?P<visible>(?P<prefix>[A-Z]+)(?P<number>\d{4}))`<a id=\"(?P<anchor>[a-z]+\d{4})\"></a>$"
)
ID_RE = re.compile(r"^(?P<prefix>[A-Z]+)(?P<number>\d{4})$")


@dataclass
class Item:
    """One top-level list item."""

    start: int
    end: int
    lines: list[str]
    section: str
    anchor: str
    excluded: bool
    lead_in: str | None

    @property
    def text(self) -> str:
        """Return the item as one line, including its identifier token."""
        return " ".join(line.strip() for line in self.lines)

    @property
    def keyword(self) -> str | None:
        """Return the item's own strongest RFC 2119 keyword."""
        return strongest_keyword(self.text)

    @property
    def modality(self) -> str | None:
        """Return the effective modality: own keyword, else the lead-in's."""
        return self.keyword or self.lead_in

    @property
    def normative(self) -> bool:
        """Return whether the item must carry an identifier."""
        return not self.excluded and self.modality is not None

    @property
    def token(self) -> re.Match[str] | None:
        """Return the identifier token match at the end of the item."""
        return TOKEN_RE.search(self.text)

    @property
    def identifier(self) -> str | None:
        """Return the visible identifier, such as ``IG0042``."""
        match = self.token
        return match.group("visible") if match else None

    @property
    def statement(self) -> str:
        """Return the item text without its identifier token."""
        return TOKEN_RE.sub("", self.text).strip()


@dataclass
class Guide:
    """Parsed guide."""

    path: Path
    lines: list[str]
    items: list[Item] = field(default_factory=list)
    prose_keywords: list[tuple[int, str]] = field(default_factory=list)
    nested_keywords: list[int] = field(default_factory=list)
    retired: dict[str, str] = field(default_factory=dict)


def strongest_keyword(text: str) -> str | None:
    """Return the strongest RFC 2119 keyword outside code spans, if any."""
    found: list[str] = KEYWORD_RE.findall(CODE_SPAN_RE.sub("", text))
    if not found:
        return None
    return max(found, key=lambda keyword: KEYWORD_RANK[keyword])


def heading_title(match: re.Match[str]) -> str:
    """Return the heading text without its explicit anchor."""
    return match.group("title").strip()


def parse(path: Path) -> Guide:
    """Parse list items, lead-ins, retired identifiers and prose keywords."""
    lines = path.read_text(encoding="utf-8").split("\n")
    guide = Guide(path=path, lines=lines)
    in_code = False
    h2 = ""
    h3 = ""
    anchor = ""
    lead_in: str | None = None
    paragraph: list[tuple[int, str]] = []
    item: Item | None = None

    def excluded() -> bool:
        return not h2 or h2 in EXCLUDED_HEADINGS or h3 in EXCLUDED_HEADINGS

    def in_retired() -> bool:
        return h3 == RETIRED_HEADING or h2 == RETIRED_HEADING

    def close_item() -> None:
        nonlocal item
        if item is not None:
            guide.items.append(item)
            item = None

    def close_paragraph() -> None:
        nonlocal lead_in, paragraph
        if not paragraph:
            return
        text = " ".join(text.strip() for _, text in paragraph)
        stripped = text.rstrip().rstrip("*").rstrip()
        keyword = strongest_keyword(text)
        if stripped.endswith(":") and keyword is not None:
            lead_in = keyword
        else:
            lead_in = None
            if keyword is not None and not excluded():
                guide.prose_keywords.append((paragraph[0][0], text))
        paragraph = []

    for number, line in enumerate(lines, start=1):
        if FENCE_RE.match(line):
            close_item()
            close_paragraph()
            in_code = not in_code
            continue
        if in_code:
            continue
        heading = HEADING_RE.match(line)
        if heading and line.startswith("#"):
            close_item()
            close_paragraph()
            level = len(heading.group(1))
            title = heading_title(heading)
            if level == 1:
                h2, h3 = "", ""
            elif level == 2:
                h2, h3 = title, ""
            else:
                h3 = title
            anchor = heading.group("anchor") or ""
            lead_in = None
            continue
        if not line.strip():
            close_item()
            close_paragraph()
            continue
        top = TOP_ITEM_RE.match(line)
        if top:
            close_item()
            close_paragraph()
            text = top.group("text")
            if in_retired():
                match = CODE_SPAN_RE.search(text)
                if match:
                    guide.retired[match.group(0).strip("`")] = text
                continue
            item = Item(
                start=number,
                end=number,
                lines=[text],
                section=h3 or h2,
                anchor=anchor,
                excluded=excluded(),
                lead_in=lead_in,
            )
            continue
        if NESTED_ITEM_RE.match(line):
            if strongest_keyword(line) and not excluded():
                guide.nested_keywords.append(number)
            if item is not None:
                item.end = number
            continue
        if item is not None and CONTINUATION_RE.match(line):
            item.lines.append(line)
            item.end = number
            continue
        close_item()
        paragraph.append((number, line))
    close_item()
    close_paragraph()
    return guide


def identifier_number(identifier: str) -> int:
    """Return the numeric part of an identifier."""
    match = ID_RE.match(identifier)
    if not match:
        raise ValueError(identifier)
    return int(match.group("number"))


def check(guide: Guide, prefix: str) -> list[str]:
    """Return every error found in the parsed guide."""
    errors: list[str] = []
    seen: dict[str, int] = {}
    location = f"{guide.path.name}"
    for item in guide.items:
        where = f"{location}:{item.start}"
        token = item.token
        if item.excluded:
            if token:
                errors.append(
                    f"{where}: identifier in non-normative section '{item.section}'"
                )
            continue
        if item.normative and token is None:
            errors.append(
                f"{where}: normative list item has no identifier: {item.text[:70]}"
            )
            continue
        if token is None:
            continue
        if not item.normative:
            errors.append(
                f"{where}: identifier on an item without RFC 2119 keyword or normative lead-in"
            )
        visible = token.group("visible")
        if token.group("prefix") != prefix:
            errors.append(f"{where}: identifier {visible} does not use prefix {prefix}")
        if token.group("anchor") != visible.lower():
            errors.append(
                f"{where}: anchor '{token.group('anchor')}' does not match {visible}"
            )
        if visible in seen:
            errors.append(
                f"{where}: duplicate identifier {visible}, first seen at line {seen[visible]}"
            )
        seen[visible] = item.start
        if visible in guide.retired:
            errors.append(f"{where}: retired identifier {visible} is in use")
    for identifier in guide.retired:
        if not ID_RE.match(identifier) or not identifier.startswith(prefix):
            errors.append(f"{location}: malformed retired identifier {identifier}")
    for number, text in guide.prose_keywords:
        errors.append(
            f"{location}:{number}: RFC 2119 keyword outside a list item; make the statement a"
            f" list item with an identifier: {text[:70]}"
        )
    for number in guide.nested_keywords:
        errors.append(
            f"{location}:{number}: nested list items cannot carry requirements"
        )
    return errors


def fix(guide: Guide, prefix: str) -> int:
    """Append the next free identifier to every unlabeled normative item."""
    used = {item.identifier for item in guide.items if item.identifier}
    used.update(guide.retired)
    numbers = [
        identifier_number(identifier) for identifier in used if ID_RE.match(identifier)
    ]
    next_number = max(numbers, default=0) + 1
    assigned = 0
    for item in guide.items:
        if not item.normative or item.token is not None:
            continue
        identifier = f"{prefix}{next_number:04d}"
        next_number += 1
        assigned += 1
        index = item.end - 1
        guide.lines[index] = (
            f'{guide.lines[index]} `{identifier}`<a id="{identifier.lower()}"></a>'
        )
    if assigned:
        guide.path.write_text("\n".join(guide.lines), encoding="utf-8")
    return assigned


def listing(guide: Guide) -> dict[str, object]:
    """Return the machine-readable requirement inventory."""
    requirements = [
        {
            "id": item.identifier,
            "modality": item.modality,
            "section": item.section,
            "anchor": item.anchor,
            "line": item.start,
            "text": item.statement,
        }
        for item in guide.items
        if item.identifier
    ]
    retired = [
        {"id": identifier, "note": note} for identifier, note in guide.retired.items()
    ]
    return {"guide": guide.path.name, "requirements": requirements, "retired": retired}


def main(argv: list[str] | None = None) -> int:
    """Run the selected mode and return the process exit status."""
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n", maxsplit=1)[0])
    parser.add_argument("guide", nargs="?", type=Path, default=DEFAULT_GUIDE)
    parser.add_argument("--prefix", default=DEFAULT_PREFIX, help="identifier prefix")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--fix", action="store_true", help="assign missing identifiers")
    mode.add_argument("--list", action="store_true", help="print requirements as JSON")
    mode.add_argument(
        "--unlabeled",
        action="store_true",
        help="print list items in normative sections that carry no identifier",
    )
    arguments = parser.parse_args(argv)
    guide = parse(arguments.guide)
    if arguments.fix:
        assigned = fix(guide, arguments.prefix)
        print(f"Assigned {assigned} identifier(s)")
        guide = parse(arguments.guide)
    if arguments.list:
        json.dump(listing(guide), sys.stdout, indent=2, ensure_ascii=False)
        print()
        return 0
    if arguments.unlabeled:
        for item in guide.items:
            if not item.excluded and item.identifier is None:
                print(f"{item.start}: [{item.section}] {item.text[:100]}")
        return 0
    errors = check(guide, arguments.prefix)
    for error in errors:
        print(error, file=sys.stderr)
    active = sum(1 for item in guide.items if item.identifier)
    print(
        f"{guide.path.name}: {active} requirement identifier(s), {len(guide.retired)} retired"
    )
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
