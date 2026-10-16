#!/usr/bin/env python3
"""Bootstrap behavior uses only disposable artifact and application state."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(os.environ.get('KOSMOS_REPO_ROOT', Path(__file__).resolve().parent.parent))
with tempfile.TemporaryDirectory(prefix='post-console-test-') as directory:
    work = Path(directory)
    artifact, state = work / 'release with spaces', work / 'state'
    selected = work / 'console-current'
    selected.symlink_to(artifact)
    command = ['bash', str(ROOT / 'scripts/prepare-post-console'), str(selected), str(state)]
    missing = subprocess.run(command, capture_output=True, text=True)
    assert missing.returncode == 1 and 'artifact missing' in missing.stderr
    assert not state.exists()
    (artifact / 'dist').mkdir(parents=True)
    (artifact / 'examples').mkdir()
    (artifact / 'dist/cli.cjs').write_text('// fixture CLI\n')
    template = artifact / 'examples/koishi.preview.yml'
    preview = "accounts: []\nbindings: []\n" + ''.join(
        "  '__POST_ARTIFACT_ROOT__/" + entry + "': {}\n" for entry in [
            'node_modules/@koishijs/plugin-server/index.cjs',
            'node_modules/@koishijs/plugin-console/lib/node/index.js',
            'node_modules/@koishijs/plugin-status/lib/index.js', 'dist/post-plugin.cjs'])
    template.write_text(preview)
    subprocess.run(command, check=True)
    config = state / 'koishi.yml'
    assert config.read_text() == preview.replace('__POST_ARTIFACT_ROOT__', str(artifact.resolve()))
    assert config.stat().st_mode & 0o777 == 0o600
    for path in [state, state / 'keys', state / 'data']:
        assert path.stat().st_mode & 0o777 == 0o700
    assert not list((state / 'keys').iterdir()), 'bootstrap must not issue keys'
    config.write_text('# operator-owned\naccounts: []\nbindings: []\n')
    before = config.stat()
    template.write_text('new upstream template\n')
    subprocess.run(command, check=True)
    assert config.read_text().startswith('# operator-owned')
    assert config.stat().st_ino == before.st_ino
    assert config.stat().st_mtime_ns == before.st_mtime_ns
    assert not list(state.glob('.preview-seed.*'))
    # An invalid template fails before any partial config can be published.
    other_state = work / 'invalid-state'
    invalid = subprocess.run(command[:-1] + [str(other_state)], capture_output=True)
    assert invalid.returncode != 0 and not (other_state / 'koishi.yml').exists()
    assert not list(other_state.glob('.preview-seed.*'))
    template.write_text(preview)
    for suffix in ['$&', '$$', '$`']:
        literal_root = work / ('release-' + suffix)
        artifact.rename(literal_root)
        selected.unlink()
        selected.symlink_to(literal_root)
        literal_state = work / ('state-' + suffix)
        subprocess.run(command[:-1] + [str(literal_state)], check=True)
        expected = preview.replace('__POST_ARTIFACT_ROOT__', str(literal_root.resolve())).encode()
        assert (literal_state / 'koishi.yml').read_bytes() == expected, suffix
        literal_root.rename(artifact)
    bad_root = work / "release'bad"
    artifact.rename(bad_root)
    invalid = subprocess.run(command[:2] + [str(bad_root), str(other_state)], capture_output=True)
    assert invalid.returncode != 0 and not (other_state / 'koishi.yml').exists()
    for unsafe in [str(artifact) + '\n', str(artifact) + '\t', str(artifact) + ':suffix', str(artifact) + '${{root}}', 'relative-release']:
        invalid = subprocess.run(command[:2] + [unsafe, str(other_state)], capture_output=True)
        assert invalid.returncode == 1 and not (other_state / 'koishi.yml').exists()
print('missing-artifact skip, private atomic seed and operator config preservation pass')
