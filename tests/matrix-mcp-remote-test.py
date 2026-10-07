#!/usr/bin/env python3
"""Observable gateway probes; all config, keys, children and locks are fixtures."""
import concurrent.futures
import fcntl
import json
import os
from pathlib import Path
import shlex
import select
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

FAKE = r'''
import fcntl, json, os, pathlib, subprocess, sys, time
root = pathlib.Path(sys.argv[1])
with (root / "pids").open("a") as p: p.write(str(os.getpid()) + "\n")
for line in sys.stdin:
    m = json.loads(line)
    if "id" not in m: continue
    if m["method"] == "initialize":
        result = {"protocolVersion": "2024-11-05", "capabilities": {"tools": {}}, "serverInfo": {"name": "fake", "version": "1"}}
    elif m["method"] == "tools/list":
        result = {"tools": []}
    else:
        with (root / "store.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            if m.get("params", {}).get("name") == "hang":
                descendant = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(300)"])
                with (root / "pids").open("a") as p: p.write(str(descendant.pid) + "\n")
                (root / "locked").touch()
                time.sleep(300)
            else: time.sleep(0.15)
            result = {"content": [{"type": "text", "text": str(os.getpid())}]}
    print(json.dumps({"jsonrpc": "2.0", "id": m["id"], "result": result}), flush=True)
'''


def eventually(check, seconds=10):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if check():
            return
        time.sleep(0.05)
    raise AssertionError("lifecycle condition did not settle")


def alive(pid):
    try:
        return Path(f"/proc/{pid}/stat").read_text().split()[2] != "Z"
    except FileNotFoundError:
        return False


# Compatible with MatrixIdStore's unlocked snapshot/allocate/save behavior.
# stdin gates the first save so the old launcher deterministically lets the
# second process load the same empty snapshot before either allocates a ref.
ID_STORE = r'''
import json, os, pathlib, sys
path = pathlib.Path(os.environ["XDG_CONFIG_HOME"]) / "id-map.json"
state = json.loads(path.read_text()) if path.exists() else {"rooms": {}, "events": {}}
print("loaded", flush=True)
sys.stdin.readline()
refs = []
for kind, prefix in [("rooms", "!"), ("events", "$")]:
    key = prefix + sys.argv[1] + ":fixture.invalid"
    state[kind][key] = len(state[kind]) + 1
    refs.append(state[kind][key])
path.write_text(json.dumps(state))
print(json.dumps(refs), flush=True)
'''


def id_map_probe(launcher, remote, env):
    children = []
    lock_path = remote / "stdio.lock"

    def locked():
        with lock_path.open("a") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                return False
            except BlockingIOError:
                return True

    try:
        for name in ["a", "b"]:
            children.append(subprocess.Popen(
                ["bash", str(launcher), str(remote), sys.executable, "-c", ID_STORE, name],
                env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True))
            if name == "a":
                eventually(lambda: bool(select.select([children[0].stdout], [], [], 0)[0]))
                assert children[0].stdout.readline().strip() == "loaded"
        # Old launcher: wait for the second snapshot to load. Fixed launcher:
        # the first child's lifetime lock prevents that load until it exits.
        eventually(lambda: locked() or bool(select.select([children[1].stdout], [], [], 0)[0]))
        first, _ = children[0].communicate("save\n", timeout=5)
        second, _ = children[1].communicate("save\n", timeout=5)
        assert all(child.returncode == 0 for child in children)
        a_refs = json.loads(first.strip())
        b_refs = json.loads(second.splitlines()[-1])
        assert all(a != b for a, b in zip(a_refs, b_refs)), (a_refs, b_refs)
        state = json.loads((remote / "config/id-map.json").read_text())
        for kind, prefix, index in [("rooms", "!", 0), ("events", "$", 1)]:
            reverse = {ref: key for key, ref in state[kind].items()}
            assert reverse[a_refs[index]] == prefix + "a:fixture.invalid"
            assert reverse[b_refs[index]] == prefix + "b:fixture.invalid"
        assert not locked(), "completed stdio child retained lifetime lock"
        print("PASS: concurrent snapshots preserve distinct room/event refs and resolution")
    finally:
        for child in children:
            if child.poll() is None:
                child.kill()
            child.wait(timeout=5)


def main():
    gateway = sys.argv[1]
    with tempfile.TemporaryDirectory(prefix="matrix-gateway-test-") as directory:
        root = Path(directory)
        fake = root / "fake.py"
        fake.write_text(FAKE)
        key = root / "key"
        key.write_text("fixture-key\n")
        key.chmod(0o600)
        with socket.socket() as reservation:
            reservation.bind(("127.0.0.1", 0))
            port = reservation.getsockname()[1]
        # A missing independent config must not invoke Matrix even if Shio's
        # config exists. HOME below belongs solely to this test.
        home = root / "home"
        shio = home / ".config/matrix-mcp/config.json"
        shio.parent.mkdir(parents=True)
        shio.write_text('{"fixture": "shio"}')
        remote = root / "remote"
        launcher = Path(sys.argv[2])
        invoked = root / "invoked"
        fake_command = [sys.executable, "-c", "import os,pathlib; pathlib.Path(os.environ['MARKER']).write_text(os.environ['XDG_CONFIG_HOME'])"]
        launcher_env = dict(os.environ, HOME=str(home), MARKER=str(invoked))
        result = subprocess.run(["bash", str(launcher), str(remote), *fake_command], env=launcher_env, capture_output=True)
        assert result.returncode != 0 and not invoked.exists()
        independent = remote / "config/matrix-mcp/config.json"
        independent.parent.mkdir(parents=True)
        independent.write_text('{"fixture": "remote"}')
        subprocess.run(["bash", str(launcher), str(remote), *fake_command], env=launcher_env, check=True)
        assert invoked.read_text() == str(remote / "config")
        id_map_probe(launcher, remote, launcher_env)
        independent.unlink()
        invoked.unlink()
        result = subprocess.run(["bash", str(launcher), str(remote), *fake_command], env=launcher_env, capture_output=True)
        assert result.returncode != 0 and not invoked.exists()
        independent.write_text('{"fixture": "remote"}')
        command = [gateway, "--stdio", shlex.join(["bash", str(launcher), str(remote), sys.executable, str(fake), str(root)]),
                   "--outputTransport", "streamableHttp", "--host", "127.0.0.1",
                   "--port", str(port), "--apiKeyFile", str(key), "--logLevel", "none"]
        env = {k: v for k, v in os.environ.items() if not k.startswith("SUPERGATEWAY_")}
        env.update(HOME=str(root), XDG_CONFIG_HOME=str(root / "config"), XDG_CACHE_HOME=str(root / "cache"))
        logs = root / "gateway.log"
        processes = []

        def start():
            with logs.open("ab") as log:
                process = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=log, stderr=log, env=env)
            processes.append(process)
            eventually(lambda: ready(process))
            return process

        def request(body=None, token=None, method="POST"):
            headers = {"Content-Type": "application/json", "Accept": "application/json, text/event-stream"}
            if token is not None:
                headers["Authorization"] = "Bearer " + token
            req = urllib.request.Request(f"http://127.0.0.1:{port}/mcp", headers=headers, method=method,
                                         data=json.dumps(body).encode() if body is not None else None)
            try:
                with urllib.request.urlopen(req, timeout=15) as response:
                    return response.status, response.read().decode(), response.headers
            except urllib.error.HTTPError as error:
                return error.code, error.read().decode(), error.headers

        def ready(process):
            assert process.poll() is None, "gateway exited with /dev/null stdin"
            try:
                return request(method="GET")[0] == 401
            except OSError:
                return False

        def call(name="ok"):
            status, body, headers = request({"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {"name": name, "arguments": {}}}, "fixture-key")
            assert status == 200, (status, body)
            assert "mcp-session-id" not in headers
            payload = json.loads(next(line[6:] for line in body.splitlines() if line.startswith("data: ")))
            assert payload["id"] == 1 and "result" in payload, payload
            return int(payload["result"]["content"][0]["text"])

        def fixture_pids():
            return [int(p) for p in (root / "pids").read_text().split()] if (root / "pids").exists() else []

        try:
            process = start()
            for method in ["GET", "POST", "DELETE"]:
                for token in [None, "wrong-key"]:
                    assert request({}, token, method)[0] == 401
            assert not fixture_pids(), "unauthenticated requests started a child"
            # Inspect the actual bound socket, not source strings or configuration.
            bound = []
            for table in ["/proc/net/tcp", "/proc/net/tcp6"]:
                for line in Path(table).read_text().splitlines()[1:]:
                    fields = line.split()
                    if int(fields[1].split(":")[1], 16) == port and fields[3] == "0A":
                        bound.append(fields[1].split(":")[0])
            assert bound == ["0100007F"], bound
            with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
                pids = list(executor.map(lambda _: call(), range(2)))
            assert len(set(pids)) == 2, "stateless requests did not own separate children"
            eventually(lambda: all(not alive(p) for p in fixture_pids()))
            assert call() not in pids, "reconnect retained an old child"
            eventually(lambda: all(not alive(p) for p in fixture_pids()))
            with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
                pending = executor.submit(call, "hang")
                eventually(lambda: (root / "locked").exists())
                queued = executor.submit(call)
                # Observe both gateway-owned process groups, including the
                # launcher waiting in flock before it can start the fixture.
                def descendants(pid):
                    try:
                        children = [int(p) for p in Path(f"/proc/{pid}/task/{pid}/children").read_text().split()]
                    except FileNotFoundError:
                        return []
                    return children + [p for child in children for p in descendants(child)]

                eventually(lambda: len(Path(f"/proc/{process.pid}/task/{process.pid}/children").read_text().split()) >= 2)
                owned_pids = descendants(process.pid)
                process.terminate()
                process.wait(timeout=12)
                for request_future in [pending, queued]:
                    try:
                        request_future.result(timeout=5)
                        raise AssertionError("interrupted request succeeded")
                    except (OSError, AssertionError) as error:
                        assert str(error) != "interrupted request succeeded"
                eventually(lambda: all(not alive(p) for p in owned_pids))
            eventually(lambda: all(not alive(p) for p in fixture_pids()))
            with (root / "store.lock").open("a") as lock:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            with (remote / "stdio.lock").open("a") as lock:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            restarted = start()
            call()
            restarted.terminate()
            restarted.wait(timeout=12)
            eventually(lambda: all(not alive(p) for p in fixture_pids()))
            assert "fixture-key" not in logs.read_text(), "key leaked into logs"
            key.write_text("")
            with logs.open("ab") as log:
                failed = subprocess.run(command, stdin=subprocess.DEVNULL, stdout=log, stderr=log, env=env, timeout=10)
            assert failed.returncode != 0, "empty key started an unauthenticated gateway"
            print("PASS: auth, loopback, stateless concurrency/reconnect, child and descendant shutdown, lock release, restart, empty key")
        finally:
            for process in processes:
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=12)
            # Only recorded children from this test-owned fixture may be cleaned up.
            for pid in fixture_pids():
                if alive(pid):
                    os.kill(pid, 9)


if __name__ == "__main__":
    main()
