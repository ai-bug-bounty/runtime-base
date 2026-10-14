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
set -euo pipefail

echo "==> installing agent-browser from npm"
sudo npm install -g agent-browser

echo "==> locating a Chromium for agent-browser"
chromium="$(find /opt/ms-playwright -type f \
  -path '*chrome-headless-shell-linux64/chrome-headless-shell' | sort | tail -n1)"
if [ -z "${chromium}" ]; then
  echo "chrome-headless-shell not found; falling back to the full Chromium build" >&2
  chromium="$(find /opt/ms-playwright -type f -name chrome | sort | tail -n1)"
fi
[ -n "${chromium}" ] || { echo "no Chromium found under /opt/ms-playwright" >&2; exit 1; }

sudo ln -sfn "${chromium}" /opt/agent-browser-chromium
echo "==> agent-browser Chromium: /opt/agent-browser-chromium -> ${chromium}"

agent-browser --version
