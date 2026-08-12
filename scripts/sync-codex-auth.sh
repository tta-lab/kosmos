#!/usr/bin/env bash
set -euo pipefail

CODEX_AUTH="${CODEX_AUTH:-$HOME/.codex/auth.json}"
PI_AUTH="${PI_AUTH:-$HOME/.pi/agent/auth.json}"
# id_token lives in its own state file, NOT in pi's auth.json: pi's OAuth
# refresh rewrites the credential to only {type, access, refresh, expires,
# accountId} and drops unknown fields, so an idToken inside auth.json would
# vanish on the first pi-side refresh. This file is outside pi's agent dir,
# so pi never writes or migrates it.
SYNC_STATE="${SYNC_STATE:-$HOME/.pi/codex-sync.json}"
BACKUP=true

backup() {
  local file="$1"
  if [ "$BACKUP" = true ] && [ -f "$file" ]; then
    cp "$file" "${file}.bak.$(date +%s)"
    echo "Backed up $file -> ${file}.bak"
  fi
}

write_id_token_state() {
  local id_token="$1"
  backup "$SYNC_STATE"
  mkdir -p "$(dirname "$SYNC_STATE")"
  jq -n --arg idToken "$id_token" '{"openai-codex": {idToken: $idToken}}' > "${SYNC_STATE}.tmp"
  mv "${SYNC_STATE}.tmp" "$SYNC_STATE"
  chmod 600 "$SYNC_STATE"
}

read_id_token_state() {
  if [ -f "$SYNC_STATE" ]; then
    jq -r '."openai-codex".idToken // empty' "$SYNC_STATE" 2>/dev/null
  fi
}

codex_to_pi() {
  if [ ! -f "$CODEX_AUTH" ]; then
    echo "Error: $CODEX_AUTH not found"
    exit 1
  fi

  local access refresh account_id id_token
  access=$(jq -r '.tokens.access_token' "$CODEX_AUTH")
  refresh=$(jq -r '.tokens.refresh_token' "$CODEX_AUTH")
  account_id=$(jq -r '.tokens.account_id // empty' "$CODEX_AUTH")
  id_token=$(jq -r '.tokens.id_token // empty' "$CODEX_AUTH")

  if [ -z "$access" ] || [ "$access" = "null" ]; then
    echo "Error: no access_token in $CODEX_AUTH"
    exit 1
  fi
  if [ -z "$id_token" ] || [ "$id_token" = "null" ]; then
    echo "Error: no id_token in $CODEX_AUTH; pi-to-codex needs it"
    exit 1
  fi

  # Derive expires from id_token JWT exp claim (seconds -> milliseconds)
  local exp_sec expires
  exp_sec=$(echo "$id_token" | cut -d. -f2 | base64 -d 2>/dev/null | jq -r '.exp // empty' 2>/dev/null)
  if [ -z "$exp_sec" ] || [ "$exp_sec" = "null" ]; then
    echo "Warning: could not decode id_token exp, using 1 hour from now"
    exp_sec=$(( $(date +%s) + 3600 ))
  fi
  expires=$(( exp_sec * 1000 ))

  # pi's refresh drops unknown credential fields, so do NOT write idToken
  # into auth.json; keep it in the sync state file instead.
  local new_entry
  new_entry=$(jq -n \
    --arg access "$access" \
    --arg refresh "$refresh" \
    --arg accountId "$account_id" \
    --argjson expires "$expires" \
    '{type:"oauth",access:$access,refresh:$refresh,expires:$expires,accountId:$accountId}')

  backup "$PI_AUTH"

  if [ -f "$PI_AUTH" ]; then
    jq --argjson entry "$new_entry" '.["openai-codex"] = $entry' "$PI_AUTH" > "${PI_AUTH}.tmp"
  else
    mkdir -p "$(dirname "$PI_AUTH")"
    jq -n --argjson entry "$new_entry" '{"openai-codex": $entry}' > "${PI_AUTH}.tmp"
  fi

  mv "${PI_AUTH}.tmp" "$PI_AUTH"
  chmod 600 "$PI_AUTH"
  write_id_token_state "$id_token"
  echo "Synced Codex -> Pi"
  echo "  source: $CODEX_AUTH"
  echo "  target: $PI_AUTH"
  echo "  id_token state: $SYNC_STATE"
  echo "  account: $account_id"
  echo "  expires: $(date -d @$(( expires / 1000 )) '+%Y-%m-%d %H:%M:%S')"
}

pi_to_codex() {
  if [ ! -f "$PI_AUTH" ]; then
    echo "Error: $PI_AUTH not found"
    exit 1
  fi

  local entry
  entry=$(jq '.["openai-codex"]' "$PI_AUTH")
  if [ "$entry" = "null" ]; then
    echo "Error: no openai-codex credential in $PI_AUTH"
    exit 1
  fi

  local access refresh account_id id_token
  access=$(echo "$entry" | jq -r '.access')
  refresh=$(echo "$entry" | jq -r '.refresh')
  account_id=$(echo "$entry" | jq -r '.accountId // empty')
  id_token=$(read_id_token_state)

  if [ -z "$access" ] || [ "$access" = "null" ]; then
    echo "Error: no access token in pi credential"
    exit 1
  fi
  if [ -z "$id_token" ] || [ "$id_token" = "null" ]; then
    echo "Error: id_token not found in $SYNC_STATE"
    echo "       run 'codex-to-pi' first to seed it"
    exit 1
  fi

  local last_refresh
  last_refresh=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  backup "$CODEX_AUTH"

  mkdir -p "$(dirname "$CODEX_AUTH")"
  jq -n \
    --arg access "$access" \
    --arg refresh "$refresh" \
    --arg account_id "$account_id" \
    --arg id_token "$id_token" \
    --arg last_refresh "$last_refresh" \
    '{
      auth_mode: "chatgpt",
      OPENAI_API_KEY: null,
      tokens: {
        id_token: $id_token,
        access_token: $access,
        refresh_token: $refresh,
        account_id: $account_id
      },
      last_refresh: $last_refresh
    }' > "${CODEX_AUTH}.tmp"

  mv "${CODEX_AUTH}.tmp" "$CODEX_AUTH"
  chmod 600 "$CODEX_AUTH"
  echo "Synced Pi -> Codex"
  echo "  source: $PI_AUTH"
  echo "  target: $CODEX_AUTH"
  echo "  id_token from: $SYNC_STATE"
  echo "  account: $account_id"
}

usage() {
  cat <<'EOF'
Usage: sync-codex-auth.sh <direction> [--no-backup]

  codex-to-pi    Convert ~/.codex/auth.json -> ~/.pi/agent/auth.json
  pi-to-codex    Convert ~/.pi/agent/auth.json -> ~/.codex/auth.json

The id_token is stored in a separate state file (default ~/.pi/codex-sync.json)
rather than pi's auth.json. Pi's OAuth refresh rewrites auth.json credentials
to only {type, access, refresh, expires, accountId} and drops unknown fields,
so an idToken inside auth.json would be erased on the first pi-side refresh.
The state file lives outside pi's agent directory, so pi never modifies it;
pi-to-codex keeps working even after pi refreshes tokens.

Options:
  --no-backup     Skip backing up the target file before overwriting
  --backup        Force backup (default)

Environment:
  CODEX_AUTH      Path to Codex auth.json (default: ~/.codex/auth.json)
  PI_AUTH         Path to Pi auth.json (default: ~/.pi/agent/auth.json)
  SYNC_STATE      Path to id_token state file (default: ~/.pi/codex-sync.json)
EOF
  exit 1
}

DIRECTION=""
for arg in "$@"; do
  case "$arg" in
    codex-to-pi|pi-to-codex) DIRECTION="$arg" ;;
    --no-backup) BACKUP=false ;;
    --backup) BACKUP=true ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $arg"; usage ;;
  esac
done

if [ -z "$DIRECTION" ]; then usage; fi

command -v jq >/dev/null 2>&1 || { echo "Error: jq is required"; exit 1; }

case "$DIRECTION" in
  codex-to-pi) codex_to_pi ;;
  pi-to-codex) pi_to_codex ;;
esac
