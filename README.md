# BoardRunner website and the FastDyn Book

This repository publishes [boardrunner2049.github.io](https://boardrunner2049.github.io/). It contains the BoardRunner homepage, field-notes blog, and **[the FastDyn Book](https://boardrunner2049.github.io/fastdyn/)**. The book is a tab in the website navigation and is built from Markdown with mdBook.

## Repository layout

| Path | Purpose |
| --- | --- |
| `index.html`, `styles.css`, `favicon.svg` | BoardRunner homepage and website layout |
| `site-theme.css` | Shared colors and fonts for the website and book |
| `blog/` | Blog archive, posts, and RSS feed |
| `fastdyn/book.toml` | mdBook configuration |
| `fastdyn/src/` | All handbook chapters and `SUMMARY.md` navigation |
| `fastdyn/theme/` | Book navigation tabs, styling, and favicon |
| `scripts/` | Pinned tool installer, complete-site build, and rendered-link checks |
| `.github/workflows/pages.yml` | Build checks and GitHub Pages deployment |

The book has 39 pages in ten parts, covering installation, architecture, instrumentation, devices, simulation, analysis, extensions, proposed work, reference material, and maintenance. Its first edition was imported from [FastDyn-Book at `84d5fcb`](https://github.com/Arslan8/FastDyn-Book/commit/84d5fcb2d7b73fe111596deb3e8da2fdf5f83eb7); future handbook changes belong here. The implementation baseline and experimental-branch revisions are recorded in the chapters.

## Build and preview

On Linux x86_64, run from the repository root:

```bash
./scripts/install-book-tools.sh
./scripts/build-site.sh
python3 -m http.server 8000 --directory _site
```

Open [localhost:8000](http://localhost:8000/) for the website or [localhost:8000/fastdyn/](http://localhost:8000/fastdyn/) for the book.

The installer downloads mdBook **0.5.4** and mdbook-mermaid **0.17.1** from their official releases, verifies their SHA-256 checksums, and installs them in `.tools/bin`. On another platform, use Rust's Cargo:

```bash
cargo install mdbook --locked --version 0.5.4
cargo install mdbook-mermaid --locked --version 0.17.1
./scripts/build-site.sh
```

Matching tools on `PATH` also work. The build script generates Mermaid's JavaScript from the pinned preprocessor, builds the book, stages the homepage and blog alongside it in `_site`, and checks local links, anchors, and chapter coverage. Readers receive static files, including search and diagram support; no application server or external JavaScript CDN is required.

Generated `fastdyn/book/`, `_site/`, `.tools/`, and Mermaid assets are ignored by Git. The root homepage and blog can still be previewed directly with a simple HTTP server, but the book tab needs the complete build above.

## Update the handbook

Edit the Markdown in `fastdyn/src/`. Add or reorder pages in `fastdyn/src/SUMMARY.md`; mdBook part headings use a single `#`. Use relative `.md` links between chapters. The build rewrites these to HTML links.

Keep claims and examples tied to their inspected implementation revision. Distinguish current interfaces, experimental branches, and proposed extensions. Follow the handbook's [contribution guide](fastdyn/src/maintainers/contributing.md) and [publishing guide](fastdyn/src/maintainers/publishing.md).

After building, review the changed chapter, sidebar, tables, code blocks, and diagrams. Test search and the navigation tabs. A successful documentation build does not establish that a firmware experiment was rerun.

## Update the homepage or blog

The homepage and handbook share `site-theme.css` for their palette and typography. Change those values there; the build copies them into the book. Keep book-specific layout and component styling in `fastdyn/theme/fastdyn.css`. The generated `fastdyn/theme/site-theme.css` copy is ignored by Git.

Edit the relevant HTML and check technical claims against the source repositories. Keep conceptual examples labeled. The LibVIO excerpt on the homepage is attributed to its [API guide](https://github.com/boardrunner2049/LibVIO/blob/main/docs/API.md).

To add a blog post:

1. Copy `blog/virtual-io-at-the-boundary/index.html` to `blog/<new-slug>/index.html`. Update its title, description, date, text, section IDs, and sources. Preserve the header's FastDyn Book tab and the relative stylesheet and favicon paths.
2. Add a newest-first entry to `blog/index.html`.
3. Add an item to `blog/feed.xml` and update `lastBuildDate`.
4. Update the featured note in `index.html` when appropriate, then build and preview the whole site.

## Deploy

The existing GitHub Pages source is **GitHub Actions**. Push to `main` or dispatch `.github/workflows/pages.yml` to build and deploy the complete `_site` artifact. Pull requests build and validate the site without deploying it. The deployment job has `pages: write` and `id-token: write`; the build job has read-only repository access. Actions and book tools are pinned.

The one workflow owns both the root site and `/fastdyn/`. Keep them in the same artifact. Confirm the workflow completes and inspect the live page before reporting a published update.

The repository name `boardrunner2049.github.io` establishes the organization-root site URL. If the repository is recreated, select **GitHub Actions** under Settings → Pages before deploying.
