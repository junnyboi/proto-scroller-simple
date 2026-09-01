#!/usr/bin/env python3
"""Create a revision-stable inventory for the lightweight template migration."""

from __future__ import annotations

import argparse
import csv
import json
import re
import subprocess
from collections import Counter
from pathlib import Path
from typing import BinaryIO


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_JSON = ROOT / "docs" / "manifests" / "game_template_baseline_inventory.json"
DEFAULT_CSV = ROOT / "docs" / "manifests" / "game_template_baseline_media.csv"

MEDIA_EXTS = {
    ".png", ".jpg", ".jpeg", ".webp", ".svg", ".mp4", ".webm",
    ".wav", ".ogg", ".mp3", ".qoa", ".ttf", ".otf", ".woff", ".woff2",
}
AUDIO_EXTS = {".wav", ".ogg", ".mp3", ".qoa"}
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".svg"}
VIDEO_EXTS = {".mp4", ".webm"}
FONT_EXTS = {".ttf", ".otf", ".woff", ".woff2"}
CODE_EXTS = {".gd", ".ts", ".tsx", ".js", ".mjs", ".py", ".sh"}
TEXT_EXTS = CODE_EXTS | {
    ".md", ".json", ".cfg", ".tres", ".tscn", ".godot", ".yml", ".yaml",
    ".toml", ".txt",
}


class GitBlobReader:
    """Read Git objects through one persistent `cat-file --batch` process."""

    def __init__(self) -> None:
        self._process = subprocess.Popen(
            ["git", "cat-file", "--batch"],
            cwd=ROOT,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
        )

    def read(self, object_id: str) -> bytes:
        input_stream = self._process.stdin
        output_stream = self._process.stdout
        if input_stream is None or output_stream is None:
            raise RuntimeError("git cat-file streams are unavailable")
        input_stream.write(f"{object_id}\n".encode("ascii"))
        input_stream.flush()
        header = output_stream.readline().decode("ascii").strip().split()
        if len(header) != 3 or header[1] != "blob":
            raise RuntimeError(f"unexpected git cat-file response for {object_id}: {header}")
        size = int(header[2])
        data = _read_exact(output_stream, size)
        if output_stream.read(1) != b"\n":
            raise RuntimeError(f"missing git cat-file record terminator for {object_id}")
        return data

    def close(self) -> None:
        if self._process.stdin is not None:
            self._process.stdin.close()
        return_code = self._process.wait(timeout=10)
        if return_code != 0:
            raise RuntimeError(f"git cat-file failed with exit code {return_code}")


def _read_exact(stream: BinaryIO, size: int) -> bytes:
    chunks: list[bytes] = []
    remaining = size
    while remaining > 0:
        chunk = stream.read(remaining)
        if not chunk:
            raise RuntimeError("unexpected EOF from git cat-file")
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def run_git(*arguments: str) -> str:
    return subprocess.check_output(["git", *arguments], cwd=ROOT, text=True).strip()


def resolve_revision(revision: str) -> str:
    return run_git("rev-parse", "--verify", f"{revision}^{{commit}}")


def tracked_files(revision: str) -> list[tuple[Path, int, str]]:
    output = subprocess.check_output(
        ["git", "ls-tree", "-r", "-l", "-z", revision], cwd=ROOT
    )
    rows: list[tuple[Path, int, str]] = []
    for record in output.split(b"\0"):
        if not record:
            continue
        metadata, raw_path = record.split(b"\t", 1)
        mode, object_type, object_id, raw_size = metadata.decode("ascii").split()
        del mode
        if object_type != "blob" or raw_size == "-":
            continue
        rows.append(
            (
                Path(raw_path.decode("utf-8", errors="surrogateescape")),
                int(raw_size),
                object_id,
            )
        )
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


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--revision",
        default="HEAD",
        help="Commit or tag to inventory. The revision is resolved before reading any blobs.",
    )
    parser.add_argument("--json-output", type=Path, default=DEFAULT_JSON)
    parser.add_argument("--csv-output", type=Path, default=DEFAULT_CSV)
    parser.add_argument(
        "--remote-branches-output",
        type=Path,
        help="Optional mutable snapshot from `git ls-remote --heads origin`.",
    )
    return parser.parse_args()


def absolute_output(path: Path) -> Path:
    return path if path.is_absolute() else ROOT / path


def remote_branch_snapshot(revision: str) -> dict[str, object]:
    branch_rows: list[dict[str, str]] = []
    output = run_git("ls-remote", "--heads", "origin")
    for line in output.splitlines():
        sha, ref = line.split()
        branch_rows.append({"branch": ref.removeprefix("refs/heads/"), "sha": sha})
    branch_rows.sort(key=lambda item: item["branch"])
    return {
        "schema_version": 1,
        "source": "git ls-remote --heads origin",
        "inventory_revision": revision,
        "branch_count": len(branch_rows),
        "branches": branch_rows,
    }


def main() -> int:
    arguments = parse_arguments()
    revision = resolve_revision(arguments.revision)
    rows = tracked_files(revision)
    category_bytes: Counter[str] = Counter()
    category_files: Counter[str] = Counter()
    extension_bytes: Counter[str] = Counter()
    extension_files: Counter[str] = Counter()
    code_lines: Counter[str] = Counter()
    resource_references: Counter[str] = Counter()
    media_rows: list[dict[str, object]] = []

    blob_reader = GitBlobReader()
    try:
        for path, size, object_id in rows:
            suffix = path.suffix.lower() or "[none]"
            group = category(path)
            category_bytes[group] += size
            category_files[group] += 1
            extension_bytes[suffix] += size
            extension_files[suffix] += 1
            if path.suffix.lower() in MEDIA_EXTS:
                media_rows.append(
                    {
                        "path": path.as_posix(),
                        "bytes": size,
                        "category": group,
                        "extension": suffix,
                    }
                )
            if path.suffix.lower() not in TEXT_EXTS:
                continue
            content = blob_reader.read(object_id).decode("utf-8", errors="ignore")
            if path.suffix.lower() in CODE_EXTS:
                code_lines[suffix] += content.count("\n") + (1 if content else 0)
            for reference in re.findall(r"res://[^\"'\s\)\],}]+", content):
                resource_references[reference.rstrip(",;:")] += 1
    finally:
        blob_reader.close()

    for item in media_rows:
        resource_path = "res://" + str(item["path"]).removeprefix("game/")
        item["reference_count"] = resource_references.get(resource_path, 0)

    summary = {
        "schema_version": 2,
        "repository": "https://github.com/junnyboi/proto-scroller-simple",
        "revision": revision,
        "tracked_file_count": len(rows),
        "tracked_bytes": sum(size for _, size, _ in rows),
        "scene_count": sum(1 for path, _, _ in rows if path.suffix.lower() == ".tscn"),
        "resource_count": sum(1 for path, _, _ in rows if path.suffix.lower() == ".tres"),
        "gdscript_count": sum(1 for path, _, _ in rows if path.suffix.lower() == ".gd"),
        "test_script_count": sum(
            1
            for path, _, _ in rows
            if path.suffix.lower() == ".gd"
            and ("/test/" in f"/{path.as_posix()}/" or path.name.startswith("test_"))
        ),
        "media_file_count": len(media_rows),
        "media_bytes": sum(int(item["bytes"]) for item in media_rows),
        "category_bytes": dict(sorted(category_bytes.items())),
        "category_files": dict(sorted(category_files.items())),
        "extension_bytes": dict(sorted(extension_bytes.items())),
        "extension_files": dict(sorted(extension_files.items())),
        "code_lines": dict(sorted(code_lines.items())),
        "top_tracked_files": [
            {"path": path.as_posix(), "bytes": size, "category": category(path)}
            for path, size, _ in sorted(rows, key=lambda item: item[1], reverse=True)[:100]
        ],
        "media_zero_literal_reference_candidates": [
            item
            for item in sorted(media_rows, key=lambda item: int(item["bytes"]), reverse=True)
            if int(item["reference_count"]) == 0
        ],
    }

    json_path = absolute_output(arguments.json_output)
    csv_path = absolute_output(arguments.csv_output)
    json_path.parent.mkdir(parents=True, exist_ok=True)
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["path", "bytes", "category", "extension", "reference_count"],
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(sorted(media_rows, key=lambda item: int(item["bytes"]), reverse=True))

    if arguments.remote_branches_output is not None:
        remote_path = absolute_output(arguments.remote_branches_output)
        remote_path.parent.mkdir(parents=True, exist_ok=True)
        remote_path.write_text(
            json.dumps(remote_branch_snapshot(revision), indent=2) + "\n",
            encoding="utf-8",
        )

    print(
        json.dumps(
            {
                "revision": revision,
                "json": str(json_path),
                "csv": str(csv_path),
                "tracked_files": summary["tracked_file_count"],
                "tracked_bytes": summary["tracked_bytes"],
                "media_files": summary["media_file_count"],
                "media_bytes": summary["media_bytes"],
                "gdscript": summary["gdscript_count"],
                "tests": summary["test_script_count"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
