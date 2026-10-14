#!/usr/bin/env bash
# Install the agent-browser CLI (vercel-labs/agent-browser).
#
# agent-browser is an npm package whose postinstall downloads a native Rust
# binary; Node is only needed for the install, never at runtime. By default it
# would also download its own Google Chrome for Testing (~700 MB). The image
# already ships Chromium for Playwright, so instead we point the CLI at the
# matching `chrome-headless-shell` build through a stable symlink and export
# AGENT_BROWSER_EXECUTABLE_PATH (set in the Dockerfile).
#
# `chrome-headless-shell` is the headless-only build Playwright itself drives
# in headless mode. The full `chrome` binary shipped alongside it aborts at
# startup in containerised/nested environments (crashpad handler failure).
#
# Runs as root during the image build: BuildKit runs build steps with
# no-new-privileges, so `sudo` is unusable there. The npm cache is kept out of
# the agent's home so it does not end up owned by root.
set -euo pipefail

AGENT_USER=ubuntu
AGENT_BROWSER_BIN=/usr/local/lib/node_modules/agent-browser/bin
CHROMIUM_LINK=/opt/agent-browser-chromium

echo "==> installing agent-browser from npm"
npm install -g --cache /root/.npm agent-browser
# The native binary is what actually runs; make sure the agent user can exec it.
chmod -R a+rX /usr/local/lib/node_modules/agent-browser
[ -d "${AGENT_BROWSER_BIN}" ] && chmod 0755 "${AGENT_BROWSER_BIN}"/agent-browser-* 2>/dev/null || true

echo "==> locating a Chromium for agent-browser"
chromium="$(find /opt/ms-playwright -type f \
  -path '*chrome-headless-shell-linux64/chrome-headless-shell' | sort | tail -n1)"
if [ -z "${chromium}" ]; then
  echo "chrome-headless-shell not found; falling back to the full Chromium build" >&2
  chromium="$(find /opt/ms-playwright -type f -name chrome | sort | tail -n1)"
fi
[ -n "${chromium}" ] || { echo "no Chromium found under /opt/ms-playwright" >&2; exit 1; }

ln -sfn "${chromium}" "${CHROMIUM_LINK}"
echo "==> agent-browser Chromium: ${CHROMIUM_LINK} -> ${chromium}"

su - "${AGENT_USER}" -c 'agent-browser --version'
