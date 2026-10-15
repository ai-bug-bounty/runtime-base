#!/usr/bin/env bash
# Smoke-test a built runtime image: verify required tooling is present and
# runnable. The image entrypoint starts a Docker daemon, so override it here.
set -euo pipefail

image="${1:?usage: smoke-test.sh <image:tag>}"

echo "==> smoke-testing ${image}"

docker run --rm --entrypoint bash "$image" -lc '
  set -uo pipefail

  required=(
    # recon / web (from kali-linux-headless unless noted)
    nmap masscan nikto sqlmap whatweb gobuster ffuf wfuzz dirb
    nuclei httpx subfinder naabu dnsx katana feroxbuster dalfox
    gau waybackurls tlsx kerbrute interactsh-client gowitness
    arjun dirsearch wpscan enum4linux-ng testssl.sh jwt_tool commix
    # credentials / network
    hydra medusa john hashcat smbclient sslscan tcpdump proxychains4
    # toolchains / platform
    python3 pip3 go node npm ruby gem brew docker git jq
    # proxies and python CLI tools
    mitmproxy wafw00f netexec theharvester
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
    "impacket", "ldap3", "pypykatz", "playwright",
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

  echo "--- nmap ---"
  # Kali ships nmap with file capabilities, so it only runs when the container
  # has NET_ADMIN (which --privileged implies). CI checks the privileged case
  # separately; here we only report.
  if nmap --version >/dev/null 2>&1; then
    echo "ok:   nmap runs"
  else
    echo "note: nmap needs --privileged (this container is unprivileged)"
  fi

  echo "--- metasploit ---"
  # Regression check for the llvm-21-dev build-tree symlinks that used to break
  # bootsnap: msfconsole must actually start, not just exist. (Capture the output
  # instead of piping to `grep -q`, which would SIGPIPE msfconsole and, under
  # `pipefail`, look like a failure.)
  if command -v msfconsole >/dev/null 2>&1; then
    msf_out="$(timeout 300 msfconsole -q -x "version; exit" 2>&1 || true)"
    case "$msf_out" in
      *Framework:*) echo "ok:   msfconsole starts" ;;
      *) echo "MISSING: msfconsole fails to start"; printf '%s\n' "$msf_out" | tail -3; missing=1 ;;
    esac
  else
    echo "MISSING: msfconsole"
    missing=1
  fi

  echo "--- docker compose ---"
  if docker compose version >/dev/null 2>&1; then
    echo "ok:   docker compose"
  else
    echo "MISSING: docker compose"
    missing=1
  fi

  echo "--- wordlists ---"
  for path in /usr/share/wordlists /usr/share/seclists /usr/share/wordlists/seclists; do
    if [ -e "$path" ]; then
      echo "ok:   $path"
    else
      echo "MISSING: $path"
      missing=1
    fi
  done

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
  nss_list="$(certutil -d "sql:$HOME/.pki/nssdb" -L 2>/dev/null || true)"
  case "$nss_list" in
    *mitmproxy*) echo "ok:   mitmproxy CA in the NSS database" ;;
    *) echo "MISSING: mitmproxy CA in the NSS database"; missing=1 ;;
  esac

  if [ "$missing" -ne 0 ] || [ "$lib_status" -ne 0 ]; then
    echo "SMOKE TEST FAILED"
    exit 1
  fi
  echo "SMOKE TEST PASSED"
'
