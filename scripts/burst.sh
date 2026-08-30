#!/usr/bin/env bash
# Push N commits back-to-back, the way two agents pushing at once looks to CI.
set -euo pipefail
n=${1:-5}
tag=${2:-burst}
for i in $(seq 1 "$n"); do
  date -Is > "beat.txt"
  echo "$tag $i/$n" >> beat.txt
  git add beat.txt
  git commit -q -m "$tag $i/$n"
  git push -q origin main
  echo "pushed $tag $i/$n -> $(git rev-parse --short HEAD)"
done
