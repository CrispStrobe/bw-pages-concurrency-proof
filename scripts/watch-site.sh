#!/usr/bin/env bash
# Poll the published site and record, per sample: which build is served, and
# whether the chunk that index.html names actually exists.
#
# Two failures are visible from here and from nowhere else:
#   out-of-order   the served build goes BACKWARDS in time
#   mismatched     index.html names a chunk that 404s (the incident §2.1 warns of)
set -uo pipefail
url=${1:?site url}
secs=${2:-900}
end=$(( $(date +%s) + secs ))
prev=""
while [ "$(date +%s)" -lt "$end" ]; do
  html=$(curl -sf "$url?cb=$(date +%s%N)" || echo "")
  build=$(printf '%s' "$html" | sed -n 's/.*chunks\/app\.\([0-9a-f]*\)\.js.*/\1/p' | head -1)
  if [ -n "$build" ]; then
    code=$(curl -s -o /dev/null -w '%{http_code}' "${url}chunks/app.${build}.js?cb=$(date +%s%N)")
    if [ "$build" != "$prev" ]; then
      echo "$(date -Is) served=$build chunk=$code"
      prev="$build"
    fi
  fi
  sleep 5
done
