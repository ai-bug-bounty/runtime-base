#!/usr/bin/env bash
# Install the latest stable Go toolchain from go.dev for the target arch.
set -euo pipefail

arch="${TARGETARCH:-amd64}"
case "$arch" in
  amd64) goarch="amd64" ;;
  arm64) goarch="arm64" ;;
  *)
    echo "unsupported TARGETARCH: $arch" >&2
    exit 1
    ;;
esac

echo "==> resolving latest stable Go version"
go_version="$(curl -fsSL 'https://go.dev/dl/?mode=json' \
  | python3 -c 'import json, sys; print(json.load(sys.stdin)[0]["version"].removeprefix("go"))')"
: "${go_version:?could not determine latest Go version}"
echo "==> installing Go ${go_version} (linux/${goarch})"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "https://go.dev/dl/go${go_version}.linux-${goarch}.tar.gz" -o "$tmp/go.tar.gz"
rm -rf /usr/local/go
tar -C /usr/local -xzf "$tmp/go.tar.gz"
/usr/local/go/bin/go version
