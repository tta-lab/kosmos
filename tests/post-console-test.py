#!/usr/bin/env python3
"""Execute evaluated service commands with real Nix tools and a disposable HOME."""
import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile

unit = json.loads(Path(os.environ['KOSMOS_POST_UNIT']).read_text())
service = unit['Service']
with tempfile.TemporaryDirectory(prefix='post-console-test-') as directory:
    home = Path(directory)
    app = home / '.local/share/lamplit-post/app'
    env = {'HOME': str(home), 'PATH': service['Environment'][0].removeprefix('PATH=')}
    condition = shlex.split(service['ExecCondition'])
    condition[-1] = str(app)

    def run(command, cwd=None):
        return subprocess.run(command, cwd=cwd, env=env, capture_output=True, text=True, timeout=20)

    missing = run(condition)
    assert missing.returncode == 1 and 'uninitialized' in missing.stderr
    assert not app.exists(), 'condition must not create state'
    app.mkdir(parents=True, mode=0o700)
    for entry in ['node_modules', 'patches', 'dist', 'post/dist']:
        (app / entry).mkdir(parents=True, exist_ok=True)
    manifest = {
        'scripts': {'start': 'node dist/cli.cjs', 'config-check': 'node check.cjs'},
        'engines': {'pnpm': '12.x'},
    }
    (app / 'package.json').write_text(json.dumps(manifest))
    (app / 'pnpm-lock.yaml').write_text('lockfileVersion: "9.0"\n')
    (app / 'pnpm-workspace.yaml').write_text(
        'verifyDepsBeforeRun: false\nfrozenLockfile: false\n')
    (app / 'koishi.yml').write_text('# operator-owned config\nplugins: {}\n')
    (app / 'post/package.json').write_text('{"name":"koishi-plugin-post"}\n')
    (app / 'post/dist/post-plugin.cjs').write_text('// app-owned plugin\n')
    (app / 'node_modules/operator-plugin').write_text('retained\n')
    (app / 'check.cjs').write_text("""
const fs = require('node:fs');
if (!fs.readFileSync('koishi.yml', 'utf8').includes('plugins:')) process.exit(1);
""")
    (app / 'dist/cli.cjs').write_text("""
const fs = require('node:fs');
const cp = require('node:child_process');
fs.writeFileSync('observed.json', JSON.stringify({
  cwd: process.cwd(), home: process.env.HOME,
  node: process.version, exec: process.execPath,
  ua: process.env.npm_config_user_agent,
  pnpm: cp.execFileSync('pnpm', ['--version'], {encoding:'utf8'}).trim(),
}));
""")
    assert run(condition).returncode == 0
    # An incomplete seed is skipped without modifying operator input.
    plugin = app / 'post/dist/post-plugin.cjs'
    plugin.rename(plugin.with_suffix('.saved'))
    assert run(condition).returncode == 1
    plugin.with_suffix('.saved').rename(plugin)
    watched = [
        app / name for name in ['package.json', 'koishi.yml', 'pnpm-lock.yaml',
                               'pnpm-workspace.yaml', 'node_modules/operator-plugin']
    ]

    def snapshot():
        return [(p.read_bytes(), p.stat().st_ino, p.stat().st_mtime_ns) for p in watched]

    before = snapshot()
    assert service['WorkingDirectory'].removeprefix('-').endswith('/lamplit-post/app')
    for _ in range(2):
        assert run(condition).returncode == 0
        check = run(shlex.split(service['ExecStartPre']), app)
        assert check.returncode == 0, check.stderr
        started = run(shlex.split(service['ExecStart']), app)
        assert started.returncode == 0, started.stderr
        observed = json.loads((app / 'observed.json').read_text())
        assert observed['cwd'] == str(app) and observed['home'] == str(home)
        assert observed['node'].startswith('v24.')
        assert observed['exec'].startswith('/nix/store/')
        assert observed['ua'].startswith('pnpm/12.')
        assert observed['pnpm'] == '12.3.4'
        assert snapshot() == before, 'startup must preserve mutable app inputs'
    (app / 'koishi.yml').write_text('invalid fixture\n')
    check = run(shlex.split(service['ExecStartPre']), app)
    assert check.returncode != 0, 'invalid config must fail preflight'
print('managed commands: missing/incomplete skip, real Node24/pnpm12 UA, preflight and persistent inputs PASS')
