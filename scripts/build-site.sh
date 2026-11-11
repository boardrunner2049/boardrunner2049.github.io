#!/usr/bin/env bash
# Build the handbook and stage the complete BoardRunner Pages site.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
export PATH="$repo_root/.tools/bin:$PATH"

for tool in mdbook mdbook-mermaid python3; do
  if ! command -v "$tool" >/dev/null; then
    printf 'Missing %s. Run ./scripts/install-book-tools.sh or install the documented versions.\n' "$tool" >&2
    exit 1
  fi
done
if [[ "$(mdbook --version)" != "mdbook v0.5.4" || \
      "$(mdbook-mermaid --version)" != "mdbook-mermaid 0.17.1" ]]; then
  printf 'This book requires mdbook 0.5.4 and mdbook-mermaid 0.17.1.\n' >&2
  exit 1
fi

# These assets are generated from the pinned preprocessor, never a CDN.
# Recreate them so a local tool upgrade cannot leave an old renderer behind.
rm -f fastdyn/mermaid.min.js fastdyn/mermaid-init.js
cp site-theme.css fastdyn/theme/site-theme.css
mdbook-mermaid install fastdyn
mdbook build fastdyn

rm -rf -- "$repo_root/_site"
mkdir -p _site
cp index.html styles.css site-theme.css favicon.svg _site/
cp -R blog _site/blog
cp -R fastdyn/book _site/fastdyn
touch _site/.nojekyll

python3 scripts/check-site.py
printf '\nSite ready in _site/. Preview: python3 -m http.server 8000 --directory _site\n'
