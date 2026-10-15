#!/usr/bin/env bash
# Go-based tools that Kali's repository does not package.
#
# Everything else the agent uses comes from apt: nuclei, subfinder, naabu,
# dnsx, katana, feroxbuster, dalfox and gowitness are Kali packages, and
# ProjectDiscovery's httpx is there as `httpx-toolkit` (symlinked to `httpx` in
# the Dockerfile, because the plain name belongs to the Python HTTP client).
set -euo pipefail

export GOPATH=/root/go
export GOBIN=/usr/local/bin
export GOFLAGS=-buildvcs=false
mkdir -p "$GOBIN" "$GOPATH"

tools=(
  github.com/projectdiscovery/tlsx/cmd/tlsx
  github.com/projectdiscovery/interactsh/cmd/interactsh-client
  github.com/lc/gau/v2/cmd/gau
  github.com/tomnomnom/waybackurls
  github.com/ropnop/kerbrute
)

for tool in "${tools[@]}"; do
  echo "==> go install ${tool}@latest"
  go install "${tool}@latest"
done

# Free the module/build caches; the compiled binaries are already in the image
# layer, and the build host (e.g. a GitHub runner) is tight on disk.
go clean -modcache
go clean -cache
