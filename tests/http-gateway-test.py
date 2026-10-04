#!/usr/bin/env python3
"""Exercise the rendered gateway with test-owned listeners and HTTP upstreams."""
import base64
import hashlib
import http.client
import json
import os
from pathlib import Path
import re
import socket
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
            self.send_header('Location', 'http://' + self.headers['Host'] + '/target')
            self.send_header('Content-Length', '0')
            self.end_headers()
            return
        body = json.dumps({'target': self.server.target, 'path': self.path, 'host': self.headers['Host'], 'forwarded_host': self.headers.get('X-Forwarded-Host'), 'forwarded_proto': self.headers.get('X-Forwarded-Proto'), 'forwarded_for': self.headers.get('X-Forwarded-For')}).encode()
        self.send_response(401 if self.path == '/auth' else 200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def request(port, host, path='/'):
    client = http.client.HTTPConnection('127.0.0.1', port, timeout=5)
    client.request('GET', path, headers={'Host': host, 'X-Forwarded-For': '198.51.100.123'})
    response = client.getresponse()
    result = response.status, dict(response.getheaders()), response.read()
    client.close()
    return result


def raw_request(port, path, extra=''):
    client = socket.create_connection(('127.0.0.1', port), timeout=5)
    client.sendall(f'GET {path} HTTP/1.1\r\nHost: anki.localhost:17480\r\nConnection: close\r\n{extra}\r\n'.encode())
    return client


with tempfile.TemporaryDirectory(prefix='kosmos-http-test-') as directory:
    work = Path(directory)
    processes = []
    servers = []
    logs = []
    try:
        for target in ['local', 'cluster']:
            server = ThreadingHTTPServer(('127.0.0.1', 0), Upstream)
            server.daemon_threads = True
            server.target = target
            threading.Thread(target=server.serve_forever, daemon=True).start()
            servers.append(server)
        local_port, upstream_port = [s.server_port for s in servers]
        edge_port, ingress_port, health_port = [free_port() for _ in range(3)]
        routes = json.loads((ROOT / 'http/cluster-routes.json').read_text())
        dynamic = {'http': {'routers': {}, 'services': {'fixture': {'loadBalancer': {'servers': [{'url': f'http://127.0.0.1:{upstream_port}'}]}}}}}
        for name, route in routes.items():
            dynamic['http']['routers'][name] = {'entryPoints': ['http'], 'rule': ' || '.join('Host(`' + host + '`)' for host in route['hosts']), 'service': 'fixture'}
        (work / 'routes.yaml').write_text(json.dumps(dynamic))
        controller = json.loads(subprocess.check_output(['jsonnet', str(ROOT / 'tanka/lib/traefik.libsonnet')]))
        args = controller['ingressDeployment']['spec']['template']['spec']['containers'][0]['args']
        args = [a for a in args if not a.startswith('--providers.kubernetesingress')]
        args = [a.replace(':17480', f':{ingress_port}').replace(':8082', f':{health_port}').replace('10.42.0.1/32', '127.0.0.1/32') for a in args]
        args += ['--providers.file.filename=' + str(work / 'routes.yaml')]
        config = Path(os.environ['KOSMOS_CADDYFILE']).read_text()
        config = config.replace('unix//run/caddy/admin.sock', 'unix/' + str(work / 'admin.sock'))
        config = config.replace('http://:17480', f'http://:{edge_port}').replace('127.0.0.1:27480', f'127.0.0.1:{ingress_port}')
        config = re.sub(r'127\.0\.0\.1:(3082|3083|3084|4318|9090)\b', f'127.0.0.1:{local_port}', config)
        (work / 'Caddyfile').write_text(config)
        env = dict(os.environ, XDG_DATA_HOME=str(work / 'data'), XDG_CONFIG_HOME=str(work / 'config'))
        for command in [[os.environ.get('TRAEFIK_BIN', 'traefik'), *args], ['caddy', 'run', '--config', str(work / 'Caddyfile'), '--adapter', 'caddyfile']]:
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
        local_hosts = ['dev-her', 'staging-her', 'prod-lamplit', 'flickgrove', 'mihomo-dashboard']
        for host, target in [(h + '.localhost', 'local') for h in local_hosts] + [(h, 'cluster') for r in routes.values() for h in r['hosts']]:
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
        assert request(edge_port, 'unknown.localhost')[::2] == (421, b'unknown host')
        with raw_request(edge_port, '/large') as client:
            chunks = []
            while chunk := client.recv(65536):
                chunks.append(chunk)
            response = b''.join(chunks)
            assert response.startswith(b'HTTP/1.1 200') and b'x' * (512 * 1024) in response and response.endswith(b'ok')
        with raw_request(edge_port, '/stream') as client:
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
        with raw_request(edge_port, '/ws', 'Upgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n') as client:
            response = b''
            while b'hello' not in response:
                chunk = client.recv(4096)
                assert chunk, response
                response += chunk
            assert response.startswith(b'HTTP/1.1 101') and b'\x81\x05hello' in response
        print('HTTP routes, authorities, encoded URLs, authentication, redirects, large headers, SSE and WebSocket pass')
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
