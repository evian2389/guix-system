#!/usr/bin/env bash
# Render ~/.zeroclaw/config.toml from config.toml.tmpl, injecting bot tokens
# from `pass`. Invoked by non-guix-packages.sh during `make reconfigure-home`.
#
# Design notes:
#   - ZeroClaw has no env-var / keyring support (v0.1.7), so secrets are
#     substituted here at deploy time rather than referenced at runtime.
#   - ZeroClaw rewrites config.toml in place; this script re-asserts the
#     declarative template on every reconfigure-home. Runtime `channel add`
#     edits are intentionally overwritten.
#   - If `pass`/gpg cannot be reached, we abort rather than write a config
#     with the token blocks stripped out.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMPL="$SCRIPT_DIR/config.toml.tmpl"
DEST="$HOME/.zeroclaw/config.toml"

command -v zeroclaw >/dev/null 2>&1 || { echo "zeroclaw not installed; skipping config render"; exit 0; }
command -v pass     >/dev/null 2>&1 || { echo "pass not installed; skipping zeroclaw config render"; exit 0; }
[ -f "$TMPL" ] || { echo "zeroclaw template missing: $TMPL"; exit 1; }

# pass_get NAME -> prints secret, or empty string if that entry does not exist.
# A gpg-agent / decryption failure (entry exists but can't be read) is fatal.
pass_get() {
  local name="$1" out rc
  if ! pass ls "$name" >/dev/null 2>&1; then
    return 0
  fi
  set +e
  out="$(pass show "$name" 2>/dev/null | head -n1)"
  rc=$?
  set -e
  if [ $rc -ne 0 ] || [ -z "$out" ]; then
    echo "ERROR: 'pass show $name' failed (gpg locked?). Aborting so the existing config is left intact." >&2
    exit 1
  fi
  printf '%s' "$out"
}

TELEGRAM_BOT_TOKEN="$(pass_get zeroclaw/telegram-bot-token)"
DISCORD_BOT_TOKEN="$(pass_get zeroclaw/discord-bot-token)"
DISCORD_USER_ID="$(pass_get zeroclaw/discord-user-id)"

python3 - "$TMPL" "$TELEGRAM_BOT_TOKEN" "$DISCORD_BOT_TOKEN" "$DISCORD_USER_ID" <<'PY' > "$SCRIPT_DIR/.rendered.tmp"
import re, sys
tmpl, tg, dc, dc_uid = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
s = open(tmpl).read()

def block(text, name, body):
    pat = re.compile(r"\n# --- BEGIN %s ---\n.*?\n# --- END %s ---\n" % (name, name), re.S)
    return pat.sub(body, text)

# Telegram: substitute token, or drop the block entirely if no secret.
if tg:
    s = s.replace("@TELEGRAM_BOT_TOKEN@", tg)
    s = s.replace("\n# --- BEGIN channels_config.telegram ---\n", "\n") \
         .replace("\n# --- END channels_config.telegram ---\n", "\n")
else:
    s = block(s, "channels_config.telegram", "\n")

# Discord: only emit the block when we have a token.
if dc:
    uid = dc_uid or "@DISCORD_USER_ID@"
    body = (
        '\n[channels_config.discord]\n'
        'bot_token = "%s"\n'
        'allowed_users = ["%s"]\n' % (dc, uid)
    )
    s = block(s, "channels_config.discord", body)
else:
    s = block(s, "channels_config.discord", "\n")

s = re.sub(r"\n{3,}", "\n\n", s)
sys.stdout.write(s)
PY

install -m 600 -D "$SCRIPT_DIR/.rendered.tmp" "$DEST"
rm -f "$SCRIPT_DIR/.rendered.tmp"
echo "Rendered $DEST (telegram: $([ -n "$TELEGRAM_BOT_TOKEN" ] && echo yes || echo no), discord: $([ -n "$DISCORD_BOT_TOKEN" ] && echo yes || echo no))"

# Sanity-check that ZeroClaw can parse it and still points at Codex.
if zeroclaw status 2>/dev/null | python3 -c 'import sys; sys.exit(0 if "openai-codex" in sys.stdin.read() else 1)'; then
  echo "zeroclaw provider: openai-codex OK"
else
  echo "WARNING: zeroclaw status does not show openai-codex provider"
fi
