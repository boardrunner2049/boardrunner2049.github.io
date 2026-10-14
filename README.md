# BoardRunner website

Static, dependency-free site for the BoardRunner research and engineering effort. The HTML content is in index.html; visual styles are in styles.css. The technical walkthrough is explicitly conceptual, while the configuration excerpt is from LibVIO's published API guide.

## Preview locally

From the repository root, run:

    python3 -m http.server 8000

Then open http://localhost:8000/. The site needs no build step or JavaScript. Assets use relative paths, so the same files work at an organization root or a project-site path.

## Updating content

Edit the relevant section of index.html and check claims against the current repositories before publishing. The most useful places to update are the component list, the interaction figure, and the getting-started links. Keep conceptual diagrams labeled as such. The only third-party technical excerpt on the site is attributed in its caption to [LibVIO's API guide](https://github.com/boardrunner2049/LibVIO/blob/main/docs/API.md); no external images or fonts are used.

Real artifacts that would strengthen a future evidence section include a documented end-to-end firmware trace, a screenshot or recording of a device model run, a reproducible configuration with firmware, and any published research. Add these only with source links and explanatory captions.

## Deployment

This repository is boardrunner2049/boardrunner2049.github.io, which is the required name for the organization root site at https://boardrunner2049.github.io/. A repository called boardrunner.github.io under the same organization would ordinarily publish at https://boardrunner2049.github.io/boardrunner.github.io/. Do not rename this repository for the root URL.

The workflow in .github/workflows/pages.yml deploys the repository root on pushes to main or manual dispatch. In repository **Settings → Pages**, set **Build and deployment → Source** to **GitHub Actions**: https://github.com/boardrunner2049/boardrunner2049.github.io/settings/pages . The workflow uses only contents: read, pages: write, and id-token: write permissions. If the Pages environment has required reviewers, approve the deployment there.

The public BoardRunner and FastDyn repositories were empty when this content was prepared. That says only that no public implementation files were available to cite; it does not establish the status of the research system itself. The QEMU repository is described only as a fork because project-specific changes were not verified.
