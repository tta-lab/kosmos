#!/usr/bin/env node
// systemd parses each EnvironmentFile in a separate oneshot input unit.
import fs from 'node:fs';
import path from 'node:path';
const [action, directory, ...args] = process.argv.slice(2);
const names = ['webhooks.json', 'shio.json', 'serein.json'];
const limit = 1048576;
const credential = value => typeof value === 'string' && value.length <= 16384 && /^[\x21-\x7e]+$/.test(value);
const userId = value => typeof value === 'string' && value.length <= 255 && /^@[^\s:]+:[^\s]+$/u.test(value);
function endpoint(value, webhook = false) {
  const u = new URL(value);
  if (u.username || u.password || u.hash || !['https:', 'http:'].includes(u.protocol) ||
      (webhook && u.protocol === 'http:' && !['localhost', '127.0.0.1', '[::1]'].includes(u.hostname))) throw Error();
  return u.toString();
}
function root() {
  if (!path.isAbsolute(directory) || fs.realpathSync(directory) !== directory) throw Error();
  const s = fs.lstatSync(directory);
  if (!s.isDirectory() || s.uid !== process.getuid() || (s.mode & 0o777) !== 0o700) throw Error();
}
function check(name) {
  try {
    const s = fs.lstatSync(path.join(directory, name));
    if (!s.isFile() || s.uid !== process.getuid() || s.nlink !== 1 || (s.mode & 0o777) !== 0o600) throw Error();
    return true;
  } catch (error) { if (error.code === 'ENOENT') return false; throw error; }
}
function remove(name) { if (check(name)) fs.unlinkSync(path.join(directory, name)); }
function read(name) {
  check(name);
  const fd = fs.openSync(path.join(directory, name), fs.constants.O_RDONLY | fs.constants.O_NOFOLLOW);
  try {
    if (fs.fstatSync(fd).size > limit) throw Error();
    return JSON.parse(fs.readFileSync(fd, 'utf8'));
  } finally { fs.closeSync(fd); }
}
function write(name, value) {
  check(name);
  const data = JSON.stringify(value);
  if (Buffer.byteLength(data) > limit) throw Error();
  // Exclusive temporary file in the verified private directory; no shared temp path.
  const tmp = `${name}.${process.pid}.tmp`;
  const fd = fs.openSync(path.join(directory, tmp), fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_EXCL | fs.constants.O_NOFOLLOW, 0o600);
  try {
    fs.writeFileSync(fd, data); fs.fsyncSync(fd);
    fs.closeSync(fd);
    fs.renameSync(path.join(directory, tmp), path.join(directory, name));
  } catch (error) {
    try { fs.closeSync(fd); } catch {}
    fs.unlinkSync(path.join(directory, tmp)); throw error;
  }
}
async function identity(kind) {
  if (!['shio', 'serein'].includes(kind)) throw Error();
  const token = process.env.MATRIX_ACCESS_TOKEN;
  if (!credential(token)) throw Error();
  const home = endpoint(process.env.MATRIX_HOMESERVER_URL).replace(/\/+$/, '');
  const response = await fetch(`${home}/_matrix/client/v3/account/whoami`, {
    headers: {Authorization: `Bearer ${token}`}, redirect: 'error', signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) throw Error();
  const chunks = []; let bytes = 0;
  for await (const chunk of response.body) {
    bytes += chunk.length;
    if (bytes > limit) throw Error();
    chunks.push(chunk);
  }
  const id = JSON.parse(new TextDecoder('utf-8', {fatal: true}).decode(Buffer.concat(chunks))).user_id;
  if (!userId(id)) throw Error();
  const url = kind === 'shio' ? 'http://127.0.0.1:3084/api/matrix/events' : process.env.MATRIX_WEBHOOK_URL;
  const bearer = kind === 'serein' ? process.env.MATRIX_WEBHOOK_BEARER_TOKEN : undefined;
  if (bearer !== undefined && !credential(bearer)) throw Error();
  const entry = {user_id: id, access_token: token};
  if (url !== undefined) {
    entry.url = endpoint(url, true);
    if (bearer !== undefined) entry.bearer_token = bearer;
  }
  write(`${kind}.json`, {home, entry});
}
try {
  root();
  if (action === 'init') {
    for (const name of names) remove(name);
    fs.accessSync(args[0], fs.constants.R_OK);
    if (!fs.statSync(args[0]).isFile()) throw Error();
  } else if (action === 'prepare') {
    if (!['shio', 'serein'].includes(args[0])) throw Error();
    remove(`${args[0]}.json`);
    await identity(args[0]);
  } else if (action === 'run') {
    const [node, artifact, ...kinds] = args;
    remove('webhooks.json');
    if (!kinds.length || new Set(kinds).size !== kinds.length || kinds.some(k => !['shio', 'serein'].includes(k))) throw Error();
    const inputs = kinds.map(k => read(`${k}.json`));
    const homes = new Set(inputs.map(i => i.home));
    const users = new Set(inputs.map(i => i.entry.user_id));
    const tokens = new Set(inputs.map(i => i.entry.access_token));
    if (homes.size !== 1 || users.size !== inputs.length || tokens.size !== inputs.length) throw Error();
    write('webhooks.json', inputs.filter(i => i.entry.url).map(i => i.entry));
    for (const kind of kinds) remove(`${kind}.json`);
    const env = Object.fromEntries(Object.entries(process.env).filter(([key]) => !key.startsWith('MATRIX_')));
    Object.assign(env, {MATRIX_HOMESERVER_URL: inputs[0].home, MATRIX_MCP_LISTEN: '127.0.0.1:8768', MATRIX_WEBHOOK_CONFIG: path.join(directory, 'webhooks.json')});
    process.execve(node, [node, artifact], env);
  } else throw Error();
} catch {
  // Never surface upstream bodies, environment values, URLs or fs error paths.
  try { root(); for (const name of names) remove(name); } catch {}
  console.error('Matrix runtime preparation failed (inputs, private paths or artifact unavailable)');
  process.exitCode = 1;
}
