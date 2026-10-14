#!/usr/bin/env bash
# Install mitmproxy's root CA and trust it where clients look.
#
# mitmproxy generates its CA on first start, so we start it briefly at build
# time and capture the certificate. The CA is then installed into:
#   * the system trust store (/usr/local/share/ca-certificates + update-ca-certificates),
#     which covers curl, openssl, Go, and anything using the OS bundle
#   * the user's NSS database, which is what Chromium/Chrome read on Linux
#   * a PEM file whose path is exported as AGENT_BROWSER_CA_CERT / NODE_EXTRA_CA_CERTS
#
# With the CA trusted, traffic can be proxied through mitmproxy instead of
# failing TLS verification.
set -euo pipefail

CONFDIR="${HOME}/.mitmproxy"
CA_PEM="${CONFDIR}/mitmproxy-ca-cert.pem"

if [ ! -f "${CA_PEM}" ]; then
  echo "==> generating the mitmproxy CA"
  # mitmdump writes the CA within the first second of startup; stop it as soon
  # as the file appears (use a port unlikely to collide).
  mitmdump -q --listen-port 8999 >/tmp/mitmproxy-ca-gen.log 2>&1 &
  mitm_pid=$!
  for _ in $(seq 1 100); do
    [ -f "${CA_PEM}" ] && break
    sleep 0.1
  done
  kill "${mitm_pid}" 2>/dev/null || true
  wait "${mitm_pid}" 2>/dev/null || true
fi

if [ ! -f "${CA_PEM}" ]; then
  echo "mitmproxy did not generate a CA; see /tmp/mitmproxy-ca-gen.log" >&2
  exit 1
fi

echo "==> installing the mitmproxy CA into the system trust store"
sudo install -m 0644 "${CA_PEM}" /usr/local/share/ca-certificates/mitmproxy-ca.crt
sudo update-ca-certificates

echo "==> installing the mitmproxy CA into the user's NSS database"
mkdir -p "${HOME}/.pki/nssdb"
certutil -d "sql:${HOME}/.pki/nssdb" -N --empty-password 2>/dev/null || true
certutil -d "sql:${HOME}/.pki/nssdb" -A -t "C,," -n mitmproxy -i "${CA_PEM}"
certutil -d "sql:${HOME}/.pki/nssdb" -L | grep -q mitmproxy

echo "==> mitmproxy CA ready at ${CA_PEM}"
