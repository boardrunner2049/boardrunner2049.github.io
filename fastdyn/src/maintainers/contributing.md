# Contribute to the handbook

A useful contribution helps a reader complete an experiment or understand an important contract. Explain the question, the required setup, the action, the observable result, and the implementation boundary. Prefer one complete example over a list of features with no working path between them.

Handbook source changes belong in [boardrunner2049/boardrunner2049.github.io](https://github.com/boardrunner2049/boardrunner2049.github.io/tree/main/fastdyn/src), under `fastdyn/src/`. This repository builds the book with mdBook and publishes it at `/fastdyn/` as part of the project's GitHub Pages site.

## Contact

For questions about contributing to the FastDyn book, contact **Arslan Khan** at [arslankhan@psu.edu](mailto:arslankhan@psu.edu).

## Choose the right chapter

User workflows belong in getting started, instrumentation, devices, simulation, and analysis. Advanced execution mechanisms belong in advanced; API and extension contracts belong in extending and reference. Architectural explanations should identify component responsibilities and show how a decision affects execution. When a proposal becomes implemented, update its status, link the practical chapter, and move it out of Proposed extensions in `SUMMARY.md`. Keep an existing URL when it remains useful as design rationale.

Use the [source map](../reference/source-map.md) before adding a new page. It helps avoid creating a second explanation of an API that already has a natural home.

## Ground the claims

Read the current implementation and relevant tests, not only an older README. Add a short source guide with pinned links to the files that establish the chapter's contract. Use tests as evidence of what is asserted, and distinguish the existence of a test from a test result observed during the documentation change.

The core implementation baseline is `f9666d7f518c373e89831d8e14a6371a27fe6436`; the JIT patcher and manual inline lab use `5b8bf3ddb01d63a4d5f86701d358e390a950cb9c`. Automatic MMIO and related API additions were reviewed at `a38af408451394ea2f41be1e9cf1e96bc46c370f`. Supercache additionally records separate frontend/backend revisions. Preserve chapter-level pins when updating only part of the book. For a branch-only feature, name the branch, pin the revision, and state the prerequisites and validation level. For an implemented experiment, distinguish available commands from established correctness. For a proposal, describe intended semantics and the existing foundations without presenting an invented API as current functionality.

If code and earlier documentation disagree, document the behavior the inspected implementation provides and keep the explanation useful to the reader. A handbook chapter should not become an unrelated backlog of every issue found during inspection.

## Write examples that can be followed

State the working directory, required build options, firmware fixture, and expected output. Use the public CLI or API that the feature actually supports. Configuration fragments should identify the existing table they extend and any required surrounding configuration.

Do not transplant literal addresses into a different firmware image. Explain when symbol resolution, instruction validation, or layout checks must run again. Keep architecture-specific register and ABI assumptions explicit.

For source-code contributors, follow FastDyn's [coding conventions](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/CodingConventions.md). In particular, retain feature ownership: plugin policy stays with the plugin, reusable immutable facts can move into host analysis, and downstream orchestration stays with the downstream project.

## Explain fidelity and performance precisely

Describe the firmware boundary an experiment exercises. A sensor-publication hook, a peripheral register model, and hardware passthrough each answer different questions. State the actual input representation, time policy, and modeled state when they matter to the result.

A performance claim needs a baseline, completion condition, configuration, raw measurements, and a statement of the behavior preserved. Avoid universal speed, fidelity, architecture, or losslessness claims based on one configuration.

## Keep mdBook structure consistent

Begin a chapter with one H1 and use concise section headings beneath it. No YAML frontmatter is needed. Source files live under `fastdyn/src/`; mdBook settings live in `fastdyn/book.toml`.

Add a new page to `fastdyn/src/SUMMARY.md` exactly once. In that navigation file, part headings use a single `#`. Use the same list marker as the surrounding entries and a path relative to `fastdyn/src/`. The special part-heading convention in `SUMMARY.md` does not change the heading hierarchy inside a chapter.

Use relative `.md` links between book pages, with fragment anchors where necessary, and pinned URLs for implementation sources. For example, a page in `maintainers/` can link to `../reference/cli.md`. Let mdBook translate chapter links into output URLs. Add a term to the [glossary](../reference/glossary.md) when several chapters need the same definition.

Use language-tagged fences such as `bash`, `toml`, `python`, `c`, or `json` for examples. A schematic snippet should say so in the surrounding text. An expected-output block should identify which parts are stable and which depend on the run.

For visual changes, edit root `site-theme.css` for shared colors and fonts, and `fastdyn/theme/fastdyn.css` for the handbook's layout and component styling. Preserve the common BR mark, wordmark, and site navigation. The build regenerates `fastdyn/theme/site-theme.css` from the shared source; keep that ignored copy out of commits. Review the website and handbook together, including the default light palette, optional charcoal and peach dark themes, and Mermaid diagrams after a light/dark switch. The [publishing guide](publishing.md) explains how the shared design reaches the built site.

## Maintain the diagrams

The handbook currently contains six fenced Mermaid diagrams. They are built through `mdbook-mermaid`, so retain the `mermaid` fence and keep the diagram source with its chapter. The build installs the required generated JavaScript assets; contributors do not need to commit those assets.

Use diagrams when they explain a boundary, feedback loop, or branching workflow more clearly than prose. Keep each diagram focused and use short labels. Supporting details belong in the surrounding text. Tables work well for configuration fields, API mappings, and support differences.

A link checker cannot establish that a diagram is legible. Inspect the rendered diagram after editing it, including how labels fit in the narrow reading column.

## Build and review a contribution

Use **mdBook 0.5.4** and **mdbook-mermaid 0.17.1**. From the website repository root, the Linux setup and review path is:

```bash
./scripts/install-book-tools.sh
./scripts/build-site.sh
python3 -m http.server 8000 --directory _site
```

The installer writes the tools to `.tools/bin`, which the build script discovers automatically. Matching tools on `PATH` also work. On other platforms, install the pinned Cargo versions as described in [publishing](publishing.md).

Open [http://localhost:8000/fastdyn/](http://localhost:8000/fastdyn/). Check the changed chapter, its sidebar entry, local links and anchors, code blocks, tables, and diagrams. The build script runs `python3 scripts/check-site.py` against the assembled output; that command can also be rerun directly after a build.

The full-site preview includes the root landing page, blog, and shared assets. Check those surfaces when changing common navigation or the build. Keep generated `fastdyn/book/`, `_site/`, `.tools/`, and Mermaid JavaScript assets out of commits.

For runtime examples, state whether they were run and with which build. A successful documentation build or syntax check is useful evidence, but it is not a firmware integration test. Commit the source change and its validation record; the existing Pages workflow publishes the complete site after the change reaches `main`.
