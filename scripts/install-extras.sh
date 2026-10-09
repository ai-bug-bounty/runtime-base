#!/usr/bin/env bash
# Tools that are not available as Ubuntu 24.04 packages.
set -euo pipefail

echo "==> wpscan (Ruby gem)"
gem install wpscan --no-document

echo "==> enum4linux-ng"
if [ ! -d /opt/enum4linux-ng/.git ]; then
  git clone --depth 1 https://github.com/cddmp/enum4linux-ng.git /opt/enum4linux-ng
fi
chmod +x /opt/enum4linux-ng/enum4linux-ng.py
ln -sfn /opt/enum4linux-ng/enum4linux-ng.py /usr/local/bin/enum4linux-ng
