#!/usr/bin/env bash
# Usage: tools/set_min_build.sh <minBuild> [version]
# Sets config/app in Firestore (needs `gcloud auth login` with project access).
set -euo pipefail
build="${1:?minBuild missing}"; version="${2:-}"
body="{\"fields\":{\"minBuild\":{\"integerValue\":\"$build\"}"
mask="updateMask.fieldPaths=minBuild"
if [ -n "$version" ]; then
  body="$body,\"version\":{\"stringValue\":\"$version\"}"; mask="$mask&updateMask.fieldPaths=version"
fi
body="$body}}"
curl -fsS -X PATCH \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" -d "$body" \
  "https://firestore.googleapis.com/v1/projects/tradinggame-austria-prod/databases/(default)/documents/config/app?$mask" >/dev/null
echo "config/app.minBuild = $build"
