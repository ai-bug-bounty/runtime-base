#!/usr/bin/env bash
# Install Homebrew for the `ubuntu` user so the agent can add tools on demand.
set -euo pipefail

export NONINTERACTIVE=1

if [ ! -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# A small, broadly useful baseline. The agent can `brew install` more later.
brew install uv ripgrep bat fd fzf yq gh
brew cleanup -s
