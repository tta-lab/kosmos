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
    assert observed["env"]["MATRIX_WEBHOOK_URL"] == env["MATRIX_WEBHOOK_URL"]
    assert observed["env"]["MATRIX_WEBHOOK_BEARER_TOKEN"] == env["MATRIX_WEBHOOK_BEARER_TOKEN"]
    disabled_env = {k: v for k, v in env.items() if not k.startswith("MATRIX_WEBHOOK_")}
    disabled = subprocess.run(["bash", launcher, str(runtime), str(artifact)],
                              env=disabled_env, capture_output=True, text=True, check=True)
    disabled_observed = json.loads(disabled.stdout)
    assert disabled_observed["env"]["MATRIX_MCP_LISTEN"] == "127.0.0.1:8768"
    assert "MATRIX_WEBHOOK_URL" not in disabled_observed["env"]
    assert "MATRIX_WEBHOOK_BEARER_TOKEN" not in disabled_observed["env"]
    missing = subprocess.run(["bash", launcher, str(runtime), str(root / "missing")],
                             env=env, capture_output=True, text=True)
    assert missing.returncode == 1 and not missing.stdout
    assert "artifact missing" in missing.stderr
    assert all(value not in missing.stderr for value in
               [env["MATRIX_ACCESS_TOKEN"], env["MATRIX_WEBHOOK_BEARER_TOKEN"], env["MATRIX_WEBHOOK_URL"]])
print("PASS launcher: fixed listener, optional webhook forwarding/default off, credential forwarding, absent artifact")

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
    webhook_token = "owned-fixture-webhook-token"
    deliveries = []
    delivered = threading.Event()

    class Receiver(http.server.BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_POST(self):
            body = self.rfile.read(int(self.headers["Content-Length"]))
            deliveries.append((self.path, self.headers.get("Authorization"),
                               self.headers.get("Content-Type"), json.loads(body)))
            self.send_response(204)
            self.end_headers()
            delivered.set()

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
                # The SDK requires a joined-room membership and advancing sync
                # cursors so a later timeline is recognized as a live event.
                events = []
                if len(syncs) == 4:
                    events = [{"type": "m.room.message", "event_id": "$owned-event",
                               "sender": "@sender:test", "origin_server_ts": 1700000000000,
                               "content": {"msgtype": "m.text", "body": "owned fixture message"}}]
                data = {"next_batch": f"fixture-{len(syncs)}", "rooms": {"join": {
                    "!owned:test": {"state": {"events": [{"type": "m.room.member",
                        "state_key": "@fixture:test", "sender": "@fixture:test",
                        "content": {"membership": "join"}}]},
                        "timeline": {"events": events, "limited": False, "prev_batch": "owned"},
                        "ephemeral": {"events": []}, "account_data": {"events": []}}}}}
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
    receiver = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Receiver)
    receiver_thread = threading.Thread(target=receiver.serve_forever, daemon=True)
    receiver_thread.start()
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    env = {"PATH": os.environ["PATH"], "MATRIX_ACCESS_TOKEN": token,
           "MATRIX_HOMESERVER_URL": f"http://127.0.0.1:{home.server_port}",
           "MATRIX_MCP_LISTEN": f"127.0.0.1:{port}",
           "MATRIX_WEBHOOK_URL": f"http://127.0.0.1:{receiver.server_port}/matrix/events",
           "MATRIX_WEBHOOK_BEARER_TOKEN": webhook_token}
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
                assert delivered.wait(timeout=5), "owned webhook did not receive a live fixture event"
                assert len(deliveries) == 1
                path, bearer, content_type, event = deliveries[0]
                assert path == "/matrix/events"
                assert bearer == "Bearer " + webhook_token and token not in bearer
                assert content_type == "application/json"
                assert event["type"] == "message" and event["room_id"] == "!owned:test"
                assert event["event_id"] == "$owned-event"
                assert event["body"] == "owned fixture message"
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
                output = log.read()
                assert token not in output and webhook_token not in output
            finally:
                if proc.poll() is None:
                    proc.kill()
                    proc.wait()
                home.shutdown()
                home.server_close()
                thread.join(timeout=2)
                receiver.shutdown()
                receiver.server_close()
                receiver_thread.join(timeout=2)
    print("PASS real MFA bundle: fake Matrix auth, MCP 401/retired-key rejection, five tools, whoami, independent JSON webhook bearer, SIGTERM, no token logs")
