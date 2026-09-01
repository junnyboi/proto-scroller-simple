#!/usr/bin/env python3
"""Generate before/after evidence for Phase 2 texture import normalization."""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

from PIL import Image

REPO = Path(__file__).resolve().parents[1]
GAME = REPO / "game"
OUTPUT = REPO / "docs" / "manifests" / "asset_optimization_phase2_textures.json"
TARGETS = {
    "enemy_archetypes": GAME / "art" / "city" / "enemies" / "archetypes",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_value(text: str, key: str) -> str:
    match = re.search(rf"^{re.escape(key)}=(.+)$", text, re.MULTILINE)
    if not match:
        raise ValueError(f"Missing {key}")
    return match.group(1).strip().strip('"')


def relative_res(path: Path) -> str:
    return "res://" + path.relative_to(GAME).as_posix()


def inspect(group: str, import_file: Path) -> dict[str, Any]:
    text = import_file.read_text(encoding="utf-8")
    source_res = read_value(text, "source_file")
    source = GAME / source_res.removeprefix("res://")
    imported_res = read_value(text, "path")
    imported = GAME / imported_res.removeprefix("res://")
    with Image.open(source) as image:
        rgba = image.convert("RGBA")
        alpha = rgba.getchannel("A")
        histogram = alpha.histogram()
        pixels = rgba.width * rgba.height
        transparent = sum(histogram[:255])
        zero_alpha = histogram[0]
        width, height = rgba.size
    return {
        "group": group,
        "source_path": source_res,
        "import_metadata_path": relative_res(import_file),
        "uid": read_value(text, "uid"),
        "source_bytes": source.stat().st_size,
        "source_sha256": sha256(source),
        "width": width,
        "height": height,
        "has_alpha": transparent > 0,
        "non_opaque_pixel_fraction": round(transparent / pixels, 8),
        "fully_transparent_pixel_fraction": round(zero_alpha / pixels, 8),
        "import_mode": int(read_value(text, "compress/mode")),
        "lossy_quality": float(read_value(text, "compress/lossy_quality")),
        "high_quality": read_value(text, "compress/high_quality") == "true",
        "size_limit": int(read_value(text, "process/size_limit")),
        "imported_path": imported_res,
        "imported_bytes": imported.stat().st_size,
        "imported_sha256": sha256(imported),
    }


def git_head() -> str:
    return subprocess.check_output(
        ["git", "-C", str(REPO), "rev-parse", "HEAD"], text=True
    ).strip()


def before() -> None:
    assets: list[dict[str, Any]] = []
    counts: dict[str, int] = {}
    for group, directory in TARGETS.items():
        imports = sorted(directory.glob("*.png.import"))
        candidates = []
        for import_file in imports:
            text = import_file.read_text(encoding="utf-8")
            if int(read_value(text, "compress/mode")) == 0:
                candidates.append(import_file)
        counts[group] = len(candidates)
        for import_file in candidates:
            assets.append(
                {
                    "source_path": read_value(
                        import_file.read_text(encoding="utf-8"), "source_file"
                    ),
                    "group": group,
                    "before": inspect(group, import_file),
                    "after": None,
                }
            )
    document = {
        "phase": 2,
        "title": "Lossless enemy texture normalization",
        "baseline_source_revision": git_head(),
        "target_policy": {"compress_mode": 1, "lossy_quality": 0.7},
        "candidate_count": len(assets),
        "group_counts": counts,
        "assets": assets,
        "summary": {
            "before_imported_bytes": sum(
                asset["before"]["imported_bytes"] for asset in assets
            ),
            "after_imported_bytes": None,
            "imported_payload_reduction_bytes": None,
        },
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")


def after() -> None:
    document = json.loads(OUTPUT.read_text(encoding="utf-8"))
    for asset in document["assets"]:
        import_file = GAME / asset["before"]["import_metadata_path"].removeprefix(
            "res://"
        )
        current = inspect(asset["group"], import_file)
        prior = asset["before"]
        for key in ("source_bytes", "source_sha256", "width", "height", "uid"):
            if current[key] != prior[key]:
                raise AssertionError(
                    f"Source identity changed for {asset['source_path']}: {key}"
                )
        if current["import_mode"] != 1 or current["lossy_quality"] != 0.7:
            raise AssertionError(f"Target policy missing for {asset['source_path']}")
        asset["after"] = current
    before_bytes = sum(asset["before"]["imported_bytes"] for asset in document["assets"])
    after_bytes = sum(asset["after"]["imported_bytes"] for asset in document["assets"])
    document["candidate_source_revision"] = git_head()
    document["summary"] = {
        "before_imported_bytes": before_bytes,
        "after_imported_bytes": after_bytes,
        "imported_payload_reduction_bytes": before_bytes - after_bytes,
    }
    OUTPUT.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    if len(sys.argv) != 2 or sys.argv[1] not in {"before", "after"}:
        raise SystemExit("Usage: audit_phase2_texture_imports.py before|after")
    if sys.argv[1] == "before":
        before()
    else:
        after()
    print(OUTPUT)


if __name__ == "__main__":
    main()
