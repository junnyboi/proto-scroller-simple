from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "localization/zh-CN.json"
OUTPUT = ROOT / "assets/fonts/DroidSansFallbackFull-ProtoScroller.ttf"
DEFAULT_SOURCE = Path("/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf")


def collect_characters(value: Any, characters: set[str]) -> None:
    if isinstance(value, str):
        characters.update(value)
    elif isinstance(value, dict):
        for child in value.values():
            collect_characters(child, characters)
    elif isinstance(value, list):
        for child in value:
            collect_characters(child, characters)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Subset DroidSansFallbackFull to the current zh-CN catalog."
    )
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    if not args.source.is_file():
        raise SystemExit(f"Missing Apache-2.0 source font: {args.source}")
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    characters: set[str] = set()
    collect_characters(catalog, characters)
    characters.update(">ADENSPCTB[]/·")
    unicodes = sorted({ord(character) for character in characters if ord(character) > 0})

    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.name_legacy = True
    options.name_languages = ["*"]
    options.notdef_glyph = True
    options.notdef_outline = True
    options.recommended_glyphs = True
    options.glyph_names = True
    options.symbol_cmap = True
    options.legacy_cmap = True

    font = TTFont(args.source, recalcTimestamp=False)
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(unicodes=unicodes)
    subsetter.subset(font)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    font.save(args.output, reorderTables=True)
    print(
        json.dumps(
            {
                "source": str(args.source),
                "output": str(args.output),
                "codepoints": len(unicodes),
                "bytes": args.output.stat().st_size,
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
