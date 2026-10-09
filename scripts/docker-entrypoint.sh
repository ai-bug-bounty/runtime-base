#!/usr/bin/env bash
# Start a nested Docker daemon, wait for it, then exec the given command.
set -euo pipefail

DOCKERD_LOG="${DOCKERD_LOG:-/tmp/dockerd.log}"

sudo dockerd >"${DOCKERD_LOG}" 2>&1 &
dockerd_pid=$!

cleanup() {
  if kill -0 "${dockerd_pid}" 2>/dev/null; then
    sudo kill "${dockerd_pid}" 2>/dev/null || true
    wait "${dockerd_pid}" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

for _ in $(seq 1 100); do
  if docker info >/dev/null 2>&1; then
    exec "$@"
  fi

  if ! kill -0 "${dockerd_pid}" 2>/dev/null; then
    break
  fi

  sleep 0.1
done

echo "Docker daemon failed to become ready." >&2
cat "${DOCKERD_LOG}" >&2 || true
exit 1
