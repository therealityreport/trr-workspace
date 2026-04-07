#!/usr/bin/env python3
"""
nyt-interactive-scraper.py
──────────────────────────
Scrape NYT sitemaps for interactive / data-vis articles.

Discovery signals (combined with OR logic):
  1. URL path contains /interactive/
  2. news:keywords contains "vis-design" (NYT graphics desk editorial tag)

Three modes:
  --recent    News sitemap (rolling ~48h) — has titles, keywords, images.
  --vis       News sitemap filtered to ONLY vis-design tagged articles
              (catches data-vis pieces on non-/interactive/ URL paths too).
  --archive   Monthly sitemaps for a date range (URL-path only, no keywords).

Filters out election-results and polls boilerplate by default (--all to include).

Examples:
  python3 scripts/nyt-interactive-scraper.py --recent
  python3 scripts/nyt-interactive-scraper.py --vis
  python3 scripts/nyt-interactive-scraper.py --recent --tag vis-design
  python3 scripts/nyt-interactive-scraper.py --archive --start 2025-01 --end 2026-04
  python3 scripts/nyt-interactive-scraper.py --archive --start 2026-03 --json
"""

import argparse
import gzip
import json
import re
import sys
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime
from typing import Optional

# ── Namespaces used in NYT sitemaps ──────────────────────────────────────────
NS = {
    "sm": "http://www.sitemaps.org/schemas/sitemap/0.9",
    "news": "http://www.google.com/schemas/sitemap-news/0.9",
    "image": "http://www.google.com/schemas/sitemap-image/1.1",
}

# ── Boilerplate URL patterns to exclude ──────────────────────────────────────
BOILERPLATE_PATTERNS = [
    r"/elections/results",
    r"/polls/",
    r"/interactive/\d{4}/us/elections/",
    r"/interactive/polls/",
]

SITEMAP_INDEX_URL = "https://www.nytimes.com/sitemaps/new/sitemap.xml.gz"
NEWS_SITEMAP_URL = "https://www.nytimes.com/sitemaps/new/news.xml.gz"

# The NYT graphics desk applies this keyword to data-visualization articles.
VIS_DESIGN_TAG = "vis-design"


def fetch_xml(url: str) -> ET.Element:
    """Fetch a URL (handles .gz transparently) and return parsed XML root."""
    req = urllib.request.Request(url, headers={"Accept-Encoding": "gzip"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = resp.read()
    if url.endswith(".gz") or data[:2] == b"\x1f\x8b":
        data = gzip.decompress(data)
    return ET.fromstring(data)


def is_boilerplate(url: str) -> bool:
    return any(re.search(pat, url) for pat in BOILERPLATE_PATTERNS)


def is_interactive(url: str) -> bool:
    return "/interactive/" in url


def has_vis_design_tag(keywords: str) -> bool:
    """Check if 'vis-design' appears in a comma-separated keywords string."""
    return any(
        k.strip().lower() == VIS_DESIGN_TAG
        for k in keywords.split(",")
    )


def parse_news_entry(url_el) -> dict:
    """Extract all metadata from a news sitemap <url> element."""
    loc = url_el.findtext("sm:loc", "", NS)
    lastmod = url_el.findtext("sm:lastmod", "", NS)

    news_el = url_el.find("news:news", NS)
    title = ""
    keywords = ""
    pub_date = ""
    if news_el is not None:
        title = news_el.findtext("news:title", "", NS)
        keywords = news_el.findtext("news:keywords", "", NS)
        pub_date = news_el.findtext("news:publication_date", "", NS)

    image_el = url_el.find("image:image", NS)
    image_url = image_el.findtext("image:loc", "", NS) if image_el is not None else ""

    return {
        "url": loc,
        "title": title,
        "keywords": keywords,
        "published": pub_date,
        "lastmod": lastmod,
        "image": image_url,
        "vis_design": has_vis_design_tag(keywords),
        "interactive_url": is_interactive(loc),
    }


# ── Recent mode: news sitemap ────────────────────────────────────────────────

def scrape_recent(
    include_all: bool = False,
    tag_filter: Optional[str] = None,
) -> list[dict]:
    """Parse news.xml.gz for interactive articles and/or vis-design tagged articles.

    Selection logic (OR):
      - URL contains /interactive/
      - keywords contain vis-design
    If tag_filter is set, only return articles matching that keyword.
    """
    root = fetch_xml(NEWS_SITEMAP_URL)
    results = []

    for url_el in root.findall("sm:url", NS):
        entry = parse_news_entry(url_el)

        # Apply tag filter if specified (strict keyword match)
        if tag_filter:
            if not any(
                k.strip().lower() == tag_filter.lower()
                for k in entry["keywords"].split(",")
            ):
                continue
        else:
            # Default: match on /interactive/ URL OR vis-design keyword
            if not entry["interactive_url"] and not entry["vis_design"]:
                continue

        if not include_all and is_boilerplate(entry["url"]):
            continue

        results.append(entry)

    return results


# ── Vis-design mode: only vis-design tagged ──────────────────────────────────

def scrape_vis_design() -> list[dict]:
    """Parse news.xml.gz for articles tagged vis-design only."""
    root = fetch_xml(NEWS_SITEMAP_URL)
    results = []
    for url_el in root.findall("sm:url", NS):
        entry = parse_news_entry(url_el)
        if entry["vis_design"]:
            results.append(entry)
    return results


# ── Archive mode: monthly sitemaps ───────────────────────────────────────────

def get_monthly_sitemap_urls() -> list[tuple[str, str]]:
    """Fetch the sitemap index and return [(url, YYYY-MM), ...]."""
    root = fetch_xml(SITEMAP_INDEX_URL)
    entries = []
    for sm in root.findall("sm:sitemap", NS):
        loc = sm.findtext("sm:loc", "", NS)
        m = re.search(r"sitemap-(\d{4}-\d{2})\.xml", loc)
        if m:
            entries.append((loc, m.group(1)))
    return entries


def scrape_archive(
    start: str, end: str, include_all: bool = False
) -> list[dict]:
    """Fetch monthly sitemaps in [start, end] range and extract interactive URLs.

    Note: monthly sitemaps have no keyword metadata, so vis-design filtering
    is not possible here. Use --recent or --vis for keyword-based discovery.
    """
    all_sitemaps = get_monthly_sitemap_urls()

    filtered = [
        (url, ym)
        for url, ym in all_sitemaps
        if start <= ym <= end
    ]

    if not filtered:
        print(f"No sitemaps found in range {start} to {end}.", file=sys.stderr)
        print(f"Available: {sorted(ym for _, ym in all_sitemaps)[:10]}...", file=sys.stderr)
        return []

    print(f"Fetching {len(filtered)} monthly sitemap(s)...", file=sys.stderr)
    results = []

    for sitemap_url, ym in sorted(filtered, key=lambda x: x[1]):
        print(f"  {ym} ...", file=sys.stderr, end=" ", flush=True)
        try:
            root = fetch_xml(sitemap_url)
        except Exception as e:
            print(f"FAILED ({e})", file=sys.stderr)
            continue

        count = 0
        for url_el in root.findall("sm:url", NS):
            loc = url_el.findtext("sm:loc", "", NS)
            if not is_interactive(loc):
                continue
            if not include_all and is_boilerplate(loc):
                continue
            lastmod = url_el.findtext("sm:lastmod", "", NS)
            results.append({
                "url": loc,
                "lastmod": lastmod,
                "sitemap_month": ym,
            })
            count += 1
        print(f"{count} interactive articles", file=sys.stderr)

    return results


# ── Output formatting ────────────────────────────────────────────────────────

def print_results(results: list[dict], as_json: bool = False):
    if as_json:
        print(json.dumps(results, indent=2))
        return

    if not results:
        print("No articles found.")
        return

    for r in results:
        title = r.get("title", "")
        kw = r.get("keywords", "")
        date = r.get("published") or r.get("lastmod", "")
        url = r["url"]
        flags = []
        if r.get("vis_design"):
            flags.append("vis-design")
        if r.get("interactive_url"):
            flags.append("/interactive/")

        if title:
            print(f"\n  {title}")
        print(f"  {url}")
        if date:
            print(f"  Date: {date}")
        if flags:
            print(f"  Matched: {', '.join(flags)}")
        if kw:
            print(f"  Tags: {kw}")

    print(f"\n── Total: {len(results)} articles ──")


# ── CLI ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Scrape NYT sitemaps for interactive/data-vis articles."
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument(
        "--recent",
        action="store_true",
        help="News sitemap (~48h): /interactive/ URLs OR vis-design tagged.",
    )
    mode.add_argument(
        "--vis",
        action="store_true",
        help="News sitemap (~48h): ONLY vis-design tagged articles.",
    )
    mode.add_argument(
        "--archive",
        action="store_true",
        help="Monthly sitemaps for a date range (URL-path matching only).",
    )
    parser.add_argument(
        "--tag",
        metavar="KEYWORD",
        help="Filter --recent to only articles with this news:keywords value "
             "(e.g. --tag vis-design, --tag 'Climate').",
    )
    parser.add_argument(
        "--start",
        default="2024-01",
        help="Start month YYYY-MM for archive mode (default: 2024-01).",
    )
    parser.add_argument(
        "--end",
        default=datetime.now().strftime("%Y-%m"),
        help="End month YYYY-MM for archive mode (default: current month).",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Include election results / polls boilerplate.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output as JSON instead of human-readable text.",
    )
    parser.add_argument(
        "--urls-only",
        action="store_true",
        help="Print just the URLs, one per line.",
    )

    args = parser.parse_args()

    if args.vis:
        results = scrape_vis_design()
    elif args.recent:
        results = scrape_recent(include_all=args.all, tag_filter=args.tag)
    else:
        if args.tag:
            parser.error("--tag requires --recent (monthly sitemaps have no keywords)")
        results = scrape_archive(args.start, args.end, include_all=args.all)

    if args.urls_only:
        for r in results:
            print(r["url"])
    else:
        print_results(results, as_json=args.json)


if __name__ == "__main__":
    main()
