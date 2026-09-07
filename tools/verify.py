"""Portable Act 1 release checks; browser acceptance is performed by the user."""
from pathlib import Path
import os, re, shutil, subprocess, sys, tempfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/verification'
OUT.mkdir(parents=True, exist_ok=True)
(ROOT / 'artifacts/.gdignore').touch()
GODOT = os.environ.get('GODOT') or shutil.which('godot') or shutil.which('godot4')
if not GODOT and Path('/Applications/Godot.app/Contents/MacOS/Godot').exists():
    GODOT = '/Applications/Godot.app/Contents/MacOS/Godot'
if not GODOT:
    raise SystemExit('Godot is required')
if sys.argv[1:] not in ([], ['--full']):
    raise SystemExit('Usage: ./verify.sh [--full]')


def run(name, command, *, cwd=ROOT, timeout=600, engine=False):
    print('[ACT1] ' + name, flush=True)
    result = subprocess.run(command, cwd=cwd, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=timeout,
                            env={**os.environ, 'PROTO_SCROLLER_LOCALE': 'en'})
    (OUT / (name + '.log')).write_text(result.stdout)
    if result.returncode:
        raise SystemExit(f'{name} failed ({result.returncode}); see {OUT / (name + ".log")}')
    if engine:
        # Godot 4.7.2's dummy renderer reports cached shader RIDs on shutdown.
        # Keep that diagnostic in the log; do not suppress actual script/resource errors.
        cleaned = re.sub(r"^ERROR: \d+ RID allocations of type 'N13RendererDummy15MaterialStorage11DummyShaderE' were leaked at exit\.$", '', result.stdout, flags=re.M)
        if re.search(r'^SCRIPT ERROR:|^ERROR:|Parse Error:|\[ACT1-FAIL\]', cleaned, re.M):
            raise SystemExit(f'{name} logged an error; see {OUT / (name + ".log")}')
    return result.stdout


run('source', ['node', 'tools/verify-source.mjs'])
run('loader', ['node', '--check', 'web/loader.js'])
run('shell', ['node', 'web/build-shell.mjs'])
run('loader-contracts', ['node', 'tools/test-loader.mjs'])
run('import', [GODOT, '--headless', '--editor', '--path', '.', '--import'], engine=True)
gut = run('gut', [GODOT, '--headless', '--path', '.', '--script', 'addons/gut/gut_cmdln.gd',
                   '-gdir=res://test', '-gexit'], engine=True)
plain = re.sub(r'\x1b\[[0-9;]*m', '', gut)
if '[Failed]' in plain or not re.search(r'Passing Tests\s+[1-9]\d*', plain):
    raise SystemExit('GUT did not pass a nonempty suite')
run('scenario', [GODOT, '--headless', '--path', '.', '--script', 'res://selftest/act1_scenario.gd'], engine=True)
if '--full' in sys.argv:
    web = OUT / 'web'
    if web.exists(): shutil.rmtree(web)
    web.mkdir()
    run('export', [GODOT, '--headless', '--path', '.', '--export-release', 'Web', str(web / 'index.html')], engine=True)
    for name in ['index.html', 'index.js', 'index.wasm', 'index.pck']:
        if not (web / name).is_file() or (web / name).stat().st_size == 0:
            raise SystemExit('Missing export: ' + name)
    if (web / 'index.pck').stat().st_size > 16 * 1024 * 1024:
        raise SystemExit('PCK exceeded the original 16 MiB budget')
    html = (web / 'index.html').read_text()
    if '$GODOT_' in html or '__TITLE_ASSETS__' in html or '/manus-storage/game_' in html:
        raise SystemExit('Unresolved or original-deployment URL in shell')
    with tempfile.TemporaryDirectory(prefix='scroller-pack-') as empty:
        run('pack-boot', [GODOT, '--headless', '--path', empty, '--main-pack', str(web / 'index.pck'), '--max-fps', '60', '--quit-after', '180'], cwd=empty, engine=True)
    print('PCK bytes:', (web / 'index.pck').stat().st_size)
print('[ACT1-PASS] ' + ('full' if '--full' in sys.argv else 'standard'))
