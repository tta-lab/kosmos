"""Test-owned launcher seam; optional real MFA artifact against a fake Matrix host."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

launcher = sys.argv[1]
with tempfile.TemporaryDirectory(prefix="kosmos-mfa-test-") as tmp:
    root = Path(tmp)
    artifact = root / "cli.js"
    artifact.write_text("test-owned artifact")
    runtime = root / "node"
    runtime.write_text(f"#!{sys.executable}\nimport json,os,sys\nprint(json.dumps({{'argv':sys.argv[1:],'env':dict(os.environ)}}))\n")
    runtime.chmod(0o700)
    env = {"PATH": os.environ["PATH"], "HOME": tmp,
           "MATRIX_HOMESERVER_URL": "http://127.0.0.1:1",
           "MATRIX_ACCESS_TOKEN": "fixture-matrix-token",
           "MATRIX_MCP_LISTEN": "0.0.0.0:9999",
           "MATRIX_WEBHOOK_URL": "http://127.0.0.1:1/webhook",
           "MATRIX_WEBHOOK_BEARER_TOKEN": "fixture-webhook-token"}
    result = subprocess.run(["bash", launcher, str(runtime), str(artifact)],
                            env=env, capture_output=True, text=True, check=True)
    observed = json.loads(result.stdout)
    assert observed["argv"] == [str(artifact)]
    assert observed["env"]["MATRIX_MCP_LISTEN"] == "127.0.0.1:8768"
    assert observed["env"]["MATRIX_ACCESS_TOKEN"] == env["MATRIX_ACCESS_TOKEN"]
    assert observed["env"]["MATRIX_HOMESERVER_URL"] == env["MATRIX_HOMESERVER_URL"]
    assert "MATRIX_WEBHOOK_URL" not in observed["env"]
    assert "MATRIX_WEBHOOK_BEARER_TOKEN" not in observed["env"]
    missing = subprocess.run(["bash", launcher, str(runtime), str(root / "missing")],
                             env=env, capture_output=True, text=True)
    assert missing.returncode == 1 and not missing.stdout
    assert "artifact missing" in missing.stderr
    assert "fixture-matrix-token" not in missing.stderr
print("PASS launcher: fixed listener, disabled webhook, credential forwarding, absent artifact")

# Outside the Nix check: run a supplied real bundle, with owned ephemeral ports.
if len(sys.argv) == 4:
    import http.server
    import socket
    import threading
    import time
    import urllib.error
    import urllib.request

    token = "owned-fixture-matrix-token"
    auth = []
    syncs = []

    class MatrixHost(http.server.BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def respond(self):
            path = self.path.split("?")[0]
            if not path.endswith("/versions"):
                auth.append(self.headers.get("Authorization"))
            if path.endswith("/whoami"):
                data = {"user_id": "@fixture:test", "device_id": "TEST"}
            elif path.endswith("/versions"):
                data = {"versions": ["v1.11"], "unstable_features": {}}
            elif path.endswith("/sync"):
                syncs.append(True)
                time.sleep(0.1)
                data = {"next_batch": "fixture", "rooms": {}}
            elif path.endswith("/filter"):
                data = {"filter_id": "fixture"}
            elif path.endswith("/pushrules/"):
                data = {"global": {k: [] for k in ["override", "content", "room", "sender", "underride"]}}
            else:
                data = {}
            body = json.dumps(data).encode()
            try:
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError):
                pass

        do_GET = respond
        do_POST = respond

    home = http.server.ThreadingHTTPServer(("127.0.0.1", 0), MatrixHost)
    thread = threading.Thread(target=home.serve_forever, daemon=True)
    thread.start()
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    env = {"PATH": os.environ["PATH"], "MATRIX_ACCESS_TOKEN": token,
           "MATRIX_HOMESERVER_URL": f"http://127.0.0.1:{home.server_port}",
           "MATRIX_MCP_LISTEN": f"127.0.0.1:{port}"}
    with tempfile.TemporaryDirectory(prefix="kosmos-mfa-http-") as tmp:
        env["HOME"] = tmp
        with (Path(tmp) / "runtime.log").open("w+") as log:
            proc = subprocess.Popen([sys.argv[2], sys.argv[3]], env=env,
                                    cwd=tmp, stdout=log, stderr=log)
            def request(bearer=None, method="tools/list", params=None):
                body = json.dumps({"jsonrpc": "2.0", "id": 1,
                                   "method": method, "params": params or {}}).encode()
                headers = {"Content-Type": "application/json", "Accept": "application/json, text/event-stream"}
                if bearer is not None:
                    headers["Authorization"] = "Bearer " + bearer
                req = urllib.request.Request(f"http://127.0.0.1:{port}/mcp", body, headers)
                try:
                    with urllib.request.urlopen(req, timeout=2) as res:
                        return res.status, json.load(res)
                except urllib.error.HTTPError as error:
                    return error.code, json.load(error)
            try:
                for attempt in range(100):
                    if proc.poll() is not None:
                        raise AssertionError("MFA exited before owned HTTP listener was ready")
                    try:
                        assert request()[0] == 401
                        break
                    except urllib.error.URLError:
                        time.sleep(0.05)
                else:
                    raise AssertionError("owned MFA listener did not become ready")
                assert request("retired-gateway-fixture")[0] == 401
                status, result = request(token)
                assert status == 200
                assert {t["name"] for t in result["result"]["tools"]} == {
                    "whoami", "list_rooms", "list_room_members", "send_message", "read_messages"}
                status, result = request(token, "tools/call", {"name": "whoami", "arguments": {}})
                assert status == 200
                assert json.loads(result["result"]["content"][0]["text"])["user_id"] == "@fixture:test"
                assert auth and all(a == "Bearer " + token for a in auth)
                proc.terminate()
                # SDK timers may outlive graceful HTTP shutdown. The unit bounds
                # this with TimeoutStopSec; verify listener shutdown separately.
                for attempt in range(100):
                    try:
                        request(token)
                    except (urllib.error.URLError, ConnectionError):
                        break
                    time.sleep(0.01)
                else:
                    raise AssertionError("MFA listener remained open after SIGTERM")
                try:
                    proc.wait(timeout=1)
                    assert proc.returncode == 0
                    print("MFA graceful process exit")
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait()
                    print("MFA HTTP closed; remaining SDK timers required bounded process kill")
                log.seek(0)
                assert token not in log.read()
            finally:
                if proc.poll() is None:
                    proc.kill()
                    proc.wait()
                home.shutdown()
                home.server_close()
                thread.join(timeout=2)
    print("PASS real MFA bundle: fake Matrix auth, MCP 401/retired-key rejection, five tools, whoami, SIGTERM, no token logs")
