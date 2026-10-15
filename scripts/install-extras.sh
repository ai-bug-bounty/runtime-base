#!/usr/bin/env bash
# Tools that neither Kali's repository nor kali-linux-headless provides.
#
# wpscan, testssl.sh, commix, dirsearch, arjun, responder, evil-winrm, medusa
# and the rest of the classic set come from apt now; only these two need
# fetching.
set -euo pipefail

echo "==> enum4linux-ng"
if [ ! -d /opt/enum4linux-ng/.git ]; then
  git clone --depth 1 https://github.com/cddmp/enum4linux-ng.git /opt/enum4linux-ng
fi
chmod +x /opt/enum4linux-ng/enum4linux-ng.py
ln -sfn /opt/enum4linux-ng/enum4linux-ng.py /usr/local/bin/enum4linux-ng
