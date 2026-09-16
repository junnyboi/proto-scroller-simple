#!/usr/bin/env python3
"""Verify or atomically restore the approved CC0 Simplified Chinese game font."""
from pathlib import Path
import argparse,hashlib,json,os,re,tempfile
ROOT=Path(__file__).resolve().parents[1]
FONT=ROOT/'assets/fonts/ManusCC0SansCJKSC-Regular.woff2'
SHA256='0a4981b817d7fb556dd8cd80f278483f1849017a312ca965e027d8e0e066968c'
REPERTOIRE_SHA256='43a32ca61e0c76d6e13925e0824eda3277fff23f7a712cdf7ee51ce5c1c9b4e9'
MAX_BYTES=1000000

def verify():
    data=FONT.read_bytes()
    if len(data)>MAX_BYTES or hashlib.sha256(data).hexdigest()!=SHA256:
        raise ValueError('Runtime Chinese font must match ManusCC0 Sans CJK SC and stay at most 1,000,000 bytes')
    points=FONT.with_name('cjk-codepoints.json')
    if hashlib.sha256(points.read_bytes()).hexdigest()!=REPERTOIRE_SHA256 or len(json.loads(points.read_text()))!=6547:
        raise ValueError('Retain the complete approved 6,547-codepoint repertoire')
    for role in ('manuscc0_font','manuscc0_medium_font','manuscc0_bold_font'):
        text=(ROOT/'resources'/(role+'.tres')).read_text()
        paths=re.findall(r'path="res://([^"\n]+)"',text)
        if len(paths)<2 or 'ManusCC0-' not in paths[0] or paths[1]!=str(FONT.relative_to(ROOT)):
            raise ValueError('ManusCC0 must remain primary with the approved CC0 Chinese fallback')
        if 'base_font = ExtResource("1_manuscc0")' not in text or 'fallbacks = Array[Font]([ExtResource("2_cjk")])' not in text:
            raise ValueError('Missing explicit primary/fallback chain')
    if 'allow_system_fallback=false' not in Path(str(FONT)+'.import').read_text():
        raise ValueError('System fallback must be disabled')
    metadata=json.loads(FONT.with_name('cjk-font.json').read_text())
    if metadata['sha256']!=SHA256 or metadata['bytes']!=len(data) or metadata['license']!='CC0-1.0':
        raise ValueError('Stale CC0 font provenance')
    print(f'CC0_CJK_PASS {FONT.relative_to(ROOT)}: {len(data)} bytes, 6547 codepoints; ManusCC0 primary')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,help='Approved ManusCC0SansCJKSC-Regular.woff2 to restore')
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    if not args.check and args.source:
        data=args.source.read_bytes()
        if len(data)>MAX_BYTES or hashlib.sha256(data).hexdigest()!=SHA256:
            raise ValueError('Refusing oversized or unapproved font before replacing existing bytes')
        with tempfile.NamedTemporaryFile(dir=FONT.parent,delete=False) as stream:
            pending=Path(stream.name);stream.write(data)
        try:pending.chmod(0o644);os.replace(pending,FONT)
        finally:
            if pending.exists():pending.unlink()
    verify()
if __name__=='__main__':main()
