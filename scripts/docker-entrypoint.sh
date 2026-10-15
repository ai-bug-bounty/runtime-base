#!/usr/bin/env bash
# Start the nested Docker daemon, wait for it, then run the given command.
#
# This is the only Docker-in-Docker startup path: the base image uses it
# directly, and the agent image's entrypoint calls this script for its own
# `bbhunter …` command, so `make base-shell`, `make agent-shell` and an
# orchestrator-started task all get a daemon started exactly the same way.
#
# The container must be started with `--privileged` and a `/var/lib/docker`
# volume: privileged because a daemon needs host-level capabilities (capabilities
# alone are not enough — cgroups and overlayfs both refuse), and the volume so
# the nested daemon does not stack overlayfs on the container's own overlayfs.
set -euo pipefail

if [ "${START_DOCKERD:-1}" = "1" ]; then
  dockerd_log="${DOCKERD_LOG:-/tmp/dockerd.log}"
  echo "==> starting nested Docker daemon (log: ${dockerd_log})"
  sudo dockerd >"${dockerd_log}" 2>&1 &
  dockerd_pid=$!

  cleanup() {
    if kill -0 "${dockerd_pid}" 2>/dev/null; then
      sudo kill "${dockerd_pid}" 2>/dev/null || true
      wait "${dockerd_pid}" 2>/dev/null || true
    fi
  }
  trap cleanup EXIT INT TERM

  for _ in $(seq 1 150); do
    if docker info >/dev/null 2>&1; then
      break
    fi
    if ! kill -0 "${dockerd_pid}" 2>/dev/null; then
      break
    fi
    sleep 0.1
  done

  if ! docker info >/dev/null 2>&1; then
    echo "Docker daemon failed to become ready." >&2
    cat "${dockerd_log}" >&2 || true
    echo "Hint: start the container with --privileged and -v /var/lib/docker." >&2
    exit 1
  fi
  echo "==> docker is ready (server $(docker info --format '{{.ServerVersion}}'))"
fi

exec "$@"
