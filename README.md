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

- Ubuntu 24.04, non-root `ubuntu` user with passwordless `sudo`.
- `apt` **and** Homebrew, so the agent can install missing tools itself.
- Docker-in-Docker (started by the entrypoint; requires `--privileged`).
- Python venv at `/opt/venv` with `pydantic-ai` and common pentest libraries,
  plus isolated pipx CLIs (mitmproxy, wafw00f, arjun, dirsearch, NetExec,
  theHarvester).
- Go toolchain and recon/web binaries (nuclei, httpx, subfinder, naabu, dnsx,
  katana, tlsx, interactsh-client, gau, dalfox, waybackurls, kerbrute,
  gowitness).
- Node, Ruby (incl. wpscan), Java.
- Playwright Chromium for browser-driven testing.
- SecLists, PayloadsAllTheThings, testssl.sh, jwt_tool, commix.

## Build

```bash
make build
# or
docker build -t runtime-base .
```

Metasploit is opt-in because it is large:

```bash
make build BUILD_ARGS="--build-arg INSTALL_METASPLOIT=true"
```

## Run

```bash
make shell    # interactive, privileged
```

The entrypoint starts an internal Docker daemon and then runs the command:

```bash
docker run --rm -it --privileged runtime-base bash
```

## Test

```bash
make test     # or: ./scripts/smoke-test.sh runtime-base:local
```

The GitHub Actions workflow builds, pushes, smoke-tests and verifies
Docker-in-Docker. Because this repository is public, Actions minutes are free.
