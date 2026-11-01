#!/usr/bin/env python3
"""Builds the static site from src/ into the repository root.

Why a build step: the app and game names are still placeholders (trademark decision pending),
and every page shares the same head, header and footer. Names live once per language in
src/site.json; pages are plain HTML templates with {{placeholders}}.

Usage (from anywhere, standard library only):
    python3 -I tools/build.py          # write the pages
    python3 -I tools/build.py --check  # exit 1 if a generated page is out of date
"""

from __future__ import annotations

import argparse
import hashlib
import json
import posixpath
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
PLACEHOLDER = re.compile(r"\{\{\s*([a-zA-Z0-9_]+)\s*\}\}")
MAX_PASSES = 4  # values may contain placeholders (e.g. a title that names the app)


def load_site() -> dict:
    with (SRC / "site.json").open(encoding="utf-8") as handle:
        return json.load(handle)


def page_dir(out: str) -> str:
    """Directory part of an output path, '' for the root."""
    return posixpath.dirname(out)


def rel_link(from_out: str, to_out: str) -> str:
    """Relative URL from one generated page to another page's directory (or file).

    Directory index pages are linked as 'dir/' so GitHub Pages serves dir/index.html.
    """
    target_dir = page_dir(to_out)
    rel = posixpath.relpath(target_dir or ".", page_dir(from_out) or ".")
    if posixpath.basename(to_out) != "index.html":
        rel = posixpath.join(rel, posixpath.basename(to_out))
        return rel if rel.startswith(".") else "./" + rel
    return "./" if rel == "." else rel + "/"


def root_prefix(out: str) -> str:
    depth = len([part for part in page_dir(out).split("/") if part])
    return "./" if depth == 0 else "../" * depth


def public_path(out: str) -> str:
    return "" if out == "index.html" else out.removesuffix("index.html")


def asset_version(relative: str) -> str:
    """Short content hash, appended as ?v= so browsers refetch a changed stylesheet."""
    return hashlib.sha256((ROOT / relative).read_bytes()).hexdigest()[:10]


def render(template: str, values: dict, source: str) -> str:
    text = template
    for _ in range(MAX_PASSES):
        missing = sorted({key for key in PLACEHOLDER.findall(text) if key not in values})
        if missing:
            raise SystemExit(f"{source}: unknown placeholder(s): {', '.join(missing)}")
        new_text = PLACEHOLDER.sub(lambda match: str(values[match.group(1)]), text)
        if new_text == text:
            return text
        text = new_text
    if PLACEHOLDER.search(text):
        raise SystemExit(f"{source}: placeholders nest too deeply")
    return text


def page_values(site: dict, page: dict, pages_by_id: dict) -> dict:
    lang = page["lang"]
    out = page["out"]
    strings = site["strings"][lang]
    values: dict = {}
    values.update(site["shared"])
    values.update(strings)
    values.update({
        "lang": lang,
        "root": root_prefix(out),
        "title": page["title"],
        "description": page["description"],
        "body_class": page.get("body_class", ""),
        "canonical": site["base_url"] + public_path(out),
        "og_image_url": site["base_url"] + strings["og_image"],
        "base_path": site["base_path"],
        "css_version": asset_version("assets/css/site.css"),
        "robots": page.get("robots", "index, follow"),
    })
    # Links to the main pages of this page's language.
    for key, page_id in site["links"][lang].items():
        values[key] = rel_link(out, pages_by_id[page_id]["out"])
    alternate = pages_by_id.get(page.get("alternate", ""))
    if alternate:
        alt_lang = alternate["lang"]
        values.update({
            "alt_href": rel_link(out, alternate["out"]),
            "alt_lang": alt_lang,
            "alt_label": site["strings"][alt_lang]["lang_name"],
            "alt_switch_label": strings["switch_to"],
        })
        tr_page = page if lang == "tr" else alternate
        en_page = page if lang == "en" else alternate
        values["hreflang"] = (
            f'<link rel="alternate" hreflang="tr" href="{site["base_url"]}{public_path(tr_page["out"])}">\n'
            f'<link rel="alternate" hreflang="en" href="{site["base_url"]}{public_path(en_page["out"])}">\n'
            f'<link rel="alternate" hreflang="x-default" href="{site["base_url"]}{public_path(tr_page["out"])}">'
        )
    return values


def build(check: bool) -> int:
    site = load_site()
    pages_by_id = {page["id"]: page for page in site["pages"]}
    stale: list[str] = []
    for page in site["pages"]:
        layout = (SRC / page["layout"]).read_text(encoding="utf-8")
        content = (SRC / page["src"]).read_text(encoding="utf-8")
        values = page_values(site, page, pages_by_id)
        values["content"] = render(content, values, page["src"]).strip()
        html = render(layout, values, page["layout"])
        html = "\n".join(line.rstrip() for line in html.splitlines()) + "\n"
        target = ROOT / page["out"]
        if check:
            if not target.exists() or target.read_text(encoding="utf-8") != html:
                stale.append(page["out"])
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(html, encoding="utf-8")
        print(f"wrote {page['out']}")

    sitemap = render((SRC / "sitemap.xml").read_text(encoding="utf-8"), {
        "urls": "\n".join(
            f"  <url><loc>{site['base_url']}{public_path(page['out'])}</loc><lastmod>{site['shared']['updated_iso']}</lastmod></url>"
            for page in site["pages"] if page.get("sitemap", True)
        )
    }, "sitemap.xml")
    robots = render((SRC / "robots.txt").read_text(encoding="utf-8"), {"base_url": site["base_url"]}, "robots.txt")
    for name, text in (("sitemap.xml", sitemap), ("robots.txt", robots)):
        target = ROOT / name
        if check:
            if not target.exists() or target.read_text(encoding="utf-8") != text:
                stale.append(name)
        else:
            target.write_text(text, encoding="utf-8")
            print(f"wrote {name}")

    if stale:
        print("out of date, run python3 -I tools/build.py: " + ", ".join(stale), file=sys.stderr)
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="only verify the generated files")
    return build(parser.parse_args().check)


if __name__ == "__main__":
    sys.exit(main())
