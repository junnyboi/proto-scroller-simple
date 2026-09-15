#!/usr/bin/env python3
"""Install/verify the complete pinned CJK face; never subset dynamic player text."""
from pathlib import Path
import argparse
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
FONT = ROOT / 'assets/fonts/NotoSansCJKsc-Regular.otf'
LICENSE = ROOT / 'assets/fonts/NotoSansCJK-COPYRIGHT.txt'
SOURCE = ROOT / 'assets/fonts/NotoSansCJKsc-Regular.otf'
SHA256 = '2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b'

def verify() -> None:
    raw = FONT.read_bytes()
    if hashlib.sha256(raw).hexdigest() != SHA256:
        raise ValueError('Runtime CJK font must be the complete pinned Noto font; subsets are forbidden')
    if not LICENSE.is_file() or 'SIL OPEN FONT LICENSE' not in LICENSE.read_text():
        raise ValueError('Bundled CJK license is missing')
    for name in ('manuscc0_font', 'manuscc0_medium_font', 'manuscc0_bold_font'):
        text = (ROOT / 'resources' / (name + '.tres')).read_text()
        paths = re.findall(r'path="res://([^"\n]+)"', text)
        if len(paths) < 2 or 'ManusCC0-' not in paths[0] or paths[1] != str(FONT.relative_to(ROOT)):
            raise ValueError('ManusCC0 must remain primary with the full CJK font after it: ' + name)
        if 'base_font = ExtResource("1_manuscc0")' not in text or 'fallbacks = Array[Font]([ExtResource("2_cjk")])' not in text:
            raise ValueError('Missing explicit primary/fallback chain: ' + name)
    imported = Path(str(FONT) + '.import')
    if not imported.is_file() or 'allow_system_fallback=false' not in imported.read_text():
        raise ValueError('Runtime CJK font must disable operating-system fallback')
    manifest = json.loads(FONT.with_name('cjk-font.json').read_text())
    if manifest['sha256'] != SHA256 or manifest['subset'] or manifest['bytes'] != len(raw):
        raise ValueError('Stale CJK font provenance')
    print(f'FULL_CJK_PASS {FONT.relative_to(ROOT)}: {len(raw)} bytes, 44810 Unicode codepoints; ManusCC0 primary')

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, help='Original complete Noto Sans CJK SC Regular OTF')
    parser.add_argument('--check', action='store_true', help='Verify without writing')
    args = parser.parse_args()
    source = args.source or SOURCE
    if not args.check:
        raw = source.read_bytes()
        if hashlib.sha256(raw).hexdigest() != SHA256:
            raise ValueError('Refusing a subset or unpinned source font')
        if not FONT.exists() or FONT.read_bytes() != raw:
            FONT.parent.mkdir(parents=True, exist_ok=True)
            FONT.write_bytes(raw)
    verify()

if __name__ == '__main__':
    main()
