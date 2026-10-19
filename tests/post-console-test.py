#!/usr/bin/env python3
"""Exercise evaluated commands in a test-owned HOME; native artifact gate is separate."""
import json
import os
from pathlib import Path
import shlex
import signal
import subprocess
import tempfile

unit = json.loads(Path(os.environ['KOSMOS_POST_UNIT']).read_text())
service = unit['Service']
with tempfile.TemporaryDirectory(prefix='post-console-test-') as directory:
    home = Path(directory)
    release = home / 'release'
    config = home / 'private/post.toml'
    env = {'HOME': str(home), 'PATH': service['Environment'][0].removeprefix('PATH=')}
    condition = shlex.split(service['ExecCondition'])
    condition[-2:] = [str(release), str(config)]

    def run(command, cwd=None):
        return subprocess.run(command, cwd=cwd, env=env, capture_output=True, text=True, timeout=20)

    missing = run(condition)
    assert missing.returncode == 1 and 'uninitialized' in missing.stderr
    assert list(home.iterdir()) == [], 'condition must not create state'
    for entry in ['dist/web', 'node_modules/smol-toml']:
        (release / entry).mkdir(parents=True)
    for entry in ['artifact-manifest.json', 'revision.json', 'node_modules/smol-toml/package.json']:
        (release / entry).write_text('{}')
    # Command fixture only: native gate below uses the archive's actual TOML parser/CLI.
    (release / 'node_modules/smol-toml/index.js').write_text('exports.parse = JSON.parse;')
    (release / 'dist/web/index.html').write_text('fixture')
    (release / 'dist/cli.cjs').write_text("""
const fs = require('node:fs');
const [command, flag, file] = process.argv.slice(2);
if (flag !== '--config') process.exit(2);
const cfg = JSON.parse(fs.readFileSync(file));
if (!cfg.valid) process.exit(1);
if (command === 'config-check') process.exit(0);
if (command !== 'serve') process.exit(2);
process.on('SIGTERM', ()=>process.exit(0));
console.log(JSON.stringify({node:process.version, exec:process.execPath,
  ua:process.env.npm_config_user_agent, cwd:process.cwd(), home:process.env.HOME}));
setInterval(()=>{}, 1000);
""")
    assert run(condition).returncode == 1, 'missing config must skip'
    config.parent.mkdir(mode=0o700)
    config.write_text(json.dumps({'valid': True, 'settings': {'admin_file': 'admin.json'}}))
    config.chmod(0o600)
    assert run(condition).returncode == 1, 'missing administrator must skip'
    (config.parent / 'admin.json').write_text('fixture-private-record')
    assert run(condition).returncode == 0
    asset = release / 'dist/web/index.html'
    asset.rename(asset.with_suffix('.saved'))
    assert run(condition).returncode == 1, 'incomplete release must skip'
    asset.with_suffix('.saved').rename(asset)
    watched = [p for p in home.rglob('*') if p.is_file()]
    before = [(p, p.read_bytes(), p.stat().st_mtime_ns) for p in watched]

    def command(key):
        args = shlex.split(service[key])
        args[1] = str(release / 'dist/cli.cjs')
        args[-1] = str(config)
        return args

    for _ in range(2):
        assert run(condition).returncode == 0
        check = run(command('ExecStartPre'), release)
        assert check.returncode == 0, check.stderr
        child = subprocess.Popen(command('ExecStart'), cwd=release, env=env,
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                 text=True, start_new_session=True)
        try:
            observed = json.loads(child.stdout.readline())
            assert observed['node'].startswith('v24.')
            assert observed['exec'].startswith('/nix/store/')
            assert 'ua' not in observed
            assert observed['cwd'] == str(release) and observed['home'] == str(home)
            os.killpg(child.pid, signal.SIGTERM)
            child.communicate(timeout=service['TimeoutStopSec'])
            assert child.returncode == 0
        finally:
            if child.poll() is None:
                os.killpg(child.pid, signal.SIGKILL)
                child.communicate()
        assert [(p, p.read_bytes(), p.stat().st_mtime_ns) for p in watched] == before
    config.write_text('{"valid":false}')
    assert run(command('ExecStartPre'), release).returncode != 0
print('evaluated commands PASS: missing/incomplete/admin skip, Node24 direct CLI, preflight, TERM and unchanged inputs')
