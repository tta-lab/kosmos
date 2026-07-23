#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path
from urllib.parse import urlsplit


REPO_ROOT = Path(
    os.environ.get("KOSMOS_REPO_ROOT", Path(__file__).resolve().parents[1])
)
FORGEJO_TOKEN_NAMES = ("FORGEJO_TOKEN", "FORGEJO_ACCESS_TOKEN", "GITEA_TOKEN")


class SyncProjectsAuthTest(unittest.TestCase):
    def test_routes_tokens_by_forge_and_org(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            test_root = Path(temporary_directory)
            bin_dir = test_root / "bin"
            code_root = test_root / "code"
            bin_dir.mkdir()
            (code_root / "projects" / "GuionAI").mkdir(parents=True)
            (code_root / "projects" / "tta-lab").mkdir(parents=True)

            env_file = test_root / "ttal.env"
            env_file.write_text(
                textwrap.dedent(
                    """\
                    # Unrelated values must not be loaded.
                    MATRIX_ACCESS_TOKEN=do-not-load
                    FORGEJO_TOKEN=test-forgejo-token
                    GUION_GITHUB_TOKEN=test-guion-github-token
                    GITHUB_TOKEN=test-default-github-token
                    """
                )
            )
            projects_file = test_root / "projects.toml"
            projects_file.write_text(
                textwrap.dedent(
                    f"""\
                    [slse]
                    path = "{code_root}/projects/GuionAI/sliqs-services"
                    remote = "http://forgejo.localhost:17480/GuionAI/sliqs-services.git"

                    [cnsupa]
                    path = "{code_root}/projects/GuionAI/cloudnative-supabase"
                    remote = "https://github.com/GuionAI/cloudnative-supabase.git"

                    [agora]
                    path = "{code_root}/projects/tta-lab/agora"
                    """
                )
            )
            (test_root / "orgs.toml").write_text(
                '[GuionAI]\ngithub_token_env = "GUION_GITHUB_TOKEN"\n'
            )

            calls_file = test_root / "git-calls.jsonl"
            fake_git = bin_dir / "git"
            fake_git.write_text(
                f"#!{sys.executable}\n"
                + textwrap.dedent(
                    """\
                    import json
                    import os
                    import sys

                    call = {
                        "argv": sys.argv[1:],
                        "token": os.environ.get("GIT_TOKEN_INJECT"),
                        "config_count": os.environ.get("GIT_CONFIG_COUNT"),
                        "helper": os.environ.get("GIT_CONFIG_VALUE_1"),
                        "credential_host": os.environ.get("GIT_CREDENTIAL_HOST"),
                        "unrelated": os.environ.get("MATRIX_ACCESS_TOKEN"),
                    }
                    with open(os.environ["SYNC_TEST_CALLS"], "a") as handle:
                        handle.write(json.dumps(call) + "\\n")
                    """
                )
            )
            fake_git.chmod(0o755)

            env = os.environ.copy()
            for name in (
                "FORGEJO_TOKEN",
                "FORGEJO_ACCESS_TOKEN",
                "GITEA_TOKEN",
                "GUION_GITHUB_TOKEN",
                "GITHUB_TOKEN",
                "GH_TOKEN",
                "MATRIX_ACCESS_TOKEN",
            ):
                env.pop(name, None)
            env.update(
                {
                    "PATH": f"{bin_dir}:{env['PATH']}",
                    "SYNC_TEST_CALLS": str(calls_file),
                }
            )

            result = subprocess.run(
                [
                    "python3",
                    str(REPO_ROOT / "scripts" / "sync-projects"),
                    "--projects-file",
                    str(projects_file),
                    "--env-file",
                    str(env_file),
                    "--code-root",
                    str(code_root),
                    "--alias",
                    "slse",
                    "--alias",
                    "cnsupa",
                    "--alias",
                    "agora",
                ],
                check=False,
                capture_output=True,
                env=env,
                text=True,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            calls = [json.loads(line) for line in calls_file.read_text().splitlines()]
            self.assertEqual(len(calls), 3)

            expected_tokens = {
                "http://forgejo.localhost:17480/GuionAI/sliqs-services.git": (
                    "test-forgejo-token"
                ),
                "https://github.com/GuionAI/cloudnative-supabase.git": (
                    "test-guion-github-token"
                ),
                "https://github.com/tta-lab/agora.git": "test-default-github-token",
            }
            for call in calls:
                remote = call["argv"][1]
                parsed = urlsplit(remote)
                self.assertEqual(call["token"], expected_tokens[remote])
                self.assertEqual(call["config_count"], "2")
                helper_env = os.environ.copy()
                helper_env.update(
                    {
                        "GIT_TOKEN_INJECT": call["token"],
                        "GIT_CREDENTIAL_PROTOCOL": parsed.scheme,
                        "GIT_CREDENTIAL_HOST": parsed.netloc,
                    }
                )
                attacker_result = subprocess.run(
                    ["bash", "-c", call["helper"].removeprefix("!")],
                    check=False,
                    capture_output=True,
                    env=helper_env,
                    input=f"protocol={parsed.scheme}\nhost=attacker.invalid\n\n",
                    text=True,
                )
                self.assertNotIn(call["token"], attacker_result.stdout)
                authorized_result = subprocess.run(
                    ["bash", "-c", call["helper"].removeprefix("!")],
                    check=False,
                    capture_output=True,
                    env=helper_env,
                    input=(
                        f"protocol={parsed.scheme}\n"
                        f"host={parsed.netloc}\n\n"
                    ),
                    text=True,
                )
                self.assertIn(call["token"], authorized_result.stdout)
                self.assertEqual(call["credential_host"], parsed.netloc)
                self.assertIsNone(call["unrelated"])
                self.assertNotIn(call["token"], call["argv"])

            for token in expected_tokens.values():
                self.assertNotIn(token, result.stdout)
                self.assertNotIn(token, result.stderr)

    def test_fetch_selects_credentials_from_the_actual_origin(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            test_root = Path(temporary_directory)
            bin_dir = test_root / "bin"
            repo_path = test_root / "code" / "projects" / "GuionAI" / "existing"
            bin_dir.mkdir()
            repo_path.mkdir(parents=True)

            env_file = test_root / "ttal.env"
            env_file.write_text("FORGEJO_TOKEN=test-forgejo-token\n")
            projects_file = test_root / "projects.toml"
            projects_file.write_text(
                textwrap.dedent(
                    f"""\
                    [existing]
                    path = "{repo_path}"
                    remote = "https://git.guion.io/GuionAI/existing.git"
                    """
                )
            )

            fetch_file = test_root / "fetch.json"
            fake_git = bin_dir / "git"
            fake_git.write_text(
                f"#!{sys.executable}\n"
                + textwrap.dedent(
                    """\
                    import json
                    import os
                    import sys

                    if "rev-parse" in sys.argv:
                        raise SystemExit(0)
                    if "get-url" in sys.argv:
                        print("https://attacker.invalid/redirected.git")
                        raise SystemExit(0)
                    if "fetch" in sys.argv:
                        with open(os.environ["SYNC_TEST_FETCH"], "w") as handle:
                            json.dump(
                                {"token": os.environ.get("GIT_TOKEN_INJECT")},
                                handle,
                            )
                        raise SystemExit(0)
                    raise SystemExit(f"unexpected git invocation: {sys.argv[1:]}")
                    """
                )
            )
            fake_git.chmod(0o755)

            env = os.environ.copy()
            for name in FORGEJO_TOKEN_NAMES:
                env.pop(name, None)
            env.update(
                {
                    "PATH": f"{bin_dir}:{env['PATH']}",
                    "SYNC_TEST_FETCH": str(fetch_file),
                }
            )
            result = subprocess.run(
                [
                    "python3",
                    str(REPO_ROOT / "scripts" / "sync-projects"),
                    "--projects-file",
                    str(projects_file),
                    "--env-file",
                    str(env_file),
                    "--code-root",
                    str(test_root / "code"),
                    "--alias",
                    "existing",
                ],
                check=False,
                capture_output=True,
                env=env,
                text=True,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIsNone(json.loads(fetch_file.read_text())["token"])


if __name__ == "__main__":
    unittest.main()
