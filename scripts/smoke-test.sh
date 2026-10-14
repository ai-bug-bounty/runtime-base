#!/usr/bin/env bash
# Smoke-test a built runtime image: verify required tooling is present and
# runnable. The image entrypoint starts a Docker daemon, so override it here.
set -euo pipefail

image="${1:?usage: smoke-test.sh <image:tag>}"

echo "==> smoke-testing ${image}"

docker run --rm --entrypoint bash "$image" -lc '
  set -uo pipefail

  required=(
    # recon / web
    nmap masscan nikto sqlmap whatweb gobuster ffuf wfuzz dirb
    nuclei httpx subfinder naabu dnsx katana tlsx gau dalfox waybackurls
    kerbrute interactsh-client gowitness wpscan enum4linux-ng
    testssl.sh jwt_tool commix
    # credentials / network
    hydra medusa john hashcat smbclient sslscan tcpdump proxychains4
    # toolchains / platform
    python3 pip3 go node npm ruby gem brew docker git jq
    # python CLI tools
    mitmproxy wafw00f arjun dirsearch netexec theHarvester
    # browser automation and the CA trust store tool
    agent-browser certutil
  )

  missing=0
  for cmd in "${required[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
      echo "ok:   $cmd"
    else
      echo "MISSING: $cmd"
      missing=1
    fi
  done

  echo "--- python libraries ---"
  python3 - <<'"'"'PY'"'"'
import importlib

mods = [
    "pydantic_ai", "requests", "httpx", "bs4", "lxml", "dns",
    "jwt", "Crypto", "paramiko", "nmap", "yaml", "scapy",
    "impacket", "pwn", "ldap3", "pypykatz", "playwright",
]
failed = []
for mod in mods:
    try:
        importlib.import_module(mod)
        print(f"ok:   {mod}")
    except Exception as exc:  # noqa: BLE001
        print(f"MISSING: {mod} ({exc})")
        failed.append(mod)
raise SystemExit(1 if failed else 0)
PY
  lib_status=$?

  echo "--- optional ---"
  if docker compose version >/dev/null 2>&1; then
    echo "ok:   docker compose"
  else
    echo "MISSING: docker compose"
    missing=1
  fi
  command -v msfconsole >/dev/null 2>&1 && echo "ok:   msfconsole" || echo "note: msfconsole not installed"

  echo "--- mitmproxy CA ---"
  ca="$HOME/.mitmproxy/mitmproxy-ca-cert.pem"
  if [ -f "$ca" ]; then
    echo "ok:   mitmproxy CA generated ($ca)"
  else
    echo "MISSING: mitmproxy CA ($ca)"
    missing=1
  fi
  if [ -f /usr/local/share/ca-certificates/mitmproxy-ca.crt ]; then
    echo "ok:   mitmproxy CA in the system trust store"
  else
    echo "MISSING: mitmproxy CA in the system trust store"
    missing=1
  fi
  if certutil -d "sql:$HOME/.pki/nssdb" -L 2>/dev/null | grep -q mitmproxy; then
    echo "ok:   mitmproxy CA in the NSS database"
  else
    echo "MISSING: mitmproxy CA in the NSS database"
    missing=1
  fi

  if [ "$missing" -ne 0 ] || [ "$lib_status" -ne 0 ]; then
    echo "SMOKE TEST FAILED"
    exit 1
  fi
  echo "SMOKE TEST PASSED"
'
