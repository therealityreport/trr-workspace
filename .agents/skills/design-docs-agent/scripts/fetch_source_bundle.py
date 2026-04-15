#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path
from urllib.parse import urljoin, urlparse


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = PACKAGE_ROOT.parents[2]
SOURCE_BUNDLES_ROOT = PACKAGE_ROOT / "source-bundles"

HTML_MIN_BYTES = 10 * 1024
VISIBLE_TEXT_TARGET = 1500
VISIBLE_TEXT_BORDERLINE = 500

BLOCK_PATTERNS = [
    re.compile(pattern, re.IGNORECASE)
    for pattern in (
        r"subscribe to read",
        r"sign in to continue",
        r"log in to continue",
        r"access denied",
        r"create an account",
    )
]
ARTICLE_MARKER_PATTERNS = [
    re.compile(pattern, re.IGNORECASE)
    for pattern in (
        r"<article\b",
        r"<h1\b",
        r'"@type"\s*:\s*"(NewsArticle|Article)"',
        r'property=["\']og:type["\'][^>]*content=["\']article["\']',
        r"\bby\s+[A-Z][a-z]+",
        r"\b(?:published|updated)\b",
    )
]
INTERACTIVE_MARKER_PATTERNS = [
    re.compile(pattern, re.IGNORECASE)
    for pattern in (
        r"<svg\b",
        r"<canvas\b",
        r"<iframe\b",
        r"\bd3[\.-]",
        r"\bchart\b",
        r"\bgraphic\b",
        r"\binteractive\b",
    )
]
PUBLISHER_PREFIXES = {
    "nytimes.com": "nyt",
    "theathletic.com": "athletic",
}


def host_matches(host: str, expected_domain: str) -> bool:
    return host == expected_domain or host.endswith(f".{expected_domain}")


def registrable_label(host: str) -> str:
    parts = [part for part in host.split(".") if part]
    if len(parts) >= 2:
        return parts[-2]
    return parts[0] if parts else "article"


def host_prefix(article_url: str) -> str:
    host = (urlparse(article_url).hostname or "").lower()
    for domain, prefix in PUBLISHER_PREFIXES.items():
        if host_matches(host, domain):
            return prefix
    return registrable_label(host)


def slugify(text: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return slug or "article"


def derive_bundle_slug(article_url: str, bundle_root: Path = SOURCE_BUNDLES_ROOT) -> str:
    parsed = urlparse(article_url)
    segments = [segment for segment in parsed.path.split("/") if segment]
    if segments and segments[-1].lower() == "index.html":
        segments = segments[:-1]
    if segments:
        tail = segments[-1]
    else:
        tail = registrable_label(parsed.hostname or "article")
    tail = tail.removesuffix(".html")
    year_match = re.search(r"/(19|20)\d{2}/", parsed.path)
    base = f"{host_prefix(article_url)}-{slugify(tail)}"
    if year_match:
        base = f"{base}-{year_match.group(0).strip('/')}"

    candidate = base
    suffix = 2
    while (bundle_root / candidate).exists():
        candidate = f"{base}-{suffix}"
        suffix += 1
    return candidate


def relative_to_repo(path: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(REPO_ROOT.resolve()).as_posix()
    except ValueError:
        return resolved.as_posix()


def strip_tags(html: str) -> str:
    cleaned = re.sub(r"(?is)<(script|style|noscript|template)[^>]*>.*?</\1>", " ", html)
    cleaned = re.sub(r"(?is)<svg[^>]*>.*?</svg>", " ", cleaned)
    cleaned = re.sub(r"(?s)<[^>]+>", " ", cleaned)
    cleaned = cleaned.replace("&nbsp;", " ")
    cleaned = re.sub(r"\s+", " ", cleaned)
    return cleaned.strip()


def assess_html_trustworthiness(html: str) -> dict:
    visible_text = strip_tags(html)
    normalized_text = re.sub(r"\s+", " ", visible_text).strip()
    compact_text_len = len(re.sub(r"\s+", "", normalized_text))
    html_bytes = len(html.encode("utf-8"))

    article_markers = [pattern.pattern for pattern in ARTICLE_MARKER_PATTERNS if pattern.search(html) or pattern.search(normalized_text)]
    interactive_markers = [pattern.pattern for pattern in INTERACTIVE_MARKER_PATTERNS if pattern.search(html)]
    blocked_patterns = [pattern.pattern for pattern in BLOCK_PATTERNS if pattern.search(normalized_text)]

    warnings: list[str] = []
    substantial_visible_text = compact_text_len >= VISIBLE_TEXT_TARGET
    borderline_visible_text = compact_text_len >= VISIBLE_TEXT_BORDERLINE
    has_content_markers = bool(article_markers or interactive_markers)

    if not substantial_visible_text and borderline_visible_text and has_content_markers:
        warnings.append("Visible text is below the preferred threshold but source markers are present.")

    blocked_without_recovery = bool(blocked_patterns) and not has_content_markers and compact_text_len < VISIBLE_TEXT_TARGET
    trustworthy = (
        html_bytes >= HTML_MIN_BYTES
        and has_content_markers
        and (substantial_visible_text or (borderline_visible_text and has_content_markers))
        and not blocked_without_recovery
    )

    if blocked_without_recovery:
        failure_reason = "server-side-paywall"
    else:
        failure_reason = "insufficient-article-content"

    return {
        "isTrustworthy": trustworthy,
        "htmlBytes": html_bytes,
        "visibleTextChars": compact_text_len,
        "articleMarkers": article_markers,
        "interactiveMarkers": interactive_markers,
        "blockedPatterns": blocked_patterns,
        "warnings": warnings,
        "failureReason": failure_reason,
    }


def should_capture_asset(asset_url: str, article_url: str) -> bool:
    asset_host = (urlparse(asset_url).hostname or "").lower()
    article_host = (urlparse(article_url).hostname or "").lower()
    if not asset_host or not article_host:
        return False
    if host_matches(asset_host, article_host):
        return True
    if registrable_label(asset_host) == registrable_label(article_host):
        return True
    if host_matches(article_host, "nytimes.com") and (asset_host.endswith(".nyt.com") or asset_host.endswith(".nytimes.com")):
        return True
    if host_matches(article_host, "theathletic.com") and asset_host.endswith(".theathletic.com"):
        return True
    return False


def extract_asset_urls(html: str, article_url: str) -> dict[str, list[str]]:
    css_urls: list[str] = []
    js_urls: list[str] = []
    for match in re.finditer(r"(?is)<link\b[^>]*rel=[\"'][^\"']*stylesheet[^\"']*[\"'][^>]*href=[\"']([^\"']+)[\"']", html):
        resolved = urljoin(article_url, match.group(1))
        if should_capture_asset(resolved, article_url):
            css_urls.append(resolved)
    for match in re.finditer(r"(?is)<script\b[^>]*src=[\"']([^\"']+)[\"']", html):
        resolved = urljoin(article_url, match.group(1))
        if should_capture_asset(resolved, article_url):
            js_urls.append(resolved)
    return {
        "css": list(dict.fromkeys(css_urls)),
        "js": list(dict.fromkeys(js_urls)),
    }


def safe_asset_name(asset_url: str, fallback_name: str, index: int) -> str:
    parsed = urlparse(asset_url)
    name = Path(parsed.path).name or fallback_name
    if "." not in name:
        name = f"{name}-{index}"
    return re.sub(r"[^A-Za-z0-9._-]+", "-", name)


def fetch_url_text(url: str) -> tuple[bool, str]:
    result = subprocess.run(
        ["curl", "-fsSL", url],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip() or f"curl exited {result.returncode}"
        return False, message
    return True, result.stdout


def fetch_asset_to_file(asset_url: str, destination: Path) -> bool:
    destination.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        ["curl", "-fsSL", asset_url, "-o", str(destination)],
        capture_output=True,
        text=True,
        check=False,
    )
    return result.returncode == 0 and destination.exists()


def persist_bundle_from_html(
    article_url: str,
    html: str,
    bundle_root: Path = SOURCE_BUNDLES_ROOT,
    *,
    fetch_assets: bool = True,
    screenshot_paths: list[Path] | None = None,
) -> dict:
    slug = derive_bundle_slug(article_url, bundle_root)
    bundle_dir = bundle_root / slug
    html_path = bundle_dir / "index.html"
    css_dir = bundle_dir / "assets" / "css"
    js_dir = bundle_dir / "assets" / "js"
    screenshot_dir = bundle_dir / "screenshots"

    html_path.parent.mkdir(parents=True, exist_ok=True)
    html_path.write_text(html)

    assets = extract_asset_urls(html, article_url)
    css_paths: list[str] = []
    js_paths: list[str] = []

    for index, asset_url in enumerate(assets["css"], start=1):
        destination = css_dir / safe_asset_name(asset_url, "style.css", index)
        if not fetch_assets:
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text("")
            css_paths.append(relative_to_repo(destination))
        elif fetch_asset_to_file(asset_url, destination):
            css_paths.append(relative_to_repo(destination))

    for index, asset_url in enumerate(assets["js"], start=1):
        destination = js_dir / safe_asset_name(asset_url, "script.js", index)
        if not fetch_assets:
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text("")
            js_paths.append(relative_to_repo(destination))
        elif fetch_asset_to_file(asset_url, destination):
            js_paths.append(relative_to_repo(destination))

    screenshot_bundle_paths: list[str] = []
    for screenshot_path in screenshot_paths or []:
        if not screenshot_path.exists():
            continue
        screenshot_dir.mkdir(parents=True, exist_ok=True)
        copied = screenshot_dir / screenshot_path.name
        shutil.copy2(screenshot_path, copied)
        screenshot_bundle_paths.append(relative_to_repo(copied))

    bundle = {
        "canonicalSourceUrl": article_url,
        "html": {"rendered": relative_to_repo(html_path)},
        "css": css_paths,
        "js": js_paths,
        "authoritativeViewport": "desktop",
    }
    if screenshot_bundle_paths:
        bundle["screenshots"] = {"desktop": screenshot_bundle_paths}
    return bundle


def build_acquisition_report(
    article_url: str,
    *,
    curl_attempted: bool,
    curl_succeeded: bool,
    curl_summary: str,
    browser_attempted: bool,
    browser_succeeded: bool,
    browser_summary: str,
    failure_reason: str,
    evidence: list[str],
) -> dict:
    return {
        "status": "needs-manual-bundle",
        "articleUrl": article_url,
        "attempts": {
            "curl": {
                "attempted": curl_attempted,
                "succeeded": curl_succeeded,
                "summary": curl_summary,
            },
            "browser": {
                "attempted": browser_attempted,
                "succeeded": browser_succeeded,
                "summary": browser_summary,
            },
        },
        "failureReason": failure_reason,
        "evidence": evidence,
        "nextAction": "Upload a saved source bundle manually so the pipeline can continue.",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Fetch and persist a Design Docs source bundle.")
    parser.add_argument("--article-url", required=True)
    parser.add_argument("--browser-html-file")
    parser.add_argument("--browser-screenshot", action="append", default=[])
    parser.add_argument("--bundle-root", default=str(SOURCE_BUNDLES_ROOT))
    args = parser.parse_args()

    bundle_root = Path(args.bundle_root)
    curl_ok, curl_payload = fetch_url_text(args.article_url)
    curl_summary = "curl fetch succeeded" if curl_ok else curl_payload
    browser_summary = "browser fallback not attempted"

    if curl_ok:
        assessment = assess_html_trustworthiness(curl_payload)
        if assessment["isTrustworthy"]:
            bundle = persist_bundle_from_html(args.article_url, curl_payload, bundle_root, fetch_assets=True)
            print(json.dumps({"status": "ok", "sourceBundle": bundle, "warnings": assessment["warnings"]}, indent=2))
            return 0
        curl_summary = (
            f"curl fetch recovered {assessment['visibleTextChars']} visible chars "
            f"with markers={len(assessment['articleMarkers']) + len(assessment['interactiveMarkers'])}"
        )
        evidence = [curl_summary]
    else:
        evidence = [curl_payload]
        assessment = {"failureReason": "server-side-paywall", "warnings": []}

    if args.browser_html_file and Path(args.browser_html_file).exists():
        browser_html = Path(args.browser_html_file).read_text()
        browser_assessment = assess_html_trustworthiness(browser_html)
        browser_summary = (
            f"browser capture recovered {browser_assessment['visibleTextChars']} visible chars "
            f"with markers={len(browser_assessment['articleMarkers']) + len(browser_assessment['interactiveMarkers'])}"
        )
        evidence.append(browser_summary)
        if browser_assessment["isTrustworthy"]:
            screenshot_paths = [Path(path) for path in args.browser_screenshot]
            bundle = persist_bundle_from_html(
                args.article_url,
                browser_html,
                bundle_root,
                fetch_assets=True,
                screenshot_paths=screenshot_paths,
            )
            print(json.dumps({"status": "ok", "sourceBundle": bundle, "warnings": browser_assessment["warnings"]}, indent=2))
            return 0
        assessment = browser_assessment
    elif args.browser_html_file:
        browser_summary = f"browser HTML file not found: {args.browser_html_file}"
        evidence.append(browser_summary)
        assessment = {"failureReason": "browser-unavailable", "warnings": []}
    else:
        evidence.append("Browser fallback not attempted.")

    failure_reason = assessment["failureReason"]
    if failure_reason == "server-side-paywall" and args.browser_html_file and Path(args.browser_html_file).exists():
        failure_reason = "popup-not-bypassable"

    report = build_acquisition_report(
        args.article_url,
        curl_attempted=True,
        curl_succeeded=curl_ok,
        curl_summary=curl_summary,
        browser_attempted=bool(args.browser_html_file),
        browser_succeeded=False,
        browser_summary=browser_summary,
        failure_reason=failure_reason,
        evidence=evidence,
    )
    print(json.dumps(report, indent=2))
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
