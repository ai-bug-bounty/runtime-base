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

# NetExec pins `certipy-ad @ git+https://github.com/Pennyw0rth/Certipy`, but
# that repository renamed its project to `certipy-nxc`, so pip now rejects the
# dependency ("expected 'certipy-ad', but metadata has 'certipy-nxc'"). Install
# from a checkout with that one dependency pointed at the renamed PyPI package,
# which still ships the `certipy` module NetExec imports.
netexec_src="$(mktemp -d)/NetExec"
echo "==> pipx install NetExec@v1.5.1 (with the certipy-ad -> certipy-nxc fix)"
git clone --quiet --depth 1 --branch v1.5.1 \
  https://github.com/Pennyw0rth/NetExec "$netexec_src"
sed -i \
  's|certipy-ad @ git+https://github.com/Pennyw0rth/Certipy|certipy-nxc>=5.1,<6|' \
  "$netexec_src/pyproject.toml"
if ! grep -q "certipy-nxc" "$netexec_src/pyproject.toml"; then
  echo "could not patch NetExec's certipy dependency; upstream changed it again" >&2
  exit 1
fi
pipx install "$netexec_src"

pipx list
