#!/usr/bin/env bash
set -euo pipefail

log() { printf '%s\n' "$*" >&2; }

read -r -p "Input media file path (drag & drop works): " in_raw

in="$(
python3 - <<'PY' "$in_raw"
import os, shlex, sys
s = sys.argv[1].strip()

# Expand ~
s = os.path.expanduser(s)

# If user pasted a shell-escaped path, shlex will unescape it.
# If they pasted an unquoted path with spaces, shlex splits it; re-join as best-effort.
try:
    parts = shlex.split(s)
    if len(parts) == 1:
        s2 = parts[0]
    elif len(parts) > 1:
        s2 = " ".join(parts)
    else:
        s2 = s
except Exception:
    s2 = s

print(os.path.abspath(s2))
PY
)"

log ""
log "Input (normalized): $in"

if [[ ! -f "$in" ]]; then
  log "ERROR: file not found."
  log "Raw input was: [$in_raw]"
  log "Normalized to: [$in]"
  parent="$(dirname "$in")"
  log "Parent dir: $parent"
  if [[ -d "$parent" ]]; then
    log "Here are similar files in that folder:"
    ls -la "$parent" | sed -n '1,200p' >&2
  else
    log "Parent directory does not exist (or cannot be accessed)."
  fi
  exit 1
fi

dir="$(cd "$(dirname "$in")" && pwd)"
base="$(basename "$in")"
name="${base%.*}"
out="$dir/$name.m4a"

log "Output: $out"
log ""

# Try stream copy first (fast, no quality loss) — works great if source audio is AAC.
# If that fails (codec/container mismatch), fall back to encoding AAC.
log "Trying: stream copy (-c:a copy)..."
if ffmpeg -hide_banner -y -i "$in" -vn -c:a copy "$out"; then
  log "Done (copied audio without re-encoding)."
  exit 0
fi

log ""
log "Stream copy failed; falling back to AAC encode..."
ffmpeg -hide_banner -y -i "$in" -vn -c:a aac -b:a 192k "$out"
log "Done (encoded AAC 192k)."