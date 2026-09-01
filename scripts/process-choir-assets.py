from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from pathlib import Path
from typing import Final

from PIL import Image

ROOT: Final = Path("/home/ubuntu/workspace/proto-scroller")
GAME: Final = ROOT / "game"
SOURCES: Final = ROOT / "docs/story-concepts/production-sources"


@dataclass(frozen=True)
class SpriteJob:
    source: Path
    output: Path
    max_dimension: int
    padding: int = 20


SPRITE_JOBS: Final = (
    SpriteJob(SOURCES / "21-reclaimed-breacher-source.png", GAME / "art/city/enemies/archetypes/21-reclaimed-breacher.png", 384),
    SpriteJob(SOURCES / "22-graft-runner-source.png", GAME / "art/city/enemies/archetypes/22-graft-runner.png", 320),
    SpriteJob(SOURCES / "23-choir-siren-source.png", GAME / "art/city/enemies/archetypes/23-choir-siren.png", 384),
    SpriteJob(SOURCES / "24-ossuary-crawler-source.png", GAME / "art/city/enemies/archetypes/24-ossuary-crawler.png", 320),
    SpriteJob(SOURCES / "25-seraph-carrier-source.png", GAME / "art/city/enemies/archetypes/25-seraph-carrier.png", 512),
    SpriteJob(SOURCES / "26-pale-engine-source.png", GAME / "art/city/enemies/archetypes/26-pale-engine.png", 640),
    SpriteJob(SOURCES / "choir-prime-core-source.png", GAME / "art/finale/choir-prime-core.png", 640),
    SpriteJob(SOURCES / "choir-pylon-source.png", GAME / "art/finale/choir-pylon.png", 512),
    SpriteJob(SOURCES / "memory-glass-node-source.png", GAME / "art/narrative/memory-glass-node.png", 192, 12),
)


def remove_magenta(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, _ = pixels[x, y]
            # Generated chroma backgrounds contain slight texture. Magenta dominance is
            # more robust than Euclidean distance and preserves cyan/amber subject light.
            score = float(min(red, blue) - green)
            if score >= 140.0:
                alpha = 0
            elif score <= 30.0:
                alpha = 255
            else:
                alpha = round(255.0 * (140.0 - score) / 110.0)
            if alpha <= 0:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            if alpha < 255:
                ratio = alpha / 255.0
                clean_red = int(max(0.0, min(255.0, (red - (1.0 - ratio) * 255.0) / ratio)))
                clean_green = int(max(0.0, min(255.0, green / ratio)))
                clean_blue = int(max(0.0, min(255.0, (blue - (1.0 - ratio) * 255.0) / ratio)))
                pixels[x, y] = (clean_red, clean_green, clean_blue, alpha)
            else:
                pixels[x, y] = (red, green, blue, 255)
    return rgba


def trim_and_scale(image: Image.Image, max_dimension: int, padding: int) -> Image.Image:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError("No nontransparent sprite pixels found")
    cropped = image.crop(bbox)
    canvas = Image.new("RGBA", (cropped.width + padding * 2, cropped.height + padding * 2), (0, 0, 0, 0))
    canvas.alpha_composite(cropped, (padding, padding))
    scale = min(1.0, max_dimension / max(canvas.width, canvas.height))
    if scale < 1.0:
        canvas = canvas.resize(
            (max(1, round(canvas.width * scale)), max(1, round(canvas.height * scale))),
            Image.Resampling.LANCZOS,
        )
    return canvas


def keep_primary_component(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    width, height = image.size
    values = alpha.load()
    visited = bytearray(width * height)
    components: list[list[tuple[int, int]]] = []

    for y in range(height):
        for x in range(width):
            offset = y * width + x
            if visited[offset] or values[x, y] <= 16:
                visited[offset] = 1
                continue
            queue: deque[tuple[int, int]] = deque([(x, y)])
            visited[offset] = 1
            component: list[tuple[int, int]] = []
            while queue:
                current_x, current_y = queue.popleft()
                component.append((current_x, current_y))
                for next_x, next_y in (
                    (current_x - 1, current_y),
                    (current_x + 1, current_y),
                    (current_x, current_y - 1),
                    (current_x, current_y + 1),
                ):
                    if not (0 <= next_x < width and 0 <= next_y < height):
                        continue
                    next_offset = next_y * width + next_x
                    if visited[next_offset]:
                        continue
                    visited[next_offset] = 1
                    if values[next_x, next_y] > 16:
                        queue.append((next_x, next_y))
            components.append(component)

    if not components:
        raise RuntimeError("No connected sprite component found")
    primary = max(components, key=len)
    keep = bytearray(width * height)
    for x, y in primary:
        keep[y * width + x] = 1
    pixels = image.load()
    for y in range(height):
        for x in range(width):
            if not keep[y * width + x]:
                red, green, blue, _ = pixels[x, y]
                pixels[x, y] = (red, green, blue, 0)
    return image


def process_sprite(job: SpriteJob) -> None:
    if not job.source.exists():
        raise FileNotFoundError(job.source)
    image = Image.open(job.source)
    output = keep_primary_component(
        trim_and_scale(remove_magenta(image), job.max_dimension, job.padding)
    )
    job.output.parent.mkdir(parents=True, exist_ok=True)
    output.save(job.output, format="PNG", optimize=True)
    if output.getchannel("A").getextrema()[0] != 0:
        raise RuntimeError(f"Sprite has no transparent background: {job.output}")


def main() -> None:
    for job in SPRITE_JOBS:
        process_sprite(job)
        print(f"processed {job.output.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
