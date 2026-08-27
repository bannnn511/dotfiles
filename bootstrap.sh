#!/usr/bin/env bash
# Reproduce this development environment on Ubuntu/Debian Linux or macOS.
set -Eeuo pipefail

DOTFILES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_FILES_DIR="$DOTFILES_DIR/etc"
OS="$(uname -s)"

# Every command used by config.fish is installed here. Go and Node are included
# because the config conditionally adds their global binary/module paths.
COMMON_PACKAGES=(
  atuin
  bat
  eza
  fish
  fzf
  git
  git-delta
  go
  helix
  neovim
  node
  starship
  zoxide
)

APT_PACKAGES=(
  bat
  curl
  fish
  fzf
  git
  golang-go
  neovim
  nodejs
  npm
  openssh-server
  snapd
  xauth
  zoxide
)

SNAPS=(
  "helix --classic"
)

NPM_GLOBAL_PACKAGES=(
  # Example: typescript
)

have() { command -v "$1" >/dev/null 2>&1; }

install_homebrew() {
  if ! have brew; then
    echo "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

install_macos() {
  have curl || { echo "curl is required to install Homebrew" >&2; return 1; }
  install_homebrew
  brew update
  brew install "${COMMON_PACKAGES[@]}"
}

install_apt() {
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${APT_PACKAGES[@]}"
}

install_github_deb() {
  local command="$1" repo="$2" pattern="$3" api asset url tmp
  have "$command" && return 0

  api="https://api.github.com/repos/${repo}/releases/latest"
  asset="$(curl -fsSL "$api" | python3 -c '
import json, re, sys
pattern = sys.argv[1]
for asset in json.load(sys.stdin)["assets"]:
    if re.fullmatch(pattern, asset["name"]):
        print(asset["browser_download_url"])
        break
' "$pattern")"
  [[ -n "$asset" ]] || { echo "No matching release found for $repo" >&2; return 1; }
  url="$asset"
  tmp="$(mktemp --suffix=.deb)"
  curl -fsSL "$url" -o "$tmp"
  sudo apt-get install -y "$tmp"
  rm -f "$tmp"
}

install_snaps() {
  ((${#SNAPS[@]})) || return 0
  have snap || { echo "snapd is required for snap packages" >&2; return 1; }
  local snap_spec name args
  for snap_spec in "${SNAPS[@]}"; do
    # shellcheck disable=SC2206
    args=($snap_spec)
    name="${args[0]}"
    sudo snap list "$name" >/dev/null 2>&1 && continue
    sudo snap install "${args[@]}"
  done
}

install_linux_release_tools() {
  local deb_arch rust_arch asset tool version url tmp binary
  deb_arch="$(dpkg --print-architecture)"
  case "$deb_arch" in
    amd64) rust_arch="x86_64-unknown-linux-gnu" ;;
    arm64) rust_arch="aarch64-unknown-linux-gnu" ;;
    *) echo "Unsupported Linux architecture: $deb_arch" >&2; return 1 ;;
  esac

  # Not available in Ubuntu 22.04's repositories.
  install_github_deb delta dandavison/delta "git-delta_.*_${deb_arch}\\.deb"
  install_github_deb hx helix-editor/helix "helix_.*_${deb_arch}\\.deb"

  for tool in starship eza atuin; do
    have "$tool" && continue
    case "$tool" in
      starship)
        version="1.26.0"
        asset="starship-${rust_arch}.tar.gz"
        url="https://github.com/starship/starship/releases/download/v${version}/${asset}"
        ;;
      eza)
        version="0.23.5"
        asset="eza_${rust_arch}.tar.gz"
        url="https://github.com/eza-community/eza/releases/download/v${version}/${asset}"
        ;;
      atuin)
        version="18.20.1"
        asset="atuin-${rust_arch}.tar.gz"
        url="https://github.com/atuinsh/atuin/releases/download/v${version}/${asset}"
        ;;
    esac
    tmp="$(mktemp -d)"
    curl -fsSL "$url" | tar -xz -C "$tmp"
    binary="$(find "$tmp" -type f -name "$tool" -print -quit)"
    [[ -n "$binary" ]] || { echo "Could not find $tool in $asset" >&2; return 1; }
    sudo install -m 0755 "$binary" "/usr/local/bin/$tool"
    rm -rf "$tmp"
  done

  # Ubuntu packages bat as batcat.
  if ! have bat && have batcat; then
    sudo ln -sfn "$(command -v batcat)" /usr/local/bin/bat
  fi
}

install_linux() {
  if ! have apt-get; then
    echo "Only apt-based Linux distributions are currently supported." >&2
    return 1
  fi
  install_apt
  install_snaps
  install_linux_release_tools
}

install_npm_globals() {
  ((${#NPM_GLOBAL_PACKAGES[@]})) || return 0
  have npm || { echo "npm is required for global npm packages" >&2; return 1; }
  npm install --global "${NPM_GLOBAL_PACKAGES[@]}"
}

install_system_files() {
  [[ -d "$SYSTEM_FILES_DIR" ]] || return 0
  local file relative target
  while IFS= read -r -d '' file; do
    relative="${file#"$SYSTEM_FILES_DIR/"}"
    target="/$relative"
    sudo install -D -m 0644 "$file" "$target"
  done < <(find "$SYSTEM_FILES_DIR" -type f -print0)

  if have sshd; then
    sudo mkdir -p /run/sshd
    sudo sshd -t
    if have systemctl && systemctl list-unit-files ssh.service >/dev/null 2>&1; then
      sudo systemctl reload ssh.service 2>/dev/null || sudo systemctl restart ssh.service 2>/dev/null || true
    elif have service; then
      sudo service ssh reload 2>/dev/null || sudo service ssh restart 2>/dev/null || true
    fi
  fi
}

link_dotfiles() {
  local file relative target backup_timestamp
  backup_timestamp="$(date +%Y%m%d%H%M%S)"
  while IFS= read -r -d '' file; do
    relative="${file#"$DOTFILES_DIR/home/"}"
    target="$HOME/$relative"
    mkdir -p "$(dirname "$target")"
    if [[ -e "$target" && ! -L "$target" ]]; then
      mv "$target" "$target.pre-dotfiles.$backup_timestamp"
    fi
    ln -sfn "$file" "$target"
  done < <(find "$DOTFILES_DIR/home" -type f -print0)
}

main() {
  case "$OS" in
    Darwin) install_macos ;;
    Linux) install_linux ;;
    *) echo "Unsupported operating system: $OS" >&2; exit 1 ;;
  esac
  install_npm_globals
  install_system_files
  link_dotfiles
  echo "Environment setup complete on $OS."
}

main "$@"
