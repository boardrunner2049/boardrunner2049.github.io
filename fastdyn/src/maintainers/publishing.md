# Publish and maintain the book

The FastDyn handbook is an mdBook published at [boardrunner2049.github.io/fastdyn/](https://boardrunner2049.github.io/fastdyn/) through GitHub Pages. Its source lives on the `main` branch of [boardrunner2049/boardrunner2049.github.io](https://github.com/boardrunner2049/boardrunner2049.github.io/tree/main/fastdyn/src). The same Pages deployment includes the project's landing page, blog, and shared assets.

## Repository layout

| Path | Purpose |
| --- | --- |
| `fastdyn/book.toml` | mdBook settings, source directory, renderer, and Mermaid preprocessor configuration |
| `fastdyn/src/index.md` | Handbook landing page |
| `fastdyn/src/SUMMARY.md` | Chapter order, nesting, and part headings |
| `fastdyn/src/<topic>/*.md` | Editable chapter sources |
| `fastdyn/book/` | Generated book output, ignored by Git |
| `site-theme.css` | Shared BoardRunner colors and fonts used by the website and handbook |
| `scripts/install-book-tools.sh` | Install the pinned Linux prebuilt tools under `.tools/bin` |
| `scripts/build-site.sh` | Build the handbook, assemble the complete `_site` tree, and validate it |
| `scripts/check-site.py` | Check rendered local links, anchors, and navigation |
| `.github/workflows/pages.yml` | Build and deploy the complete site from `main` |

Edit the Markdown under `fastdyn/src/`. Generated output and downloaded tools are build products. Commit source files and intentional build configuration changes; keep `fastdyn/book/`, `_site/`, `.tools/`, and generated Mermaid assets out of source commits.

The shared visual design belongs to root `site-theme.css`: the website's `styles.css` imports it, and the build copies it to ignored `fastdyn/theme/site-theme.css` for mdBook to load before `fastdyn/theme/fastdyn.css`. Edit and commit the shared source, never the generated copy. The handbook uses the same BR mark, wordmark, and site navigation. It defaults to the light palette even when the operating system prefers dark mode; manually selected dark themes use charcoal and peach. The custom `fastdyn/theme/mermaid-init.js` reads the CSS palette and uses Mermaid's base theme, refreshing diagrams when readers switch between light and dark palettes.

## Install the pinned tools

Run all commands in this chapter from the website repository root:

```bash
git clone https://github.com/boardrunner2049/boardrunner2049.github.io.git
cd boardrunner2049.github.io
```

The build uses **mdBook 0.5.4** and **mdbook-mermaid 0.17.1**. On the supported Linux host, install the prebuilt tools with:

```bash
./scripts/install-book-tools.sh
```

The installer places executables under `.tools/bin`. The build script discovers that location automatically. It can also use matching executables already available on `PATH`.

For a platform using a local Rust toolchain instead of the Linux prebuilt installer:

```bash
cargo install mdbook --locked --version 0.5.4
cargo install mdbook-mermaid --locked --version 0.17.1
```

Ensure Cargo's executable directory is on `PATH`. Keep both version pins aligned with the repository scripts when deliberately updating the toolchain. A local installation of a different mdBook version is not the same build environment as the Pages workflow.

## Build and preview the complete site

```bash
./scripts/build-site.sh
python3 -m http.server 8000 --directory _site
```

Open [http://localhost:8000/fastdyn/](http://localhost:8000/fastdyn/). The site root and blog are served by the same preview, so inspect those entry points when changing shared navigation or assets.

The build script runs `mdbook-mermaid install fastdyn` to materialize the ignored JavaScript assets required by the Mermaid renderer, then builds the book using `fastdyn/book.toml`. It stages the rendered handbook under `_site/fastdyn/` alongside the main site's files. This preserves the public `/fastdyn/` path while keeping the existing site content in the same deployment.

The current handbook contains six fenced Mermaid diagrams. Preview them in a browser after a renderer or diagram change; successful Markdown parsing alone does not establish that a diagram rendered correctly. The source remains in ordinary `mermaid` code fences, so the diagrams stay editable with their surrounding explanations.

The build also runs the rendered-site checker. To repeat that check against the existing `_site` tree:

```bash
python3 scripts/check-site.py
```

It checks local destinations, fragment anchors, and navigation. Browser review should additionally cover the landing page, sidebar groups, code blocks, tables, search, and diagrams. Follow at least one cross-chapter link and one pinned implementation-source link. Rebuild after editing a chapter; the simple HTTP server serves the files currently staged in `_site`.

## Maintain navigation and links

`fastdyn/src/SUMMARY.md` is mdBook's navigation source. A part title uses a **single `#`**, even though the file also commonly begins with `# Summary`:

```markdown
# Summary

[FastDyn](index.md)

# Architecture

* [The system model](architecture/system-model.md)
* [The execution pipeline](architecture/execution-pipeline.md)
```

Add each chapter once and point to its relative `.md` path. Links inside a chapter are relative to that chapter's directory. mdBook rewrites Markdown chapter links for the rendered site; keep source links as `.md` rather than hard-coding generated `.html` paths.

Each chapter begins with its own H1. YAML frontmatter is not needed. When moving a chapter or renaming a heading, update incoming links and rerun the rendered checker, including fragment links to the changed heading.

The syntax and build behavior follow the official [mdBook summary format](https://rust-lang.github.io/mdBook/format/summary.html) and [build-command documentation](https://rust-lang.github.io/mdBook/cli/build.html).

## Publish through the existing Pages workflow

Commit the reviewed source changes to `main`, or merge a documentation pull request into `main`. The existing `.github/workflows/pages.yml` workflow builds the whole `_site` tree, validates it, uploads that directory as the Pages artifact, and deploys it. The workflow can also be started manually through its dispatch trigger.

Use that single site workflow for handbook changes. It owns the root site and `/fastdyn/` together, so a book update must not publish only the book output over the site's root artifact.

Check the workflow result and then inspect the live `/fastdyn/` page. A successful source commit, a successful local build, and a completed Pages deployment are separate outcomes. Record the one actually observed when reporting a release.

## Updating the source baseline

Core chapters retain FastDyn baseline `f9666d7f518c373e89831d8e14a6371a27fe6436`; the Advanced section was reviewed at main `5b8bf3ddb01d63a4d5f86701d358e390a950cb9c`, with separate frontend/backend pins for Supercache. A baseline update should review the public APIs, configuration parser, build defaults, shipped examples, and tests before replacing source-link SHAs in bulk. Update the workflow's checkout instructions as well as its source links so readers do not run a newer feature from an older tutorial checkout.

Keep branch-preview evidence pinned to the revision that was inspected. When a branch is merged, check the resulting main implementation instead of assuming the earlier branch text is still exact. The [source map](../reference/source-map.md) identifies the original documentation and code locations behind each chapter.
