# runtime-base

Public base image for AI penetration-testing agents. It is intentionally
generic: it provides the system, language runtimes, package managers, browser,
wordlists and common security tooling, and downstream (often private) projects
build their own images `FROM ghcr.io/ai-bug-bounty/runtime-base`.

Published image:

```text
ghcr.io/ai-bug-bounty/runtime-base:main
ghcr.io/ai-bug-bounty/runtime-base:<branch>
ghcr.io/ai-bug-bounty/runtime-base:sha-<commit>
```

The image is public, so downstream projects do not need registry credentials.

## What is inside

- Kali Linux rolling plus **`kali-linux-headless`**: scanners and recon (`nmap`,
  masscan, nikto, whatweb, wpscan, skipfish), web tooling (`sqlmap`, `commix`,
  `ffuf`, `gobuster`, `wfuzz`, `dirb`, `arjun`, `dirsearch`, the ProjectDiscovery
  suite), credentials and AD (`hydra`, `medusa`, `john`, `hashcat`, `netexec`,
  `impacket`, `responder`, `evil-winrm`, `certipy`, `bloodhound`, `pypykatz`),
  exploitation (`metasploit-framework`, `exploitdb`, `radare2`), MITM/proxy
  tooling (`mitmproxy`, `proxychains4`), `wordlists`, `seclists` and more.
- Non-root `ubuntu` user with passwordless `sudo`; `apt` **and** Homebrew, so
  the agent can install anything missing itself.
- Docker-in-Docker, **on by default** (`START_DOCKERD=1`). The container must be
  started with `--privileged` and a `/var/lib/docker` volume — see *Run* below.
- Python venv at `/opt/venv` with `pydantic-ai` and common pentest libraries
  (`impacket`, `scapy`, `ldap3`, `certipy`, `pypykatz`, `playwright`, …).
  (`pwntools` is not included: its `unicorn` dependency has no Python 3.14
  wheel; install it in your own venv if you need it.)
- Go toolchain plus the Go tools Kali does not package (`tlsx`,
  `interactsh-client`, `gau`, `waybackurls`, `kerbrute`). ProjectDiscovery's
  httpx is Kali's `httpx-toolkit`, symlinked to `httpx` (the plain name belongs
  to the Python HTTP client).
- Node, Ruby, Java toolchains; Playwright Chromium for browser-driven testing,
  plus **`agent-browser`** (headless-Chromium automation CLI) wired to it.
- **mitmproxy** with its **root CA pre-installed** — generated at build time and
  trusted in the system store (`/usr/local/share/ca-certificates`), the user's
  NSS database (`~/.pki/nssdb`) and via `AGENT_BROWSER_CA_CERT` /
  `NODE_EXTRA_CA_CERTS` / `SSL_CERT_FILE` — so traffic can be intercepted
  without TLS errors.
- PayloadsAllTheThings, jwt_tool, enum4linux-ng (the pieces Kali does not ship).

Two deliberate build-time fixes worth knowing about:

- `llvm-21-dev` (pulled in by clang via the metapackage) ships Debian's
  recursive build-tree symlinks (`build/Release -> ..`), which make any naive
  tree walk recurse until `ELOOP` and broke `msfconsole`. The Dockerfile removes
  those two symlinks.
- `nmap` ships with file capabilities and a wrapper that forces `--privileged`
  for non-root users, so it only runs in a container that has `NET_ADMIN` —
  which `--privileged` implies.

## Browser and proxy environment

The image exports these so the browser and the proxy work without setup:

| Variable | Value |
|---|---|
| `AGENT_BROWSER_EXECUTABLE_PATH` | `/opt/agent-browser-chromium` (symlink to the Playwright headless-shell build) |
| `AGENT_BROWSER_CA_CERT`, `NODE_EXTRA_CA_CERTS` | `~/.mitmproxy/mitmproxy-ca-cert.pem` |
| `SSL_CERT_FILE`, `REQUESTS_CA_BUNDLE`, `CURL_CA_BUNDLE` | `/etc/ssl/certs/ca-certificates.crt` (merged system bundle) |

`AGENT_BROWSER_PROXY` is deliberately **not** set: agent-browser should only be
routed through mitmproxy when you ask for it (e.g.
`agent-browser --proxy http://127.0.0.1:8080 …`), not for every command.

## Build

```bash
make build
# or
docker build -t runtime-base .
```

The build installs `kali-linux-headless` (~199 packages) and takes ~25–30
minutes cold. Metasploit arrives with the metapackage; there is no opt-in flag
any more.

## Run

The entrypoint starts the nested Docker daemon and then runs the command, so
give it `--privileged` **and** a `/var/lib/docker` volume:

```bash
make shell    # interactive, privileged
docker run --rm -it --privileged -v /var/lib/docker runtime-base bash
```

Both flags are required: `--privileged` because a daemon needs host-level
capabilities (the capability set alone is not enough — cgroups and overlayfs
refuse), and the volume so the nested daemon's overlayfs does not stack on the
container's own writable layer (without it `dockerd` starts but no container can
run). `--rm` removes the anonymous volume with the container.

Set `START_DOCKERD=0` to skip the daemon (e.g. when running unprivileged).

## Test

```bash
make test     # or: ./scripts/smoke-test.sh runtime-base:local
```

The GitHub Actions workflow builds, pushes, smoke-tests and verifies
Docker-in-Docker. Because this repository is public, Actions minutes are free.
