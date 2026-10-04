#!/usr/bin/env python3
"""Check that Fastlane's store fields match APPSTORE-METADATA.md."""

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "APPSTORE-METADATA.md"
METADATA = ROOT / "fastlane/metadata"


def section(markdown: str, heading: str) -> str:
    match = re.search(
        rf"^## {re.escape(heading)}\s*$\n(.*?)(?=^## |\Z)",
        markdown,
        flags=re.MULTILINE | re.DOTALL,
    )
    if not match:
        raise ValueError(f"missing section: {heading}")
    return match.group(1)


def code_field(markdown: str, heading: str) -> str:
    match = re.search(r"```\n(.*?)```", section(markdown, heading), flags=re.DOTALL)
    if not match:
        raise ValueError(f"missing text block in section: {heading}")
    return match.group(1).removesuffix("\n")


def table_value(markdown: str, heading: str, label: str) -> str:
    match = re.search(
        rf"^\| {re.escape(label)} \| (.*?) \|$",
        section(markdown, heading),
        flags=re.MULTILINE,
    )
    if not match:
        raise ValueError(f"missing {label} in section: {heading}")
    return match.group(1)


def expected_fields(markdown: str) -> dict[str, str]:
    copyright_match = re.search(r"^## Copyright\s*\n([^\n]+)", markdown, re.MULTILINE)
    if not copyright_match:
        raise ValueError("missing copyright field")
    return {
        "default/copyright.txt": copyright_match.group(1),
        "en-US/name.txt": table_value(markdown, "Identity", "Name"),
        "en-US/subtitle.txt": table_value(markdown, "Identity", "Subtitle"),
        "en-US/description.txt": code_field(markdown, "Description"),
        "en-US/keywords.txt": code_field(markdown, "Keywords"),
        "en-US/promotional_text.txt": code_field(markdown, "Promotional Text"),
        "en-US/support_url.txt": table_value(markdown, "Support and Privacy URLs", "Support URL"),
        "en-US/privacy_url.txt": table_value(markdown, "Support and Privacy URLs", "Privacy Policy URL"),
        "en-US/marketing_url.txt": table_value(markdown, "Support and Privacy URLs", "Marketing URL"),
        "en-US/release_notes.txt": "Initial release.",
    }


def main() -> int:
    try:
        expected = expected_fields(SOURCE.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        print(f"metadata source error: {error}", file=sys.stderr)
        return 1

    actual_paths = {
        path.relative_to(METADATA).as_posix()
        for path in METADATA.rglob("*")
        if path.is_file()
    }
    errors = []
    for relative_path, value in expected.items():
        path = METADATA / relative_path
        if not path.is_file():
            errors.append(f"missing: {relative_path}")
            continue
        if path.read_bytes() != value.encode("utf-8"):
            errors.append(f"mismatch: {relative_path}")
    for relative_path in sorted(actual_paths - expected.keys()):
        errors.append(f"unmapped metadata file: {relative_path}")

    if errors:
        print("Fastlane metadata check failed:")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print(f"Fastlane metadata matches APPSTORE-METADATA.md ({len(expected)} fields).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
