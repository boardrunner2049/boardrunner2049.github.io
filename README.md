# BoardRunner website

Static, dependency-free site for the BoardRunner research and engineering effort. The landing page is in index.html, the blog archive is in blog/index.html, and individual posts live in blog/<slug>/index.html. Shared visual styles are in styles.css. The technical walkthrough is explicitly conceptual, while the configuration excerpt is from LibVIO's published API guide.

## Preview locally

From the repository root, run:

    python3 -m http.server 8000

Then open http://localhost:8000/. The site needs no build step or JavaScript. Assets use relative paths, so the same files work at an organization root or a project-site path.

## Updating content

Edit the relevant section of index.html and check claims against the current repositories before publishing. The most useful places to update are the component list, the interaction figure, and the getting-started links. Keep conceptual diagrams labeled as such. The only third-party technical excerpt on the site is attributed in its caption to [LibVIO's API guide](https://github.com/boardrunner2049/LibVIO/blob/main/docs/API.md); no external images or fonts are used.

Real artifacts that would strengthen a future evidence section include a documented end-to-end firmware trace, a screenshot or recording of a device model run, a reproducible configuration with firmware, and any published research. Add these only with source links and explanatory captions.

## Publishing a blog post

1. Copy blog/virtual-io-at-the-boundary/index.html to blog/<new-slug>/index.html. Update the title, description, heading, date, article text, section IDs, and source links. Keep the relative stylesheet and favicon paths at ../../styles.css and ../../favicon.svg.
2. Add a newest-first entry to blog/index.html. The archive is hand-maintained so it remains readable without JavaScript.
3. Add an item to blog/feed.xml and update lastBuildDate. RSS item links use this repository's current organization-root URL.
4. Update the featured note in index.html if the new post should appear on the home page. Preview all three pages locally, then push to main.

The first post is a technical explainer based on the public LibVIO documentation, not an announcement of a BoardRunner release. For later posts, distinguish documented software, conceptual examples, and project goals in the same way.

## Deployment

This repository is boardrunner2049/boardrunner2049.github.io, which is the required name for the organization root site at https://boardrunner2049.github.io/. A repository called boardrunner.github.io under the same organization would ordinarily publish at https://boardrunner2049.github.io/boardrunner.github.io/. Do not rename this repository for the root URL.

The workflow in .github/workflows/pages.yml deploys the repository root on pushes to main or manual dispatch. The Pages publishing source is configured as **GitHub Actions**. If this repository is recreated, verify that setting at https://github.com/boardrunner2049/boardrunner2049.github.io/settings/pages . The workflow uses only contents: read, pages: write, and id-token: write permissions. If the Pages environment has required reviewers, approve the deployment there.

The public BoardRunner and FastDyn repositories were empty when this content was prepared. That says only that no public implementation files were available to cite; it does not establish the status of the research system itself. The QEMU repository is described only as a fork because project-specific changes were not verified.
