#!/usr/bin/env python3
"""Exercise the rendered gateway with test-owned listeners and HTTP upstreams."""
import base64
import hashlib
import http.client
import json
import os
import re
from pathlib import Path
import socket
import shutil
import ssl
import shlex
import subprocess
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = Path(os.environ.get('KOSMOS_REPO_ROOT', Path(__file__).resolve().parent.parent))


def free_port():
    with socket.socket() as listener:
        listener.bind(('127.0.0.1', 0))
        return listener.getsockname()[1]


class Upstream(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *_):
        pass

    def do_GET(self):
        if self.path == '/ws':
            accept = base64.b64encode(hashlib.sha1((self.headers['Sec-WebSocket-Key'] + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()).decode()
            self.send_response(101)
            self.send_header('Upgrade', 'websocket')
            self.send_header('Connection', 'Upgrade')
            self.send_header('Sec-WebSocket-Accept', accept)
            self.end_headers()
            self.wfile.write(b'\x81\x05hello')
            self.wfile.flush()
            self.close_connection = True
            return
        if self.path == '/stream':
            self.send_response(200)
            self.send_header('Content-Type', 'text/event-stream')
            self.send_header('Connection', 'close')
            self.end_headers()
            self.wfile.write(b'data: first\n\n')
            self.wfile.flush()
            time.sleep(0.7)
            self.wfile.write(b'data: second\n\n')
            self.wfile.flush()
            self.close_connection = True
            return
        if self.path == '/large':
            self.send_response(200)
            self.send_header('X-Media', 'x' * (512 * 1024))
            self.send_header('Content-Length', '2')
            self.end_headers()
            self.wfile.write(b'ok')
            return
        if self.path == '/redirect':
            self.send_response(302)
            self.send_header('Location', self.headers.get('X-Forwarded-Proto', 'http') + '://' + self.headers['Host'] + '/target')
            self.send_header('Content-Length', '0')
            self.end_headers()
            return
        body = json.dumps({'target': self.server.target, 'path': self.path, 'host': self.headers['Host'], 'forwarded_host': self.headers.get('X-Forwarded-Host'), 'forwarded_proto': self.headers.get('X-Forwarded-Proto'), 'forwarded_for': self.headers.get('X-Forwarded-For'), 'origin': self.headers.get('Origin')}).encode()
        self.send_response(401 if self.path == '/auth' else 200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)


TLS_CONTEXT = None


class TLSConnection(http.client.HTTPSConnection):
    def connect(self):
        self.sock = self._context.wrap_socket(
            socket.create_connection(('127.0.0.1', self.port), timeout=5,
                                     source_address=self.source_address),
            server_hostname=self.host)


def request(port, host, path='/', tls=False, source='127.0.0.1'):
    client = (TLSConnection(host, port, timeout=5, context=TLS_CONTEXT, source_address=(source, 0))
              if tls else http.client.HTTPConnection('127.0.0.1', port, timeout=5))
    client.request('GET', path, headers={'Host': host, 'X-Forwarded-For': '198.51.100.123', 'X-Forwarded-Proto': 'http', 'Origin': ('https://' if tls else 'http://') + host})
    response = client.getresponse()
    result = response.status, dict(response.getheaders()), response.read()
    client.close()
    return result


def raw_request(port, path, extra='', host='anki.localhost:17480', tls=False):
    client = socket.create_connection(('127.0.0.1', port), timeout=5)
    if tls:
        client = TLS_CONTEXT.wrap_socket(client, server_hostname=host)
    client.sendall(f'GET {path} HTTP/1.1\r\nHost: {host}\r\nConnection: close\r\n{extra}\r\n'.encode())
    return client


def unit_commands(package, overrides):
    # Exec* empty assignments reset earlier commands, including package defaults.
    commands = {name: [] for name in ['ExecStartPre', 'ExecStart', 'ExecReload']}
    section = ''
    for line in (package + '\n' + overrides).splitlines():
        if line.startswith('['):
            section = line
        if section == '[Service]' and '=' in line:
            name, value = line.split('=', 1)
            if name in commands:
                if value.strip():
                    commands[name].append(shlex.split(value))
                else:
                    commands[name] = []
    return commands


with tempfile.TemporaryDirectory(prefix='kosmos-http-test-') as directory:
    work = Path(directory)
    processes = []
    servers = []
    logs = []
    try:
        routes = json.loads((ROOT / 'http/cluster-routes.json').read_text())
        local_routes = {'dev-her': 3082, 'staging-her': 3083, 'prod-lamplit': 3084, 'flickgrove': 4318, 'mihomo-dashboard': 9090}
        fixture_ports = {}
        for target in [*local_routes, *routes]:
            server = ThreadingHTTPServer(('127.0.0.1', 0), Upstream)
            server.daemon_threads = True
            server.target = target
            threading.Thread(target=server.serve_forever, daemon=True).start()
            servers.append(server)
            fixture_ports[target] = server.server_port
        edge_port, ingress_port, health_port, tls_port = [free_port() for _ in range(4)]
        dynamic = {'http': {'routers': {}, 'services': {}}}
        for name, route in routes.items():
            dynamic['http']['services'][name] = {'loadBalancer': {'servers': [{'url': f'http://127.0.0.1:{fixture_ports[name]}'}]}}
            dynamic['http']['routers'][name] = {'entryPoints': ['http'], 'rule': ' || '.join('Host(`' + host + '`)' for host in route['hosts'] + [name + '.nuc.guion.io']), 'service': name}
        (work / 'routes.yaml').write_text(json.dumps(dynamic))
        controller = json.loads(subprocess.check_output(['jsonnet', str(ROOT / 'tanka/lib/traefik.libsonnet')]))
        args = controller['ingressDeployment']['spec']['template']['spec']['containers'][0]['args']
        args = [a for a in args if not a.startswith('--providers.kubernetesingress')]
        args = [a.replace(':17480', f':{ingress_port}').replace(':8082', f':{health_port}').replace('10.42.0.1/32', '127.0.0.1/32') for a in args]
        args += ['--providers.file.filename=' + str(work / 'routes.yaml')]
        # All keys and trust roots belong to this temporary fixture.
        def openssl(*args):
            subprocess.run(['openssl', *args], cwd=work, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        openssl('req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', 'ca.key', '-out', 'ca.pem', '-days', '2', '-subj', '/CN=Fixture CA')
        openssl('req', '-newkey', 'rsa:2048', '-nodes', '-keyout', 'leaf.key', '-out', 'leaf.csr', '-subj', '/CN=*.nuc.guion.io')
        (work / 'extensions').write_text('subjectAltName=DNS:*.nuc.guion.io\nextendedKeyUsage=serverAuth\n')
        openssl('x509', '-req', '-in', 'leaf.csr', '-CA', 'ca.pem', '-CAkey', 'ca.key', '-CAcreateserial', '-out', 'leaf.pem', '-days', '2', '-extfile', 'extensions')
        TLS_CONTEXT = ssl.create_default_context(cafile=str(work / 'ca.pem'))
        vpn = Path(os.environ['KOSMOS_VPN_CADDYFILE']).read_text()
        token_file = work / 'cloudflare-token'
        synthetic_token = 'cfut_' + 'X' * 32
        token_file.write_text(synthetic_token + '\n')
        automated = vpn.replace('/run/agenix/cloudflare-ddns-token', str(token_file))
        (work / 'automated-template').write_text(automated)
        automated_config = Path(os.environ['KOSMOS_CADDYFILE']).read_text().replace('/run/caddy/vpn/*.caddy', str(work / 'automated-template'))
        (work / 'automated-Caddyfile').write_text(automated_config)
        modules = subprocess.check_output(['caddy', 'list-modules'], text=True)
        assert 'dns.providers.cloudflare' in modules.splitlines()
        adapted = subprocess.check_output(['caddy', 'adapt', '--config', str(work / 'automated-Caddyfile'), '--adapter', 'caddyfile'], env=dict(os.environ, XDG_DATA_HOME=str(work / 'data'), XDG_CONFIG_HOME=str(work / 'config')))
        assert synthetic_token.encode() not in adapted
        adapted_config = json.loads(adapted)
        servers_config = adapted_config['apps']['http']['servers']
        assert {a for server in servers_config.values() for a in server['listen']} == {'127.0.0.1:17480', '10.80.12.4:443'}
        assert all(server['automatic_https'].get('disable_redirects') for server in servers_config.values())
        policies = adapted_config['apps']['tls']['automation']['policies']
        assert len(policies) == 1
        policy = policies[0]
        assert policy['subjects'] == ['*.nuc.guion.io']
        issuer = policy['issuers'][0]
        assert issuer['module'] == 'acme' and issuer['ca'] == 'https://acme-v02.api.letsencrypt.org/directory'
        assert issuer['challenges']['http']['disabled'] and issuer['challenges']['tls-alpn']['disabled']
        assert issuer['challenges']['dns']['provider'] == {'name': 'cloudflare', 'api_token': '{file.' + str(token_file) + '}'}
        assert issuer['challenges']['dns']['resolvers'] == ['1.1.1.1:53', '8.8.8.8:53']
        assert issuer['acme_timeout'] == 120000000000
        # Provision/validate the real issuer without Start or any issuance request.
        validation_env = dict(os.environ, XDG_DATA_HOME=str(work / 'data'), XDG_CONFIG_HOME=str(work / 'config'))
        validation = subprocess.run(['caddy', 'validate', '--config', str(work / 'automated-Caddyfile'), '--adapter', 'caddyfile'], env=validation_env, capture_output=True, text=True)
        assert validation.returncode == 0, validation.stderr
        token_file.write_text('SYNTHETIC-malformed-secret')
        validation = subprocess.run(['caddy', 'validate', '--config', str(work / 'automated-Caddyfile'), '--adapter', 'caddyfile'], env=validation_env, capture_output=True, text=True)
        assert validation.returncode != 0 and 'SYNTHETIC-malformed-secret' not in validation.stdout + validation.stderr
        assert 'Cloudflare API token format is invalid' in validation.stderr
        token_file.write_text(synthetic_token + '\n')
        # Route/lifecycle fixture uses a test-owned leaf, never real ACME/Cloudflare.
        vpn = re.sub(r'(?ms)^([ \t]*)tls \{\n.*?^\1\}\n', lambda m: m[1] + f'tls {work / "leaf.pem"} {work / "leaf.key"}\n', vpn, count=1)
        vpn = vpn.replace('https://*.nuc.guion.io:443', f'https://*.nuc.guion.io:{tls_port}').replace('bind 10.80.12.4', 'bind 127.0.0.1')
        vpn = vpn.replace('10.80.12.0/24', '127.0.0.1/32').replace('10.42.0.0/16', '127.0.0.3/32')
        vpn = vpn.replace('127.0.0.1:27480', f'127.0.0.1:{ingress_port}')
        for name, port in local_routes.items():
            vpn = vpn.replace(f'127.0.0.1:{port}', f'127.0.0.1:{fixture_ports[name]}')
        (work / 'vpn-template').write_text(vpn)
        # Only this test's fake ip executable is used; no live interfaces change.
        (work / 'ip').write_text('#!' + shutil.which('bash') + '\nprintf "2: tun0 inet %s scope global tun0\\n" "${TEST_VPN_ADDRESS:-10.80.12.4/24}"\n')
        (work / 'ip').chmod(0o700)
        prep_env = dict(os.environ, PATH=str(work) + os.pathsep + os.environ['PATH'], XDG_DATA_HOME=str(work / 'data'), XDG_CONFIG_HOME=str(work / 'config'))
        def prepare(credential='cloudflare-token', address='10.80.12.4/24'):
            result = subprocess.run(['bash', str(ROOT / 'scripts/prepare-vpn-https'), str(work / credential), str(work / 'vpn-template'), str(work / 'vpn/https.caddy')], env=dict(prep_env, TEST_VPN_ADDRESS=address), capture_output=True, text=True)
            assert result.returncode == 0, result.stderr
            assert synthetic_token not in result.stdout + result.stderr
            return (work / 'vpn/https.caddy').exists(), result.stderr
        assert not prepare(credential='missing-token')[0]
        token_file.chmod(0o000)
        assert not prepare()[0]
        token_file.chmod(0o600)
        assert not prepare(address='10.80.12.99/24')[0]
        for invalid in ['SYNTHETIC-malformed-secret', synthetic_token + '\n\n', synthetic_token + '\nextra']:
            token_file.write_text(invalid)
            enabled, diagnostics = prepare()
            assert not enabled and invalid not in diagnostics
        token_file.write_text(synthetic_token + '\r\n')
        assert prepare()[0]
        token_file.write_text(synthetic_token + '\n')
        config = Path(os.environ['KOSMOS_CADDYFILE']).read_text()
        config = config.replace('/run/caddy/vpn/*.caddy', str(work / 'vpn/*.caddy'))
        config = config.replace('unix//run/caddy/admin.sock', 'unix/' + str(work / 'admin.sock'))
        config = config.replace('http://:17480', f'http://:{edge_port}').replace('127.0.0.1:27480', f'127.0.0.1:{ingress_port}')
        for name, port in local_routes.items():
            config = config.replace(f'127.0.0.1:{port}', f'127.0.0.1:{fixture_ports[name]}')
        (work / 'Caddyfile').write_text(config)
        env = dict(os.environ, XDG_DATA_HOME=str(work / 'data'), XDG_CONFIG_HOME=str(work / 'config'))
        units = Path(os.environ['KOSMOS_CADDY_UNIT_DIR'])
        package_unit = (units / 'package.service').read_text()
        native = unit_commands(package_unit, (units / 'present.conf').read_text())
        absent = unit_commands(package_unit, (units / 'absent.conf').read_text())
        assert len(native['ExecStartPre']) == 1 and len(native['ExecStart']) == 1
        assert len(native['ExecReload']) == 2, native
        assert native['ExecReload'][0] == native['ExecStartPre'][0], native
        assert native['ExecReload'][1][1] == 'reload' and native['ExecStart'][0][1] == 'run'
        assert len(absent['ExecReload']) == 2 and absent['ExecReload'][0][1:] == ['-f', '/run/caddy/vpn/https.caddy']
        for command in [native['ExecStart'][0], native['ExecReload'][1]]:
            assert command[command.index('--adapter') + 1] == 'caddyfile'
            assert command[command.index('--config') + 1] == '/etc/caddy/caddy_config'
        def fixture_command(command):
            if command == native['ExecStartPre'][0]:
                # Same script body, with test-owned material/interface injection.
                # The Nix wrapper's iproute2 PATH would otherwise read real tun0.
                assert command[1] == '/run/agenix/cloudflare-ddns-token'
                return ['bash', str(ROOT / 'scripts/prepare-vpn-https'), str(token_file), str(work / 'vpn-template'), str(work / 'vpn/https.caddy')]
            return [a.replace('/etc/caddy/caddy_config', str(work / 'Caddyfile')).replace('/run/caddy/vpn/https.caddy', str(work / 'vpn/https.caddy')) for a in command]
        def native_reload(commands=native, address='10.80.12.4/24'):
            for command in commands['ExecReload']:
                subprocess.run(fixture_command(command), env=dict(prep_env, TEST_VPN_ADDRESS=address), check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        token_file.rename(work / 'unprovisioned-token')
        for command in native['ExecStartPre']:
            subprocess.run(fixture_command(command), env=prep_env, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        assert not (work / 'vpn/https.caddy').exists()
        for command in [[os.environ.get('TRAEFIK_BIN', 'traefik'), *args], fixture_command(native['ExecStart'][0])]:
            log = (work / f'log-{len(logs)}').open('w+')
            logs.append(log)
            processes.append(subprocess.Popen(command, stdout=log, stderr=log, env=env, cwd=work))
        for port in [edge_port, health_port]:
            for _ in range(100):
                assert all(p.poll() is None for p in processes), 'gateway exited during startup'
                try:
                    request(port, 'unknown.localhost')
                    break
                except (OSError, http.client.HTTPException):
                    time.sleep(0.05)
            else:
                raise AssertionError('gateway did not become ready')
        for _ in range(100):
            if request(edge_port, 'anki.localhost')[0] == 200:
                break
            time.sleep(0.05)
        else:
            raise AssertionError('Traefik did not load fixture routes')
        # Caddy started with missing credential and still serves the old path.
        assert request(edge_port, 'dev-her.localhost')[0] == 200
        (work / 'unprovisioned-token').rename(token_file)
        native_reload()
        assert request(tls_port, 'dev-her.nuc.guion.io', tls=True)[0] == 200
        token_file.write_text('SYNTHETIC-malformed-secret')
        native_reload()
        assert not (work / 'vpn/https.caddy').exists()
        assert request(edge_port, 'dev-her.localhost')[0] == 200
        try:
            request(tls_port, 'dev-her.nuc.guion.io', tls=True)
            raise AssertionError('Invalid credential kept HTTPS active')
        except OSError:
            pass
        token_file.write_text(synthetic_token + '\n')
        native_reload()
        token_file.rename(work / 'unprovisioned-token')
        native_reload()
        assert not (work / 'vpn/https.caddy').exists()
        assert request(edge_port, 'dev-her.localhost')[0] == 200
        (work / 'unprovisioned-token').rename(token_file)
        native_reload()
        native_reload(address='10.80.12.99/24')
        assert not (work / 'vpn/https.caddy').exists()
        assert request(edge_port, 'dev-her.localhost')[0] == 200
        native_reload()
        # Removing declarations uses the evaluated native absent-credential remover.
        native_reload(absent)
        assert not (work / 'vpn/https.caddy').exists()
        assert request(edge_port, 'dev-her.localhost')[0] == 200
        native_reload()
        local_hosts = list(local_routes)
        for host, target in [(h + '.localhost', h) for h in local_hosts] + [(h, name) for name, r in routes.items() for h in r['hosts']]:
            for authority_port in [17480, 17481]:
                authority = f'{host}:{authority_port}'
                status, _, body = request(edge_port, authority, '/a%2Fb?x=one%3Btwo&y=three')
                data = json.loads(body)
                assert status == 200 and data['target'] == target, (authority, status, data)
                assert data['path'] == '/a%2Fb?x=one%3Btwo&y=three'
                assert data['host'] == authority and data['forwarded_host'] == authority
                assert data['forwarded_proto'] == 'http'
                assert '198.51.100.123' not in data['forwarded_for']
                assert request(edge_port, authority, '/redirect')[1]['Location'] == f'http://{authority}/target'
                assert request(edge_port, authority, '/auth')[0] == 401
        for host, target in [(h + '.nuc.guion.io', h) for h in local_hosts] + [(h + '.nuc.guion.io', h) for h in routes]:
            status, _, body = request(tls_port, host, '/a%2Fb?x=one%3Btwo&y=three', tls=True)
            data = json.loads(body)
            assert status == 200 and data['target'] == target, (host, status, data)
            assert data['path'] == '/a%2Fb?x=one%3Btwo&y=three'
            assert data['host'] == data['forwarded_host'] == host
            assert data['forwarded_proto'] == 'https' and data['origin'] == 'https://' + host
            assert request(tls_port, host, '/redirect', tls=True)[1]['Location'] == f'https://{host}/target'
            assert request(tls_port, host, '/auth', tls=True)[0] == 401
        assert request(tls_port, 'unknown.nuc.guion.io', tls=True)[::2] == (421, b'unknown host')
        assert request(tls_port, 'anki.nuc.guion.io', tls=True, source='127.0.0.2')[0] == 403
        assert request(tls_port, 'ente-storage.nuc.guion.io', tls=True, source='127.0.0.3')[0] == 200
        assert request(tls_port, 'ente.nuc.guion.io', tls=True, source='127.0.0.3')[0] == 403
        try:
            request(tls_port, 'outside.invalid', tls=True)
            raise AssertionError('TLS hostname mismatch was accepted')
        except ssl.SSLError:
            pass
        trusted_context = TLS_CONTEXT
        TLS_CONTEXT = ssl.create_default_context()
        try:
            request(tls_port, 'anki.nuc.guion.io', tls=True)
            raise AssertionError('Untrusted fixture CA was accepted')
        except ssl.SSLError:
            pass
        finally:
            TLS_CONTEXT = trusted_context
        assert request(edge_port, 'unknown.localhost')[::2] == (421, b'unknown host')
        with raw_request(edge_port, '/large') as client:
            chunks = []
            while chunk := client.recv(65536):
                chunks.append(chunk)
            response = b''.join(chunks)
            assert response.startswith(b'HTTP/1.1 200') and b'x' * (512 * 1024) in response and response.endswith(b'ok')
        for stream_host in ['prod-lamplit.nuc.guion.io', 'anki.nuc.guion.io']:
            with raw_request(tls_port, '/stream', host=stream_host, tls=True) as client:
                received = b''
                start = time.monotonic()
                while b'data: first' not in received:
                    chunk = client.recv(4096)
                    assert chunk, received
                    received += chunk
                assert time.monotonic() - start < 0.6 and b'data: second' not in received, 'SSE was buffered'
                while b'data: second' not in received:
                    chunk = client.recv(4096)
                    assert chunk, received
                    received += chunk
            with raw_request(tls_port, '/ws', 'Upgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n', host=stream_host, tls=True) as client:
                response = b''
                while b'hello' not in response:
                    chunk = client.recv(4096)
                    assert chunk, response
                    response += chunk
                assert response.startswith(b'HTTP/1.1 101') and b'\x81\x05hello' in response
        print('19 HTTPS and preserved HTTP routes, trusted TLS, source restrictions, native start/reload preparation, wildcard DNS-01 issuer, runtime-only credential, redacted malformed-token failure, missing-input preflight, authorities, encoded URLs, authentication, redirects, large headers, SSE and WebSocket pass')
    except Exception:
        for log in logs:
            log.flush()
            log.seek(0)
            print(log.read(), file=__import__('sys').stderr)
        raise
    finally:
        for process in processes:
            process.terminate()
        for process in processes:
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        for server in servers:
            server.shutdown()
            server.server_close()
        for log in logs:
            log.close()
