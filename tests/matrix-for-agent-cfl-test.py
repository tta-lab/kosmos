"""Test-owned launcher seam; independent Shio launcher."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

launcher = sys.argv[1]
with tempfile.TemporaryDirectory(prefix="kosmos-shio-test-") as tmp:
    root = Path(tmp)
    artifact = root / "cli.js"
    artifact.write_text("test-owned artifact")
    runtime = root / "node"
    runtime.write_text(f"#!{sys.executable}\nimport json,os,sys\nprint(json.dumps({{'argv':sys.argv[1:],'env':dict(os.environ)}}))\n")
    runtime.chmod(0o700)
    env = {"PATH": os.environ["PATH"], "HOME": tmp,
           "MATRIX_HOMESERVER_URL": "http://127.0.0.1:1",
           "MATRIX_ACCESS_TOKEN": "fixture-shio-token",
           "MATRIX_MCP_LISTEN": "0.0.0.0:9999",
           "MATRIX_WEBHOOK_URL": "http://127.0.0.1:1/webhook",
           "MATRIX_WEBHOOK_BEARER_TOKEN": "fixture-webhook-token"}
    result = subprocess.run(["bash", launcher, str(runtime), str(artifact)],
                            env=env, capture_output=True, text=True, check=True)
    observed = json.loads(result.stdout)
    assert observed["argv"] == [str(artifact)]
    assert observed["env"]["MATRIX_MCP_LISTEN"] == "127.0.0.1:8769"
    assert observed["env"]["MATRIX_ACCESS_TOKEN"] == env["MATRIX_ACCESS_TOKEN"]
    assert observed["env"]["MATRIX_HOMESERVER_URL"] == env["MATRIX_HOMESERVER_URL"]
    assert observed["env"]["MATRIX_WEBHOOK_URL"] == "http://127.0.0.1:3084/api/matrix/events"
    assert "MATRIX_WEBHOOK_BEARER_TOKEN" not in observed["env"]
    missing = subprocess.run(["bash", launcher, str(runtime), str(root / "missing")],
                             env=env, capture_output=True, text=True)
    assert missing.returncode == 1 and not missing.stdout
    assert "artifact missing" in missing.stderr
    assert "fixture-shio-token" not in missing.stderr
print("PASS launcher: fixed listener, fixed CFL webhook, credential forwarding, absent artifact")
