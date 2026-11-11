#!/usr/bin/env python3
"""Check the generated site's local links, assets, anchors, and chapter coverage."""

from html.parser import HTMLParser
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "_site"


class Page(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.ids = set()
        self.links = []
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if "id" in values:
            self.ids.add(values["id"])
        if tag == "a" and "name" in values:
            self.ids.add(values["name"])
        for key in ("href", "src"):
            if values.get(key):
                self.links.append(values[key])


def main():
    errors = []
    pages = {path.resolve(): Page(path.read_text()) for path in SITE.rglob("*.html")}
    for required in ("index.html", "blog/index.html", "fastdyn/index.html"):
        if not (SITE / required).is_file():
            errors.append(f"Missing site entry point: {required}")

    source = ROOT / "fastdyn/src"
    summary = (source / "SUMMARY.md").read_text()
    chapters = re.findall(r"\[[^\]]+\]\(([^)]+\.md)\)", summary)
    if len(chapters) != len(set(chapters)):
        errors.append("SUMMARY.md contains a chapter more than once")
    included = {source / chapter for chapter in chapters}
    actual = set(source.rglob("*.md")) - {source / "SUMMARY.md"}
    for missing in sorted(included - actual):
        errors.append(f"Missing chapter source: {missing.relative_to(source)}")
    for orphan in sorted(actual - included):
        errors.append(f"Chapter absent from SUMMARY.md: {orphan.relative_to(source)}")
    for chapter in chapters:
        path = Path(chapter)
        output = path.with_name("index.html") if path.name == "README.md" else path.with_suffix(".html")
        if not (SITE / "fastdyn" / output).is_file():
            errors.append(f"Missing rendered chapter: {output}")

    checked = 0
    for path, page in pages.items():
        for link in page.links:
            url = urlsplit(link)
            if url.scheme or url.netloc:
                continue
            local_path = unquote(url.path)
            if local_path.startswith("/"):
                target = SITE / local_path.lstrip("/")
            else:
                target = path.parent / local_path if local_path else path
            target = target.resolve()
            if not target.is_relative_to(SITE):
                errors.append(f"{path.relative_to(SITE)}: link escapes site: {link}")
                continue
            if target.is_dir():
                target = target / "index.html"
            checked += 1
            if not target.is_file():
                errors.append(f"{path.relative_to(SITE)}: missing target: {link}")
            elif url.fragment and target in pages:
                fragment = unquote(url.fragment)
                if fragment not in pages[target].ids:
                    errors.append(f"{path.relative_to(SITE)}: missing anchor: {link}")

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print(f"Validated {len(chapters)} chapters, {len(pages)} HTML pages, and {checked} local links/assets.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
