#!/usr/bin/env bash
# Install Python-based pentest CLIs, each isolated by pipx.
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

# Tools published on PyPI.
pypi_tools=(
  mitmproxy
  wafw00f
  arjun
  dirsearch
)

# Tools that must be installed straight from git. Pin refs: upstream master may
# require a newer Python than the Ubuntu 24.04 interpreter (theHarvester needed
# >=3.14 on master, while 4.11.1 still supports >=3.12).
git_tools=(
  "git+https://github.com/Pennyw0rth/NetExec@v1.5.1"
  "git+https://github.com/laramies/theHarvester@4.11.1"
)

for tool in "${pypi_tools[@]}"; do
  echo "==> pipx install ${tool}"
  pipx install "$tool"
done

for tool in "${git_tools[@]}"; do
  echo "==> pipx install ${tool}"
  pipx install "$tool"
done

pipx list
