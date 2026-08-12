#!/usr/bin/env bun

import {
  chmodSync,
  copyFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
  renameSync,
  writeFileSync,
} from "node:fs";
import { dirname } from "node:path";

type JsonObject = Record<string, unknown>;
type Direction = "codex-to-pi" | "pi-to-codex";

const home = process.env.HOME;

if (!home) {
  fail("HOME is not set");
}

const codexAuth = process.env.CODEX_AUTH ?? `${home}/.codex/auth.json`;
const piAuth = process.env.PI_AUTH ?? `${home}/.pi/agent/auth.json`;
const syncState = process.env.SYNC_STATE ?? `${home}/.pi/codex-sync.json`;
let backupEnabled = true;

function fail(message: string): never {
  console.error(`Error: ${message}`);
  process.exit(1);
}

function isObject(value: unknown): value is JsonObject {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function readObject(file: string): JsonObject {
  let value: unknown;

  try {
    value = JSON.parse(readFileSync(file, "utf8"));
  } catch {
    fail(`could not parse JSON in ${file}`);
  }

  if (!isObject(value)) {
    fail(`expected a JSON object in ${file}`);
  }

  return value;
}

function requiredString(value: unknown, description: string): string {
  if (typeof value !== "string" || value.length === 0) {
    fail(`no ${description}`);
  }

  return value;
}

function optionalString(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function backup(file: string): void {
  if (!backupEnabled || !existsSync(file)) {
    return;
  }

  const destination = `${file}.bak.${Date.now()}`;
  copyFileSync(file, destination);
  console.log(`Backed up ${file} -> ${destination}`);
}

function writeObject(file: string, value: JsonObject): void {
  mkdirSync(dirname(file), { recursive: true });

  const temporary = `${file}.tmp-${process.pid}-${crypto.randomUUID()}`;
  writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
  chmodSync(temporary, 0o600);
  renameSync(temporary, file);
  chmodSync(file, 0o600);
}

function expiryFromIdToken(idToken: string): number | undefined {
  const payload = idToken.split(".")[1];

  if (!payload) {
    return undefined;
  }

  try {
    const decoded = JSON.parse(Buffer.from(payload, "base64url").toString("utf8"));

    if (!isObject(decoded) || typeof decoded.exp !== "number" || !Number.isFinite(decoded.exp)) {
      return undefined;
    }

    return decoded.exp * 1000;
  } catch {
    return undefined;
  }
}

function writeIdTokenState(idToken: string): void {
  backup(syncState);
  writeObject(syncState, { "openai-codex": { idToken } });
}

function readIdTokenState(): string | undefined {
  if (!existsSync(syncState)) {
    return undefined;
  }

  const provider = readObject(syncState)["openai-codex"];
  return isObject(provider) && typeof provider.idToken === "string" && provider.idToken.length > 0
    ? provider.idToken
    : undefined;
}

function codexToPi(): void {
  if (!existsSync(codexAuth)) {
    fail(`${codexAuth} not found`);
  }

  const codex = readObject(codexAuth);
  const tokens = codex.tokens;

  if (!isObject(tokens)) {
    fail(`no tokens object in ${codexAuth}`);
  }

  const access = requiredString(tokens.access_token, `access_token in ${codexAuth}`);
  const refresh = requiredString(tokens.refresh_token, `refresh_token in ${codexAuth}`);
  const idToken = requiredString(tokens.id_token, `id_token in ${codexAuth}; pi-to-codex needs it`);
  const accountId = optionalString(tokens.account_id);
  const decodedExpiry = expiryFromIdToken(idToken);
  const expires = decodedExpiry ?? Date.now() + 60 * 60 * 1000;

  if (decodedExpiry === undefined) {
    console.warn("Warning: could not decode id_token exp, using 1 hour from now");
  }

  const pi = existsSync(piAuth) ? readObject(piAuth) : {};
  pi["openai-codex"] = {
    type: "oauth",
    access,
    refresh,
    expires,
    accountId,
  };

  backup(piAuth);
  writeObject(piAuth, pi);
  writeIdTokenState(idToken);
  console.log("Synced Codex -> Pi");
  console.log(`  source: ${codexAuth}`);
  console.log(`  target: ${piAuth}`);
  console.log(`  id_token state: ${syncState}`);
  console.log(`  account: ${accountId}`);
  console.log(`  expires: ${new Date(expires).toISOString()}`);
}

function piToCodex(): void {
  if (!existsSync(piAuth)) {
    fail(`${piAuth} not found`);
  }

  const pi = readObject(piAuth);
  const entry = pi["openai-codex"];

  if (!isObject(entry)) {
    fail(`no openai-codex credential in ${piAuth}`);
  }

  const access = requiredString(entry.access, "access token in pi credential");
  const refresh = requiredString(entry.refresh, "refresh token in pi credential");
  const accountId = optionalString(entry.accountId);
  const idToken = readIdTokenState();

  if (!idToken) {
    fail(`id_token not found in ${syncState}; run 'codex-to-pi' first to seed it`);
  }

  backup(codexAuth);
  writeObject(codexAuth, {
    auth_mode: "chatgpt",
    OPENAI_API_KEY: null,
    tokens: {
      id_token: idToken,
      access_token: access,
      refresh_token: refresh,
      account_id: accountId,
    },
    last_refresh: new Date().toISOString(),
  });
  console.log("Synced Pi -> Codex");
  console.log(`  source: ${piAuth}`);
  console.log(`  target: ${codexAuth}`);
  console.log(`  id_token from: ${syncState}`);
  console.log(`  account: ${accountId}`);
}

function usage(exitCode: number): never {
  console.log(`Usage: sync-codex-auth.ts <direction> [--no-backup]

  codex-to-pi    Convert ~/.codex/auth.json -> ~/.pi/agent/auth.json
  pi-to-codex    Convert ~/.pi/agent/auth.json -> ~/.codex/auth.json

The id_token is stored in a separate state file (default ~/.pi/codex-sync.json)
rather than pi's auth.json. Pi's OAuth refresh rewrites auth.json credentials
to only {type, access, refresh, expires, accountId} and drops unknown fields,
so an idToken inside auth.json would be erased on the first pi-side refresh.

Options:
  --no-backup     Skip backing up the target file before overwriting
  --backup        Force backup (default)

Environment:
  CODEX_AUTH      Path to Codex auth.json (default: ~/.codex/auth.json)
  PI_AUTH         Path to Pi auth.json (default: ~/.pi/agent/auth.json)
  SYNC_STATE      Path to id_token state file (default: ~/.pi/codex-sync.json)`);
  process.exit(exitCode);
}

let direction: Direction | undefined;

for (const argument of process.argv.slice(2)) {
  switch (argument) {
    case "codex-to-pi":
    case "pi-to-codex":
      direction = argument;
      break;
    case "--no-backup":
      backupEnabled = false;
      break;
    case "--backup":
      backupEnabled = true;
      break;
    case "-h":
    case "--help":
      usage(0);
      break;
    default:
      console.error(`Unknown option: ${argument}`);
      usage(1);
  }
}

if (!direction) {
  usage(1);
}

if (direction === "codex-to-pi") {
  codexToPi();
} else {
  piToCodex();
}
