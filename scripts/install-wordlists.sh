#!/usr/bin/env bash
# Payload collections and helper scripts that Kali does not ship.
#
# Kali's `wordlists` and `seclists` packages (part of kali-linux-headless) cover
# the wordlists, and testssl.sh/commix/jwt_tool-adjacent tools come from apt, so
# this only fetches what is genuinely missing.
set -euo pipefail

mkdir -p /opt/payloads /usr/share/wordlists

echo "==> SecLists lives in /usr/share/seclists (Kali package); link the old path"
if [ -d /usr/share/seclists ]; then
  ln -sfn /usr/share/seclists /usr/share/wordlists/seclists
fi

echo "==> rockyou (Kali ships it gzipped; leave it as-is, tools read .gz)"
ls /usr/share/wordlists/rockyou.txt* 2>/dev/null || echo "note: no rockyou in /usr/share/wordlists"

echo "==> PayloadsAllTheThings"
if [ ! -d /opt/payloads/PayloadsAllTheThings/.git ]; then
  git clone --depth 1 \
    https://github.com/swisskyrepo/PayloadsAllTheThings.git \
    /opt/payloads/PayloadsAllTheThings
fi

echo "==> jwt_tool"
if [ ! -d /opt/jwt_tool/.git ]; then
  git clone --depth 1 https://github.com/ticarpi/jwt_tool.git /opt/jwt_tool
fi
ln -sfn /opt/jwt_tool/jwt_tool.py /usr/local/bin/jwt_tool

chmod -R a+rX /opt/payloads /opt/jwt_tool
