# syntax=docker/dockerfile:1.7

###############################################################################
# web-security runtime — agent-friendly penetration-testing environment
#
# Design goals:
#   * the AI agent runs as an unprivileged `ubuntu` user (passwordless sudo)
#   * the agent can install whatever it still needs via apt or Homebrew
#   * a nested Docker daemon is available for disposable tool/sandbox
#     containers (the container must be started with --privileged)
#   * common recon / web / credential / AD tooling and wordlists are baked in
#
# Build:
#   docker build -t web-security-runtime runtime/
#   docker build --build-arg INSTALL_METASPLOIT=true -t web-security-runtime runtime/
###############################################################################

FROM ubuntu:24.04

ARG TARGETARCH=amd64
ARG TZ=America/St_Johns
# Metasploit bundles its own Ruby/PostgreSQL stack and is large; opt in.
ARG INSTALL_METASPLOIT=false

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
    PATH=/opt/venv/bin:/home/ubuntu/.local/bin:/home/ubuntu/go/bin:/usr/local/go/bin:/usr/local/bin:/opt/metasploit-framework/bin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/usr/sbin:/usr/bin:/sbin:/bin

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ---------------------------------------------------------------------------
# 1. Base OS packages, toolchains and pentest CLI tools
# ---------------------------------------------------------------------------
# tshark's postinst asks whether non-superusers may capture packets; preseed it.
RUN echo "wireshark-common wireshark-common/install-setuid boolean false" | debconf-set-selections \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      # build / shell / general utilities
      build-essential pkg-config ca-certificates curl wget git git-crypt gnupg \
      unzip zip xz-utils p7zip-full sudo locales tzdata man-db bash-completion \
      zsh vim less nano tmux screen jq tree file procps htop lsof strace rsync \
      shellcheck sqlite3 socat netcat-openbsd \
      # networking / traffic / OSINT
      dnsutils whois traceroute iproute2 net-tools iputils-ping tcpdump tshark \
      proxychains4 openvpn tor sshpass libimage-exiftool-perl \
      # browser trust store (certutil, used by Chromium and agent-browser)
      libnss3-tools \
      # language runtimes
      python3 python3-pip python3-venv python3-dev pipx \
      ruby-full ruby-dev \
      nodejs npm \
      openjdk-17-jdk-headless \
      # container tooling (Docker-in-Docker)
      docker.io docker-compose-v2 \
      # recon / scanning
      nmap masscan nikto sqlmap whatweb gobuster ffuf wfuzz dirb \
      # credentials / SMB / LDAP / SNMP
      hydra medusa john hashcat smbclient ldap-utils nbtscan onesixtyone snmp sslscan \
      # service clients
      postgresql-client mariadb-client redis-tools \
      # python build dependencies
      libssl-dev libffi-dev libxml2-dev libxslt1-dev zlib1g-dev libjpeg-dev libpcap-dev \
 && ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime \
 && echo "${TZ}" > /etc/timezone \
 && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 2. Non-root user, sudo and a login-shell PATH for interactive use
# ---------------------------------------------------------------------------
RUN echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ubuntu \
 && chmod 0440 /etc/sudoers.d/ubuntu \
 && usermod -aG docker ubuntu \
 && mkdir -p /opt /workspace /home/ubuntu/.local/bin /home/ubuntu/go \
 && chown -R ubuntu:ubuntu /home/ubuntu /workspace \
 && printf '%s\n' \
      'export PATH="/opt/venv/bin:$HOME/.local/bin:$HOME/go/bin:/usr/local/go/bin:/opt/metasploit-framework/bin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"' \
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
# 3. Go toolchain (latest stable, arch aware)
# ---------------------------------------------------------------------------
COPY scripts/install-go.sh /usr/local/bin/install-go.sh
RUN chmod +x /usr/local/bin/install-go.sh \
 && TARGETARCH="${TARGETARCH}" /usr/local/bin/install-go.sh

# ---------------------------------------------------------------------------
# 4. Python environment for the agents and pentest libraries (/opt/venv)
# ---------------------------------------------------------------------------
RUN python3 -m venv /opt/venv \
 && /opt/venv/bin/pip install --upgrade pip setuptools wheel

RUN --mount=type=cache,target=/root/.cache/pip \
    /opt/venv/bin/pip install \
      "pydantic-ai" \
      "requests" "httpx[http2]" "beautifulsoup4" "lxml" "html5lib" \
      "dnspython" "pyjwt" "pycryptodome" "paramiko" "python-nmap" \
      "shodan" "censys" "scapy" "impacket" "pwntools" \
      "ldap3" "ldapdomaindump" "certipy-ad" "bloodhound" "pypykatz" \
      "pyyaml" "rich" "typer" "tenacity" "playwright"

RUN chown -R ubuntu:ubuntu /opt/venv

# ---------------------------------------------------------------------------
# 5. Python CLI tools, each isolated in its own pipx venv
# ---------------------------------------------------------------------------
COPY scripts/install-pipx-tools.sh /usr/local/bin/install-pipx-tools.sh
RUN chmod +x /usr/local/bin/install-pipx-tools.sh \
 && su - ubuntu -c 'install-pipx-tools.sh'

# mitmproxy creates its root CA on first use. Generate it at build time and
# trust it system-wide and in the user's NSS database, so traffic can be
# proxied through mitmproxy without TLS errors.
COPY scripts/install-mitmproxy-ca.sh /usr/local/bin/install-mitmproxy-ca.sh
RUN chmod +x /usr/local/bin/install-mitmproxy-ca.sh \
 && su - ubuntu -c 'install-mitmproxy-ca.sh'

# ---------------------------------------------------------------------------
# 6. Go-based recon/web tools
# ---------------------------------------------------------------------------
COPY scripts/install-go-tools.sh /usr/local/bin/install-go-tools.sh
RUN chmod +x /usr/local/bin/install-go-tools.sh \
 && /usr/local/bin/install-go-tools.sh

# ---------------------------------------------------------------------------
# 7. Chromium for Playwright (browser-driven web testing) + agent-browser
# ---------------------------------------------------------------------------
RUN /opt/venv/bin/playwright install --with-deps chromium \
 && chown -R ubuntu:ubuntu /opt/ms-playwright

# agent-browser reuses the Chromium installed above instead of downloading its
# own Chrome; the install script points it at the headless-shell build and
# records a stable path in AGENT_BROWSER_EXECUTABLE_PATH (see the ENV block).
COPY scripts/install-agent-browser.sh /usr/local/bin/install-agent-browser.sh
RUN chmod +x /usr/local/bin/install-agent-browser.sh \
 && su - ubuntu -c 'install-agent-browser.sh'

# ---------------------------------------------------------------------------
# 8. Extra tools that are not packaged by Ubuntu (wpscan, enum4linux-ng)
# ---------------------------------------------------------------------------
COPY scripts/install-extras.sh /usr/local/bin/install-extras.sh
RUN chmod +x /usr/local/bin/install-extras.sh && /usr/local/bin/install-extras.sh

# ---------------------------------------------------------------------------
# 9. Wordlists, payloads and helper scripts
# ---------------------------------------------------------------------------
COPY scripts/install-wordlists.sh /usr/local/bin/install-wordlists.sh
RUN chmod +x /usr/local/bin/install-wordlists.sh && /usr/local/bin/install-wordlists.sh

# ---------------------------------------------------------------------------
# 10. Homebrew — lets the agent install tools that are not in apt
# ---------------------------------------------------------------------------
COPY scripts/install-homebrew.sh /usr/local/bin/install-homebrew.sh
RUN chmod +x /usr/local/bin/install-homebrew.sh \
 && su - ubuntu -c 'install-homebrew.sh'

# ---------------------------------------------------------------------------
# 11. Optional: Metasploit Framework (nightly installer)
# ---------------------------------------------------------------------------
RUN if [ "${INSTALL_METASPLOIT}" = "true" ]; then \
      curl -fsSL \
        https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb \
        -o /tmp/msfinstall \
      && chmod +x /tmp/msfinstall \
      && /tmp/msfinstall \
      && rm -f /tmp/msfinstall; \
    else \
      echo "Skipping Metasploit (INSTALL_METASPLOIT=${INSTALL_METASPLOIT})"; \
    fi

# ---------------------------------------------------------------------------
# 12. Entrypoint (starts a nested Docker daemon) and default user
# ---------------------------------------------------------------------------
COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

USER ubuntu
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["bash"]
