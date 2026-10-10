"""Actual new bundle seam. Run ONLY inside a test-owned network namespace."""
import http.server
import json
import os
from pathlib import Path
import subprocess
import socket
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request

# Fixed Shio callback/listener are safe only in a separate network namespace.
assert os.stat('/proc/self/ns/net').st_ino != int(sys.argv[4])
helper, node, artifact = [str(Path(p).resolve()) for p in sys.argv[1:4]]
tokens = {'shio-owned': '@shio:test', 'serein-owned': '@serein:test', 'dynamic-owned': '@dynamic:test'}
syncs = {}; deliveries = []; auth = []
class Receiver(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_): pass
    def do_POST(self):
        event = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        deliveries.append((self.server.server_port, self.path, self.headers.get('Authorization'), event))
        self.send_response(204); self.end_headers()
class Matrix(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_): pass
    def respond(self):
        token = self.headers.get('Authorization', '').removeprefix('Bearer ')
        route = self.path.split('?')[0]
        if not route.endswith('/versions'): auth.append(token)
        if token not in tokens and not route.endswith('/versions'):
            data = {'errcode': 'M_UNKNOWN_TOKEN'}; status = 401
        else:
            status = 200; uid = tokens.get(token)
            if route.endswith('/whoami'): data = {'user_id': uid, 'device_id': 'OWNED'}
            elif route.endswith('/versions'): data = {'versions': ['v1.11'], 'unstable_features': {}}
            elif route.endswith('/filter'): data = {'filter_id': 'owned'}
            elif route.endswith('/pushrules/'): data = {'global': {k: [] for k in ['override', 'content', 'room', 'sender', 'underride']}}
            elif route.endswith('/sync'):
                count = syncs[token] = syncs.get(token, 0) + 1; time.sleep(.1)
                events = [{'type': 'm.room.message', 'event_id': '$' + token, 'sender': '@sender:test',
                           'origin_server_ts': 1700000000000, 'content': {'msgtype': 'm.text', 'body': token + '-message'}}] if count == 5 else []
                data = {'next_batch': f'{token}-{count}', 'rooms': {'join': {'!owned:test': {
                    'state': {'events': [{'type': 'm.room.member', 'state_key': uid, 'sender': uid, 'content': {'membership': 'join'}}]},
                    'timeline': {'events': events, 'limited': False, 'prev_batch': 'owned'},
                    'ephemeral': {'events': []}, 'account_data': {'events': []}}}}}
            else: data = {}
        body = json.dumps(data).encode()
        try:
            self.send_response(status); self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body))); self.end_headers(); self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError): pass
    do_GET = respond
    do_POST = respond
servers = [http.server.ThreadingHTTPServer(('127.0.0.1', 0), Matrix),
           http.server.ThreadingHTTPServer(('127.0.0.1', 3084), Receiver),
           http.server.ThreadingHTTPServer(('127.0.0.1', 0), Receiver)]
threads = [threading.Thread(target=s.serve_forever, daemon=True) for s in servers]
for t in threads: t.start()
base = {'PATH': os.environ['PATH']}
def request(token=None, method='tools/list', params=None):
    headers = {'Content-Type': 'application/json', 'Accept': 'application/json, text/event-stream'}
    if token: headers['Authorization'] = 'Bearer ' + token
    body = json.dumps({'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params or {}}).encode()
    req = urllib.request.Request('http://127.0.0.1:8768/mcp', body, headers)
    try:
        with urllib.request.urlopen(req, timeout=2) as r: return r.status, json.load(r)
    except urllib.error.HTTPError as e: return e.code, json.load(e)
try:
    with tempfile.TemporaryDirectory(prefix='kosmos-matrix-actual-') as tmp:
        root = Path(tmp); root.chmod(0o700)
        home = f'http://127.0.0.1:{servers[0].server_port}'
        def prep(action, *args, env=base):
            subprocess.run([node, helper, action, tmp, *args], env=env, capture_output=True, check=True)
        prep('init', artifact)
        for kind in ['shio', 'serein']:
            prep('prepare', kind, env={**base, 'MATRIX_HOMESERVER_URL': home, 'MATRIX_ACCESS_TOKEN': kind+'-owned',
                'MATRIX_WEBHOOK_URL': f'http://127.0.0.1:{servers[2].server_port}/serein', 'MATRIX_WEBHOOK_BEARER_TOKEN': 'receiver-owned'})
        with (root / 'owned-runtime.log').open('w+') as log:
            proc = subprocess.Popen([node, helper, 'run', tmp, node, artifact, 'shio', 'serein'], env=base, stdout=log, stderr=log)
            try:
                for _ in range(150):
                    assert proc.poll() is None, 'actual bundle exited early'
                    try:
                        if request()[0] == 401: break
                    except urllib.error.URLError: pass
                    time.sleep(.05)
                else: raise AssertionError('listener unavailable')
                with socket.socket() as probe:
                    assert probe.connect_ex(('127.0.0.1', 8769)) != 0
                config = json.loads((root / 'webhooks.json').read_text())
                assert [e['user_id'] for e in config] == ['@shio:test', '@serein:test']
                for token, uid in tokens.items():
                    status, result = request(token, 'tools/call', {'name':'whoami','arguments':{}})
                    assert status == 200 and json.loads(result['result']['content'][0]['text'])['user_id'] == uid
                assert request('invalid-owned')[0] == 401
                for _ in range(100):
                    if len(deliveries) >= 2 and syncs.get('dynamic-owned', 0) >= 6: break
                    time.sleep(.05)
                assert len(deliveries) == 2, deliveries
                by_port = {d[0]: d for d in deliveries}
                assert by_port[3084][1:3] == ('/api/matrix/events', None)
                assert by_port[servers[2].server_port][1:3] == ('/serein', 'Bearer receiver-owned')
                assert by_port[3084][3]['body'] == 'shio-owned-message'
                assert by_port[servers[2].server_port][3]['body'] == 'serein-owned-message'
                proc.terminate()
                for _ in range(100):
                    try: request()
                    except (urllib.error.URLError, ConnectionError): break
                    time.sleep(.01)
                else: raise AssertionError('HTTP not closed after SIGTERM')
                try: proc.wait(timeout=1)
                except subprocess.TimeoutExpired: proc.kill(); proc.wait()
                log.seek(0); output = log.read()
                assert all(secret not in output for secret in [*tokens, 'receiver-owned'])
            finally:
                if proc.poll() is None: proc.kill(); proc.wait()
        rejected = subprocess.run([node, artifact], env={**base, 'MATRIX_HOMESERVER_URL': home, 'MATRIX_ACCESS_TOKEN':'obsolete-owned'}, capture_output=True, text=True, timeout=5)
        assert rejected.returncode != 0 and 'is obsolete' in rejected.stderr and 'obsolete-owned' not in rejected.stderr
finally:
    for s in servers: s.shutdown(); s.server_close()
    for t in threads: t.join(timeout=2)
print('PASS generated private JSON accepted by approved actual MFA, two independent background deliveries, three-token whoami isolation, invalid/obsolete rejection, HTTP closure')
