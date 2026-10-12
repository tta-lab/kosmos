"""Exercise the generated unit with test-owned keys, sshd and loopback ports."""
import json
import os
import pwd
from pathlib import Path
import shlex
import socket
import subprocess
import sys
import tempfile
import time

unit = json.loads(Path(sys.argv[1]).read_text())
service = unit['Service']
assert service['Type'] == 'exec' and service['Restart'] == 'always'
assert service['RestartSec'] == '5s' and service['KillMode'] == 'control-group'
assert unit['Unit']['StartLimitIntervalSec'] == 0
assert unit['Install']['WantedBy'] == ['default.target']
args = shlex.split(service['ExecStart'])
# -G validates OpenSSH's parsed artifact without consulting real identities.
with tempfile.TemporaryDirectory(prefix='sw-tunnel-config-') as directory:
    (Path(directory) / 'identity').touch()
    config_args = list(args)
    config_args[config_args.index('-i') + 1] = str(Path(directory) / 'identity')
    config_args = [a.replace('/home/neil/.ssh/known_hosts', str(Path(directory) / 'known_hosts'))
                   for a in config_args]
    config = dict(line.split(' ', 1) for line in subprocess.check_output(
        [*config_args[:1], '-G', *config_args[1:]], text=True).splitlines()
        if not line.startswith('remoteforward '))
for key, value in {
    'batchmode': 'yes', 'stricthostkeychecking': 'true',
    'identityagent': 'none', 'exitonforwardfailure': 'yes',
    'connecttimeout': '10', 'connectionattempts': '1',
    'serveraliveinterval': '15', 'serveralivecountmax': '3',
    'controlmaster': 'false', 'forwardagent': 'no',
    'forkafterauthentication': 'no', 'sessiontype': 'none', 'requesttty': 'false',
}.items():
    assert config[key] == value, (key, config[key])
assert config.get('controlpath', 'none') == 'none'
assert [args[i + 1] for i, a in enumerate(args) if a == '-R'] == [
    '127.0.0.1:18080:127.0.0.1:8080', '127.0.0.1:17890:127.0.0.1:7890']

# Nix build users are locked accounts: sshd cannot authenticate them without PAM.
# Keep the bind-failure probe outside that sandbox; never use host PAM in tests.
if '--config-only' in sys.argv:
    print('Generated unit and OpenSSH configuration valid')
    sys.exit(0)

def reserve():
    s = socket.socket()
    s.bind(('127.0.0.1', 0))
    s.listen()
    return s

with tempfile.TemporaryDirectory(prefix='sw-tunnel-test-') as directory:
    root = Path(directory)
    for name in ['client', 'host']:
        subprocess.run(['ssh-keygen', '-q', '-t', 'ed25519', '-N', '',
                        '-f', str(root / name)], check=True)
    listener = reserve()
    port = listener.getsockname()[1]
    listener.close()
    (root / 'known_hosts').write_text(
        f'[127.0.0.1]:{port} ' + (root / 'host.pub').read_text())
    (root / 'sshd_config').write_text(f'''Port {port}
ListenAddress 127.0.0.1
HostKey {root / 'host'}
PidFile {root / 'pid'}
AuthorizedKeysFile {root / 'client.pub'}
StrictModes no
UsePAM no
PasswordAuthentication no
KbdInteractiveAuthentication no
AllowTcpForwarding remote
GatewayPorts no
''')
    with (root / 'server.log').open('w+') as log:
        sshd = subprocess.check_output(['which', 'sshd'], text=True).strip()
        server = subprocess.Popen([sshd, '-D', '-e', '-f', str(root / 'sshd_config')], stderr=log)
        try:
            for _ in range(100):
                if server.poll() is not None:
                    log.seek(0)
                    raise AssertionError(log.read())
                try:
                    with socket.create_connection(('127.0.0.1', port), timeout=.1):
                        break
                except OSError:
                    time.sleep(.05)
            # Both attempted listeners are owned by this fixture. No live forwards.
            for blocked_index in [0, 1]:
                sockets = [reserve(), reserve()]
                ports = [s.getsockname()[1] for s in sockets]
                sockets[1 - blocked_index].close()
                fixture_args = list(args)
                fixture_args[fixture_args.index('-i') + 1] = str(root / 'client')
                fixture_args = [a.replace('/home/neil/.ssh/known_hosts', str(root / 'known_hosts'))
                                for a in fixture_args]
                for i, a in enumerate(fixture_args):
                    if a == '-R':
                        original = fixture_args[i + 1]
                        index = 0 if ':18080:' in original else 1
                        fixture_args[i + 1] = f'127.0.0.1:{ports[index]}:127.0.0.1:9'
                fixture_args[-1] = f'{pwd.getpwuid(os.getuid()).pw_name}@127.0.0.1'
                fixture_args[-1:-1] = ['-p', str(port)]
                try:
                    result = subprocess.run(fixture_args, capture_output=True, text=True, timeout=15)
                    assert result.returncode == 255, result.stderr
                    assert 'remote port forwarding failed' in result.stderr, result.stderr
                finally:
                    for s in sockets:
                        s.close()
        finally:
            server.terminate()
            server.wait(timeout=5)
print('Generated unit: foreground ownership, bounded reconnect and either-listener bind failure valid')
