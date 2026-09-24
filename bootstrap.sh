#!/usr/bin/env bash
# Install mise, then apply this repository's declarative machine setup.
set -Eeuo pipefail

DOTFILES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v mise >/dev/null 2>&1; then
  if ! command -v curl >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl
    else
      echo "curl is required to install mise" >&2
      exit 1
    fi
  fi

  curl -fsSL https://mise.run | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

mise trust "$DOTFILES_DIR/mise.toml"
exec mise -C "$DOTFILES_DIR" bootstrap "$@"
