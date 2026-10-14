#!/usr/bin/env bash
# Generate mitmproxy's root CA and trust it where clients look.
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
#
# Runs as root during the image build: BuildKit runs build steps with
# no-new-privileges, so `sudo` is unusable there. Anything that should end up
# owned by the agent is run as that user with `su` instead.
set -euo pipefail

AGENT_USER=ubuntu
AGENT_HOME=/home/ubuntu
CA_PEM="${AGENT_HOME}/.mitmproxy/mitmproxy-ca-cert.pem"
NSSDB="${AGENT_HOME}/.pki/nssdb"

if [ ! -f "${CA_PEM}" ]; then
  echo "==> generating the mitmproxy CA (as ${AGENT_USER})"
  su - "${AGENT_USER}" -c '
    mitmdump -q --listen-port 8999 >/tmp/mitmproxy-ca-gen.log 2>&1 &
    mitm_pid=$!
    for _ in $(seq 1 200); do
      [ -f "$HOME/.mitmproxy/mitmproxy-ca-cert.pem" ] && break
      sleep 0.1
    done
    kill "$mitm_pid" 2>/dev/null || true
    wait "$mitm_pid" 2>/dev/null || true
  '
fi

if [ ! -f "${CA_PEM}" ]; then
  echo "mitmproxy did not generate a CA; see /tmp/mitmproxy-ca-gen.log" >&2
  cat /tmp/mitmproxy-ca-gen.log >&2 || true
  exit 1
fi

echo "==> installing the mitmproxy CA into the system trust store"
install -m 0644 "${CA_PEM}" /usr/local/share/ca-certificates/mitmproxy-ca.crt
update-ca-certificates

echo "==> installing the mitmproxy CA into the user's NSS database"
mkdir -p "${NSSDB}"
certutil -d "sql:${NSSDB}" -N --empty-password 2>/dev/null || true
certutil -d "sql:${NSSDB}" -A -t "C,," -n mitmproxy -i "${CA_PEM}"
certutil -d "sql:${NSSDB}" -L | grep -q mitmproxy
chown -R "${AGENT_USER}:${AGENT_USER}" "${AGENT_HOME}/.pki"

echo "==> mitmproxy CA ready at ${CA_PEM}"
