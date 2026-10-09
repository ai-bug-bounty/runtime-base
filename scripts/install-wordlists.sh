#!/usr/bin/env bash
# Wordlists, payload collections and small helper scripts.
set -euo pipefail

mkdir -p /opt/wordlists /opt/payloads /usr/share/wordlists

echo "==> SecLists (sparse checkout of the most useful directories)"
if [ ! -d /opt/wordlists/SecLists/.git ]; then
  git clone --depth 1 --filter=blob:none --sparse \
    https://github.com/danielmiessler/SecLists.git /opt/wordlists/SecLists
  git -C /opt/wordlists/SecLists sparse-checkout set \
    Discovery/Web-Content \
    Discovery/DNS \
    Discovery/Infrastructure \
    Passwords \
    Usernames \
    Fuzzing
fi
ln -sfn /opt/wordlists/SecLists /usr/share/wordlists/seclists

echo "==> PayloadsAllTheThings"
if [ ! -d /opt/payloads/PayloadsAllTheThings/.git ]; then
  git clone --depth 1 \
    https://github.com/swisskyrepo/PayloadsAllTheThings.git \
    /opt/payloads/PayloadsAllTheThings
fi

echo "==> testssl.sh"
if [ ! -d /opt/testssl.sh/.git ]; then
  git clone --depth 1 https://github.com/drwetter/testssl.sh.git /opt/testssl.sh
fi
ln -sfn /opt/testssl.sh/testssl.sh /usr/local/bin/testssl.sh

echo "==> jwt_tool"
if [ ! -d /opt/jwt_tool/.git ]; then
  git clone --depth 1 https://github.com/ticarpi/jwt_tool.git /opt/jwt_tool
fi
ln -sfn /opt/jwt_tool/jwt_tool.py /usr/local/bin/jwt_tool

echo "==> commix"
if [ ! -d /opt/commix/.git ]; then
  git clone --depth 1 https://github.com/commixproject/commix.git /opt/commix
fi
ln -sfn /opt/commix/commix.py /usr/local/bin/commix

chmod -R a+rX /opt/wordlists /opt/payloads /opt/testssl.sh /opt/jwt_tool /opt/commix
