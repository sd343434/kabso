#!/usr/bin/env bash
# Print the current registry digest of Docker Hub image tags, for digest pinning (SEC-021).
#
#   scripts/image-digests.sh postgres:16.15-alpine redis:7.4-alpine pgsty/minio:RELEASE.2026-08-04T00-00-00Z
#
# The digest printed is the one `docker pull <image>:<tag>` resolves: the multi-arch index
# (manifest list) digest when the tag is multi-arch, so the pin works on amd64 CI runners and
# arm64 laptops alike. Paste the result as `<image>:<tag>@sha256:...` in docker-compose.yml and
# in the service containers of .github/workflows/ci.yml.
# Requires: curl, python3. Talks only to auth.docker.io and registry-1.docker.io.
set -euo pipefail

if [ "$#" -eq 0 ]; then
  sed -n '2,10p' "$0"
  exit 2
fi

accept="application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json"

for ref in "$@"; do
  name="${ref%%:*}"
  tag="${ref#*:}"
  if [ "$name" = "$ref" ]; then
    tag="latest"
  fi
  case "$name" in
    */*) repo="$name" ;;
    *) repo="library/$name" ;;
  esac

  scope="repository:${repo}:pull"
  token="$(curl -fsS "https://auth.docker.io/token?service=registry.docker.io&scope=${scope}" |
    python3 -I -c 'import json, sys; print(json.load(sys.stdin)["token"])')"

  digest="$(curl -fsS -I \
    -H "Authorization: Bearer ${token}" \
    -H "Accept: ${accept}" \
    "https://registry-1.docker.io/v2/${repo}/manifests/${tag}" |
    tr -d '\r' | awk 'tolower($1) == "docker-content-digest:" { print $2 }')"

  if [ -z "$digest" ]; then
    echo "error: no digest returned for ${ref}" >&2
    exit 1
  fi
  printf '%s@%s\n' "$ref" "$digest"
done
