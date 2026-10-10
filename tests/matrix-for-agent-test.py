"""Owned runtime fixtures. No live files, endpoints, secrets or units."""
import http.server
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time

helper, node = sys.argv[1:3]
tokens = {'shio-"\\$token': '@shio:test', 'serein-token': '@serein:test'}
requests = []
class Homeserver(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_): pass
    def do_GET(self):
        token = self.headers.get('Authorization', '').removeprefix('Bearer ')
        requests.append((self.path, token))
        if token == 'stall':
            self.send_response(200); self.end_headers(); time.sleep(11); return
        data = {'user_id': tokens.get(token)}
        body = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(200 if token in tokens else 401)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        if token == 'unicode-owned':
            split = body.index('雪'.encode()) + 1
            self.wfile.write(body[:split]); self.wfile.flush(); time.sleep(.02)
            self.wfile.write(body[split:])
        else: self.wfile.write(body)
home = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Homeserver)
thread = threading.Thread(target=home.serve_forever, daemon=True); thread.start()
url = f'http://127.0.0.1:{home.server_port}'
base = {'PATH': os.environ['PATH']}
with tempfile.TemporaryDirectory(prefix='kosmos-unified-matrix-') as tmp:
    root = Path(tmp); root.chmod(0o700)
    artifact = root / 'cli.js'; artifact.write_text('owned fake artifact')
    exe = root / 'fake-node'
    exe.write_text(f'#!{sys.executable}\nimport json,os,sys\nprint(json.dumps(dict(argv=sys.argv[1:],env=dict(os.environ))))\n')
    exe.chmod(0o700)
    def run(action, *args, env=None, ok=True):
        p = subprocess.run([node, helper, action, tmp, *map(str, args)], env=env or base,
                           capture_output=True, text=True, timeout=13)
        if ok: assert p.returncode == 0, p.stderr
        else:
            assert p.returncode != 0 and not p.stdout
            assert p.stderr == 'Matrix runtime preparation failed (inputs, private paths or artifact unavailable)\n'
            assert not (root / 'webhooks.json').exists()
        return p
    def prepare(kind, **overrides):
        env = {**base, 'MATRIX_HOMESERVER_URL': url + '/',
               'MATRIX_ACCESS_TOKEN': list(tokens)[kind == 'serein'],
               'MATRIX_WEBHOOK_URL': 'http://localhost:1111/receiver',
               'MATRIX_WEBHOOK_BEARER_TOKEN': 'receiver-"\\$token', **overrides}
        return run('prepare', kind, env=env)
    run('init', artifact)
    prepare('shio'); prepare('serein')
    leaked = {**base, 'MATRIX_ACCESS_TOKEN': 'must-remove', 'MATRIX_WEBHOOK_URL': 'must-remove',
              'MATRIX_WEBHOOK_BEARER_TOKEN': 'must-remove', 'MATRIX_OTHER': 'must-remove'}
    observed = json.loads(run('run', exe, artifact, 'shio', 'serein', env=leaked).stdout)
    config = json.loads((root / 'webhooks.json').read_text())
    assert observed['argv'] == [str(artifact)]
    assert {k:v for k,v in observed['env'].items() if k.startswith('MATRIX_')} == {
        'MATRIX_HOMESERVER_URL': url, 'MATRIX_MCP_LISTEN': '127.0.0.1:8768',
        'MATRIX_WEBHOOK_CONFIG': str(root / 'webhooks.json')}
    assert config == [
        {'user_id': '@shio:test', 'access_token': list(tokens)[0], 'url': 'http://127.0.0.1:3084/api/matrix/events'},
        {'user_id': '@serein:test', 'access_token': list(tokens)[1], 'url': 'http://localhost:1111/receiver', 'bearer_token': 'receiver-"\\$token'}]
    assert (root / 'webhooks.json').stat().st_mode & 0o777 == 0o600
    assert not (root / 'shio.json').exists() and not (root / 'serein.json').exists()
    for kind in ['shio', 'serein']:
        run('init', artifact)
        env = {**base, 'MATRIX_HOMESERVER_URL': url, 'MATRIX_ACCESS_TOKEN': list(tokens)[kind == 'serein']}
        run('prepare', kind, env=env)
        run('run', exe, artifact, kind)
        assert len(json.loads((root / 'webhooks.json').read_text())) == (kind == 'shio')
    # Every init clears stale configuration even when the artifact is missing.
    run('init', root / 'missing', ok=False)
    for overrides in [{'MATRIX_ACCESS_TOKEN': ''}, {'MATRIX_ACCESS_TOKEN': 'bad token'},
                      {'MATRIX_ACCESS_TOKEN': 'invalid'}, {'MATRIX_HOMESERVER_URL': 'file:///tmp'},
                      {'MATRIX_WEBHOOK_URL': 'http://remote.invalid/x'},
                      {'MATRIX_WEBHOOK_BEARER_TOKEN': 'bad bearer'}]:
        run('init', artifact)
        env = {**base, 'MATRIX_HOMESERVER_URL': url, 'MATRIX_ACCESS_TOKEN': list(tokens)[1], **overrides}
        run('prepare', 'serein', env=env, ok=False)
    tokens['malformed-id-owned'] = 'not-a-matrix-id'
    run('prepare', 'serein', env={**base, 'MATRIX_HOMESERVER_URL': url, 'MATRIX_ACCESS_TOKEN': 'malformed-id-owned'}, ok=False)
    del tokens['malformed-id-owned']
    tokens['unicode-owned'] = '@雪:test'
    run('prepare', 'serein', env={**base, 'MATRIX_HOMESERVER_URL': url, 'MATRIX_ACCESS_TOKEN': 'unicode-owned'})
    assert json.loads((root / 'serein.json').read_text())['entry']['user_id'] == '@雪:test'
    del tokens['unicode-owned']
    run('prepare', 'shio', env=base, ok=False)
    run('prepare', '../../outside', env=base, ok=False)
    for change in ['home', 'user', 'token']:
        run('init', artifact); prepare('shio'); prepare('serein')
        file = root / 'serein.json'; data = json.loads(file.read_text())
        if change == 'home': data['home'] += '/other'
        else: data['entry']['user_id' if change == 'user' else 'access_token'] = config[0]['user_id' if change == 'user' else 'access_token']
        file.write_text(json.dumps(data))
        run('run', exe, artifact, 'shio', 'serein', ok=False)
    alternate = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Homeserver)
    alternate_thread = threading.Thread(target=alternate.serve_forever, daemon=True)
    alternate_thread.start()
    try:
        run('init', artifact); prepare('shio')
        prepare('serein', MATRIX_HOMESERVER_URL=f'http://127.0.0.1:{alternate.server_port}')
        run('run', exe, artifact, 'shio', 'serein', ok=False)
    finally:
        alternate.shutdown(); alternate.server_close(); alternate_thread.join(timeout=2)
    run('init', artifact); prepare('shio')
    run('run', exe, artifact, 'shio', 'serein', ok=False)
    # Unsafe paths are refused and never overwritten or deleted.
    outside = root / 'outside'; outside.write_text('keep')
    (root / 'shio.json').symlink_to(outside)
    tokens['malformed-id-owned'] = 'not-a-matrix-id'
    run('prepare', 'serein', env={**base, 'MATRIX_HOMESERVER_URL': url, 'MATRIX_ACCESS_TOKEN': 'malformed-id-owned'}, ok=False)
    del tokens['malformed-id-owned']
    tokens['unicode-owned'] = '@雪:test'
    run('prepare', 'serein', env={**base, 'MATRIX_HOMESERVER_URL': url, 'MATRIX_ACCESS_TOKEN': 'unicode-owned'})
    assert json.loads((root / 'serein.json').read_text())['entry']['user_id'] == '@雪:test'
    del tokens['unicode-owned']
    run('prepare', 'shio', env=base, ok=False)
    assert outside.read_text() == 'keep' and (root / 'shio.json').is_symlink()
    (root / 'shio.json').unlink()
    outside.chmod(0o600); os.link(outside, root / 'shio.json')
    run('init', artifact, ok=False); assert outside.read_text() == 'keep'
    (root / 'shio.json').unlink()
    root.chmod(0o755); run('init', artifact, ok=False); root.chmod(0o700)
    (root / 'shio.json').write_text('{}'); (root / 'shio.json').chmod(0o644)
    run('init', artifact, ok=False); (root / 'shio.json').unlink()
    run('init', artifact)
    started = time.monotonic()
    run('prepare', 'shio', env={**base, 'MATRIX_HOMESERVER_URL': url, 'MATRIX_ACCESS_TOKEN': 'stall'}, ok=False)
    assert time.monotonic() - started < 12
    assert not list(root.glob('*.tmp'))
home.shutdown(); home.server_close(); thread.join(timeout=2)
assert requests and all(p == '/_matrix/client/v3/account/whoami' for p, _ in requests)
print('PASS private atomic preparation, independent inputs/headers, fixed callback, sanitized exec environment, optional enrollment, failures and bounded whoami')
