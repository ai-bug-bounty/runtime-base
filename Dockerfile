# syntax=docker/dockerfile:1.7

###############################################################################
# web-security runtime — agent-friendly penetration-testing environment
#
# Design goals:
#   * the agent runs as an unprivileged `ubuntu` user (passwordless sudo)
#   * a wide, current pentest tool set comes from Kali's `kali-linux-headless`
#     instead of being assembled package by package
#   * the agent can still install whatever else it needs via apt or Homebrew
#   * a nested Docker daemon runs by default (`START_DOCKERD=1`), so the
#     container must be started with `--privileged` and a `/var/lib/docker`
#     volume (see README.md)
#   * browser automation (Playwright Chromium, agent-browser) and traffic
#     interception (mitmproxy with a pre-trusted CA) work out of the box
#
# Build:
#   docker build -t runtime-base .
#
# Base: `kalilinux/kali-rolling`, deliberately unpinned. Kali publishes only a
# rolling repository and no per-release or per-date snapshot we can pin to, so
# pinning the base tag would not pin the packages; the weekly CI rebuild (plus
# the on-push ones) keeps this image current instead. Pin by digest if you would
# rather have a frozen build.
###############################################################################

FROM kalilinux/kali-rolling

ARG TARGETARCH=amd64
ARG TZ=America/St_Johns

ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true \
    TZ=${TZ} \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    HOME=/home/ubuntu \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    NPM_CONFIG_MIN_RELEASE_AGE=7 \
    GOROOT=/usr/local/go \
    GOPATH=/home/ubuntu/go \
    GOFLAGS=-buildvcs=false \
    PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright \
    AGENT_BROWSER_EXECUTABLE_PATH=/opt/agent-browser-chromium \
    AGENT_BROWSER_CA_CERT=/home/ubuntu/.mitmproxy/mitmproxy-ca-cert.pem \
    NODE_EXTRA_CA_CERTS=/home/ubuntu/.mitmproxy/mitmproxy-ca-cert.pem \
    SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    START_DOCKERD=1 \
    PATH=/opt/venv/bin:/home/ubuntu/.local/bin:/home/ubuntu/go/bin:/usr/local/go/bin:/usr/local/bin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/usr/sbin:/usr/bin:/sbin:/bin

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ---------------------------------------------------------------------------
# 1. Kali's headless tool set, plus only what it does not carry
# ---------------------------------------------------------------------------
# `kali-linux-headless` is ~199 packages: scanners, exploitation, credentials,
# wordlists, Metasploit, mitmproxy, impacket, netexec, the ProjectDiscovery
# suite (as httpx-toolkit) and more. The extra list below is deliberately
# short: shell/OS utilities the metapackage omits, language runtimes, container
# tooling, the browser trust store, and the few tools Kali has but headless does
# not pull in (arjun, dirsearch, medusa).
RUN apt-get update \
 && apt-get -y install kali-linux-headless \
 && apt-get -y install --no-install-recommends \
      # shell / OS utilities the metapackage does not include
      curl wget ca-certificates gnupg git-crypt sudo locales tzdata man-db \
      unzip zip xz-utils p7zip-full bash-completion zsh vim less nano tmux \
      screen jq tree file procps htop lsof strace rsync shellcheck sqlite3 \
      socat netcat-openbsd tshark tcpdump tor sshpass \
      # runtimes and headers needed to build wheels/gems at runtime
      python3 python3-dev python3-venv python3-pip build-essential pkg-config \
      libssl-dev libffi-dev libxml2-dev libxslt1-dev zlib1g-dev libjpeg-dev \
      libpcap-dev ruby-full nodejs npm \
      # container tooling for the nested daemon. docker.io only *Recommends*
      # the CLI and we build with --no-install-recommends, so ask for it.
      # (Debian calls Compose 2 `docker-compose`.)
      docker.io docker-cli docker-compose \
      # certutil, so mitmproxy's CA can be trusted by Chromium/NSS
      libnss3-tools \
      # web/recon tools that live in Kali's repo but are *not* pulled in by
      # kali-linux-headless: the ProjectDiscovery suite (httpx is packaged as
      # httpx-toolkit, to keep the name clear of the Python HTTP client),
      # plus a few others
      nuclei subfinder httpx-toolkit naabu dnsx katana feroxbuster dalfox \
      gowitness testssl.sh seclists arjun dirsearch medusa \
 && rm -f /usr/lib/llvm-21/build/Release /usr/lib/llvm-21/build/Debug+Asserts \
 && ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime \
 && echo "${TZ}" > /etc/timezone \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# `llvm-21-dev` (pulled in by clang via the metapackage) ships Debian's
# recursive build-tree symlinks `build/Release -> ..` and
# `build/Debug+Asserts -> ..`. Any naive tree walk recurses forever, which
# breaks Metasploit's bootsnap path scanner (`msfconsole --version` died with
# ELOOP). Nothing needs a symlink that points at its own parent, so they go.

# Kali's `httpx` is ProjectDiscovery's httpx under the name `httpx-toolkit`
# (the plain name belongs to the Python HTTP client). Our venv installs the
# Python library, whose CLI would otherwise shadow it on PATH. Similarly,
# testssl.sh's package installs the command `testssl`.
RUN ln -sfn /usr/bin/httpx-toolkit /usr/local/bin/httpx \
 && ln -sfn /usr/bin/testssl /usr/local/bin/testssl.sh

# ---------------------------------------------------------------------------
# 2. The unprivileged agent user (Kali ships no desktop user to reuse)
# ---------------------------------------------------------------------------
RUN useradd --create-home --shell /bin/bash --uid 1000 ubuntu \
 && (getent group docker >/dev/null || groupadd docker) \
 && usermod -aG docker ubuntu \
 && echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ubuntu \
 && chmod 0440 /etc/sudoers.d/ubuntu \
 && mkdir -p /opt /workspace /home/ubuntu/.local/bin /home/ubuntu/go \
 && chown -R ubuntu:ubuntu /home/ubuntu /workspace \
 && printf '%s\n' \
      'export PATH="/opt/venv/bin:$HOME/.local/bin:$HOME/go/bin:/usr/local/go/bin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"' \
      'export PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright' \
      'export AGENT_BROWSER_EXECUTABLE_PATH=/opt/agent-browser-chromium' \
      'export AGENT_BROWSER_CA_CERT=$HOME/.mitmproxy/mitmproxy-ca-cert.pem' \
      'export NODE_EXTRA_CA_CERTS=$HOME/.mitmproxy/mitmproxy-ca-cert.pem' \
      'export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt' \
      'export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt' \
      'export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt' \
      'export GOROOT=/usr/local/go' \
      'export GOPATH=$HOME/go' \
      'export GOFLAGS=-buildvcs=false' \
      > /etc/profile.d/00-runtime-env.sh \
 && chmod 0644 /etc/profile.d/00-runtime-env.sh

# ---------------------------------------------------------------------------
# 3. Go toolchain (for the tools Kali does not package, and for the agent)
# ---------------------------------------------------------------------------
COPY scripts/install-go.sh /usr/local/bin/install-go.sh
RUN chmod +x /usr/local/bin/install-go.sh \
 && TARGETARCH="${TARGETARCH}" /usr/local/bin/install-go.sh

# ---------------------------------------------------------------------------
# 4. Python environment for the agents and pentest libraries (/opt/venv)
# ---------------------------------------------------------------------------
RUN python3 -m venv /opt/venv \
 && /opt/venv/bin/pip install --upgrade pip setuptools wheel

RUN --mount=type=cache,target=/home/ubuntu/.cache/pip \
    /opt/venv/bin/pip install \
      "pydantic-ai" \
      "requests" "httpx[http2]" "beautifulsoup4" "lxml" "html5lib" \
      "dnspython" "pyjwt" "pycryptodome" "paramiko" "python-nmap" \
      # no pwntools: its `unicorn` dependency has no Python 3.14 wheel
      "shodan" "censys" "scapy" "impacket" \
      "ldap3" "ldapdomaindump" "certipy-ad" "bloodhound" "pypykatz" \
      "pyyaml" "rich" "typer" "tenacity" "playwright"

RUN chown -R ubuntu:ubuntu /opt/venv \
 # `httpx` must be ProjectDiscovery's (Kali packages it as httpx-toolkit and we
 # symlink it): the Python library's console script would shadow it, because
 # /opt/venv/bin comes first on PATH.
 && rm -f /opt/venv/bin/httpx

# ---------------------------------------------------------------------------
# 5. mitmproxy's CA, generated and trusted system-wide and in the NSS database
# ---------------------------------------------------------------------------
COPY scripts/install-mitmproxy-ca.sh /usr/local/bin/install-mitmproxy-ca.sh
RUN chmod +x /usr/local/bin/install-mitmproxy-ca.sh \
 && /usr/local/bin/install-mitmproxy-ca.sh

# ---------------------------------------------------------------------------
# 6. Go tools Kali does not package (everything else comes from apt)
# ---------------------------------------------------------------------------
COPY scripts/install-go-tools.sh /usr/local/bin/install-go-tools.sh
RUN chmod +x /usr/local/bin/install-go-tools.sh \
 && /usr/local/bin/install-go-tools.sh

# ---------------------------------------------------------------------------
# 7. Chromium for Playwright + agent-browser
# ---------------------------------------------------------------------------
RUN apt-get update \
 && /opt/venv/bin/playwright install --with-deps chromium \
 && rm -rf /var/lib/apt/lists/* \
 && chown -R ubuntu:ubuntu /opt/ms-playwright

# agent-browser drives the Chromium installed above instead of downloading its
# own Chrome; the script points it at the headless-shell build and records the
# path in AGENT_BROWSER_EXECUTABLE_PATH.
COPY scripts/install-agent-browser.sh /usr/local/bin/install-agent-browser.sh
RUN chmod +x /usr/local/bin/install-agent-browser.sh \
 && /usr/local/bin/install-agent-browser.sh

# ---------------------------------------------------------------------------
# 8. Tools neither Kali nor the metapackage ships
# ---------------------------------------------------------------------------
COPY scripts/install-extras.sh /usr/local/bin/install-extras.sh
RUN chmod +x /usr/local/bin/install-extras.sh && /usr/local/bin/install-extras.sh

# ---------------------------------------------------------------------------
# 9. Wordlists, payloads and helper scripts Kali does not ship
# ---------------------------------------------------------------------------
COPY scripts/install-wordlists.sh /usr/local/bin/install-wordlists.sh
RUN chmod +x /usr/local/bin/install-wordlists.sh && /usr/local/bin/install-wordlists.sh

# ---------------------------------------------------------------------------
# 10. Homebrew — lets the agent install tools that are not in apt
# ---------------------------------------------------------------------------
COPY scripts/install-homebrew.sh /usr/local/bin/install-homebrew.sh
# Steps above run as root with HOME=/home/ubuntu, so pip/npm/go leave root-owned
# caches in the agent's home; hand it back before anything writes there as
# `ubuntu` (the Homebrew installer is the first thing that does).
RUN chown -R ubuntu:ubuntu /home/ubuntu \
 && chmod +x /usr/local/bin/install-homebrew.sh \
 && su - ubuntu -c 'install-homebrew.sh'

# …and once more at the very end, so the agent owns its whole home at runtime.
RUN chown -R ubuntu:ubuntu /home/ubuntu

# ---------------------------------------------------------------------------
# 11. Entrypoint (starts the nested Docker daemon) and default user
# ---------------------------------------------------------------------------
COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

USER ubuntu
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["bash"]
