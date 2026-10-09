#!/usr/bin/env bash
# Install Go-based recon and web testing tools into /usr/local/bin.
set -euo pipefail

export GOPATH=/root/go
export GOBIN=/usr/local/bin
export GOFLAGS=-buildvcs=false
mkdir -p "$GOBIN" "$GOPATH"

tools=(
  github.com/projectdiscovery/nuclei/v3/cmd/nuclei
  github.com/projectdiscovery/httpx/cmd/httpx
  github.com/projectdiscovery/subfinder/v2/cmd/subfinder
  github.com/projectdiscovery/naabu/v2/cmd/naabu
  github.com/projectdiscovery/dnsx/cmd/dnsx
  github.com/projectdiscovery/katana/cmd/katana
  github.com/projectdiscovery/tlsx/cmd/tlsx
  github.com/projectdiscovery/interactsh/cmd/interactsh-client
  github.com/lc/gau/v2/cmd/gau
  github.com/hahwul/dalfox/v2
  github.com/tomnomnom/waybackurls
  github.com/ropnop/kerbrute
  github.com/sensepost/gowitness
)

for tool in "${tools[@]}"; do
  echo "==> go install ${tool}@latest"
  go install "${tool}@latest"
done

# Free the module/build caches; the compiled binaries are already in the image
# layer, and the build host (e.g. a GitHub runner) is tight on disk.
go clean -modcache
go clean -cache
