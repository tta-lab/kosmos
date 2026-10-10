"""Optional host check: only owned transient units and synthetic EnvironmentFiles."""
import http.server
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading

helper, node = map(str, map(Path, sys.argv[1:3]))
helper = str(Path(helper).resolve()); node = str(Path(node).resolve())
token = 'owned-"\\$token'
seen = []
class Host(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_): pass
    def do_GET(self):
        seen.append(self.headers.get('Authorization'))
        body = b'{"user_id":"@owned:test"}'
        self.send_response(200); self.send_header('Content-Length', str(len(body)))
        self.end_headers(); self.wfile.write(body)
home = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Host)
thread = threading.Thread(target=home.serve_forever, daemon=True); thread.start()
try:
    with tempfile.TemporaryDirectory(prefix='kosmos-matrix-systemd-') as tmp:
        root = Path(tmp); root.chmod(0o700)
        fixture = root / 'input.env'
        fixture.write_text(f'''# systemd syntax, never shell sourced
MATRIX_HOMESERVER_URL="http://127.0.0.1:\\
{home.server_port}/"
MATRIX_ACCESS_TOKEN=discarded-fixture
MATRIX_ACCESS_TOKEN='{token}'
MATRIX_WEBHOOK_URL="http://localhost:1234/events"
MATRIX_WEBHOOK_BEARER_TOKEN='independent-$bearer'
UNRELATED='$(touch should-not-exist)'
''')
        fixture.chmod(0o600)
        for attempt in range(2):
            p = subprocess.run(['systemd-run', '--user', '--wait', '--pipe', '--collect',
                                f'--unit=kosmos-matrix-fixture-{os.getpid()}-{attempt}',
                                '--property=Type=oneshot', '--property=UMask=0077',
                                '--property=TimeoutStartSec=15',
                                '--property=Environment=MATRIX_HOMESERVER_URL= MATRIX_ACCESS_TOKEN= MATRIX_WEBHOOK_URL= MATRIX_WEBHOOK_BEARER_TOKEN=',
                                '--property=UnsetEnvironment=MATRIX_WEBHOOK_URL= MATRIX_WEBHOOK_BEARER_TOKEN=', f'--property=WorkingDirectory={tmp}',
                                f'--property=EnvironmentFile={fixture}', node, helper, 'prepare', tmp, 'serein'],
                               capture_output=True, text=True, timeout=20)
            assert p.returncode == 0, p.stderr
            data = json.loads((root / 'serein.json').read_text())
            assert data['entry']['access_token'] == token
            assert data['entry']['bearer_token'] == 'independent-$bearer'
            assert data['home'] == f'http://127.0.0.1:{home.server_port}'
            assert not (root / 'should-not-exist').exists()
            assert (root / 'serein.json').stat().st_mode & 0o777 == 0o600
        fixture.write_text(f"MATRIX_HOMESERVER_URL=http://127.0.0.1:{home.server_port}\nMATRIX_ACCESS_TOKEN='{token}'\n")
        p = subprocess.run(['systemd-run', '--user', '--wait', '--pipe', '--collect',
                            f'--unit=kosmos-matrix-fixture-{os.getpid()}-optional',
                            '--property=Type=oneshot',
                            '--property=Environment=MATRIX_HOMESERVER_URL= MATRIX_ACCESS_TOKEN= MATRIX_WEBHOOK_URL= MATRIX_WEBHOOK_BEARER_TOKEN=',
                            '--property=UnsetEnvironment=MATRIX_WEBHOOK_URL= MATRIX_WEBHOOK_BEARER_TOKEN=',
                            f'--property=EnvironmentFile={fixture}', node, helper, 'prepare', tmp, 'serein'],
                           capture_output=True, text=True, timeout=20)
        assert p.returncode == 0, p.stderr
        assert json.loads((root / 'serein.json').read_text())['entry'] == {'user_id':'@owned:test','access_token':token}
        assert seen == ['Bearer ' + token] * 3
finally:
    home.shutdown(); home.server_close(); thread.join(timeout=2)
print('PASS real systemd EnvironmentFile quoting, continuation, repeated assignments, literal shell syntax, fresh preparation')
