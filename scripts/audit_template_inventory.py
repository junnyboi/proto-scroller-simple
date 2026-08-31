#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import os
import re
import subprocess
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "docs" / "manifests"
OUT_DIR.mkdir(parents=True, exist_ok=True)

MEDIA_EXTS = {
    ".png", ".jpg", ".jpeg", ".webp", ".svg", ".mp4", ".webm",
    ".wav", ".ogg", ".mp3", ".qoa", ".ttf", ".otf", ".woff", ".woff2",
}
AUDIO_EXTS = {".wav", ".ogg", ".mp3", ".qoa"}
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".svg"}
VIDEO_EXTS = {".mp4", ".webm"}
FONT_EXTS = {".ttf", ".otf", ".woff", ".woff2"}
CODE_EXTS = {".gd", ".ts", ".tsx", ".js", ".mjs", ".py", ".sh"}
TEXT_EXTS = CODE_EXTS | {".md", ".json", ".cfg", ".tres", ".tscn", ".godot", ".yml", ".yaml", ".toml", ".txt"}


def tracked_files() -> list[tuple[Path, int]]:
    output = subprocess.check_output(
        ["git", "ls-tree", "-r", "-l", "HEAD"], cwd=ROOT, text=True
    )
    rows: list[tuple[Path, int]] = []
    for line in output.splitlines():
        meta, rel = line.split("\t", 1)
        size_token = meta.split()[-1]
        if size_token == "-":
            continue
        rows.append((Path(rel), int(size_token)))
    return rows


def category(path: Path) -> str:
    parts = path.parts
    suffix = path.suffix.lower()
    path_string = path.as_posix()
    if path_string.startswith("client/public/game/"):
        return "generated_web_bundle"
    if suffix in VIDEO_EXTS or "title-video" in parts:
        return "video"
    if suffix in AUDIO_EXTS:
        return "audio"
    if suffix in IMAGE_EXTS:
        if "boss" in path_string:
            return "boss_images"
        if "enemy" in path_string or "enemies" in parts:
            return "enemy_images"
        if "robot" in parts or "player" in parts:
            return "player_images"
        if "city" in parts or "parallax" in parts or "facade" in path_string:
            return "world_images"
        if "ui" in parts or "presentation" in parts:
            return "ui_images"
        return "other_images"
    if suffix in FONT_EXTS:
        return "fonts"
    if suffix == ".gd":
        if "/test/" in f"/{path_string}/" or path.name.startswith("test_"):
            return "godot_tests"
        return "godot_code"
    if suffix in {".tscn", ".tres"}:
        return "godot_resources"
    if suffix in {".ts", ".tsx", ".js", ".mjs"}:
        return "web_code"
    if suffix in {".py", ".sh"}:
        return "tooling_code"
    if suffix == ".md":
        return "documentation"
    return "other"


def text_content(path: Path) -> str:
    full = ROOT / path
    if not full.is_file() or path.suffix.lower() not in TEXT_EXTS:
        return ""
    try:
        return full.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return ""


rows = tracked_files()
category_bytes: Counter[str] = Counter()
category_files: Counter[str] = Counter()
extension_bytes: Counter[str] = Counter()
extension_files: Counter[str] = Counter()
media_rows: list[dict[str, object]] = []
code_lines: Counter[str] = Counter()
resource_references: Counter[str] = Counter()

for path, size in rows:
    suffix = path.suffix.lower() or "[none]"
    group = category(path)
    category_bytes[group] += size
    category_files[group] += 1
    extension_bytes[suffix] += size
    extension_files[suffix] += 1
    if path.suffix.lower() in MEDIA_EXTS:
        media_rows.append({"path": path.as_posix(), "bytes": size, "category": group, "extension": suffix})
    if path.suffix.lower() in CODE_EXTS:
        content = text_content(path)
        code_lines[suffix] += content.count("\n") + (1 if content else 0)
    content = text_content(path)
    if content:
        for ref in re.findall(r"res://[^\"'\s\)\],}]+", content):
            resource_references[ref.rstrip(",;:")] += 1

all_paths = {path.as_posix() for path, _ in rows}
media_with_refs = []
for item in media_rows:
    res_path = "res://" + str(item["path"]).removeprefix("game/")
    item["reference_count"] = resource_references.get(res_path, 0)
    media_with_refs.append(item)

branch_rows = []
branch_output = subprocess.check_output(
    ["git", "ls-remote", "--heads", "origin"], cwd=ROOT, text=True
)
for line in branch_output.splitlines():
    sha, ref = line.split()
    branch_rows.append({"branch": ref.removeprefix("refs/heads/"), "sha": sha})

scene_count = sum(1 for path, _ in rows if path.suffix.lower() == ".tscn")
resource_count = sum(1 for path, _ in rows if path.suffix.lower() == ".tres")
gdscript_count = sum(1 for path, _ in rows if path.suffix.lower() == ".gd")
test_script_count = sum(
    1
    for path, _ in rows
    if path.suffix.lower() == ".gd" and ("/test/" in f"/{path.as_posix()}/" or path.name.startswith("test_"))
)

summary = {
    "repository": "https://github.com/junnyboi/proto-scroller-simple",
    "head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
    "tracked_file_count": len(rows),
    "tracked_bytes": sum(size for _, size in rows),
    "branch_count": len(branch_rows),
    "scene_count": scene_count,
    "resource_count": resource_count,
    "gdscript_count": gdscript_count,
    "test_script_count": test_script_count,
    "media_file_count": len(media_rows),
    "media_bytes": sum(int(item["bytes"]) for item in media_rows),
    "category_bytes": dict(sorted(category_bytes.items())),
    "category_files": dict(sorted(category_files.items())),
    "extension_bytes": dict(sorted(extension_bytes.items())),
    "extension_files": dict(sorted(extension_files.items())),
    "code_lines": dict(sorted(code_lines.items())),
    "top_tracked_files": [
        {"path": path.as_posix(), "bytes": size, "category": category(path)}
        for path, size in sorted(rows, key=lambda item: item[1], reverse=True)[:100]
    ],
    "branches": branch_rows,
    "media_zero_literal_reference_candidates": [
        item for item in sorted(media_with_refs, key=lambda item: int(item["bytes"]), reverse=True)
        if int(item["reference_count"]) == 0
    ],
}

json_path = OUT_DIR / "game_template_current_inventory.json"
json_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

csv_path = OUT_DIR / "game_template_media_inventory.csv"
with csv_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(
        handle,
        fieldnames=["path", "bytes", "category", "extension", "reference_count"],
        lineterminator="\n",
    )
    writer.writeheader()
    writer.writerows(sorted(media_with_refs, key=lambda item: int(item["bytes"]), reverse=True))

print(json.dumps({
    "json": str(json_path),
    "csv": str(csv_path),
    "tracked_files": summary["tracked_file_count"],
    "tracked_bytes": summary["tracked_bytes"],
    "media_files": summary["media_file_count"],
    "media_bytes": summary["media_bytes"],
    "branches": summary["branch_count"],
    "gdscript": summary["gdscript_count"],
    "tests": summary["test_script_count"],
}, indent=2))
