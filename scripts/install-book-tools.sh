#!/usr/bin/env bash
# Install the exact Linux x86_64 releases used by the Pages workflow.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tool_dir="$repo_root/.tools/bin"

if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
  cat >&2 <<'EOF'
This installer supports Linux x86_64. On other platforms, install with Rust:
  cargo install mdbook --locked --version 0.5.4
  cargo install mdbook-mermaid --locked --version 0.17.1
Then run ./scripts/build-site.sh with those tools on PATH.
EOF
  exit 1
fi

download_dir="$(mktemp -d)"
trap 'rm -rf -- "$download_dir"' EXIT
mkdir -p "$tool_dir"

install_release() {
  local binary="$1" version="$2" repository="$3" checksum="$4"
  local archive="$download_dir/$binary.tar.gz"
  curl --fail --location --silent --show-error --retry 3 \
    "https://github.com/$repository/releases/download/v$version/$binary-v$version-x86_64-unknown-linux-gnu.tar.gz" \
    --output "$archive"
  printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check
  tar -xzf "$archive" -C "$tool_dir" "$binary"
}

install_release mdbook 0.5.4 rust-lang/mdBook \
  3f28de05dafca9d0f2eab99c662116b0e37b89b1d96a08f8f430b9eeae958cd7
install_release mdbook-mermaid 0.17.1 badboy/mdbook-mermaid \
  9afcfa5b8463afe606d48595a7ae338564302903e626ea5b6edb8007d29393a5

"$tool_dir/mdbook" --version
"$tool_dir/mdbook-mermaid" --version
