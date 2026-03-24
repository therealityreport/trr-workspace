"""
Design System Extractor - Pre-processor
Fetches and cleans website data for Design System analysis
"""

import requests
from bs4 import BeautifulSoup
import re
from urllib.parse import urljoin, urlparse
import sys
import json
import warnings

# Suppress SSL warnings
warnings.filterwarnings("ignore", message="Unverified HTTPS request")


class DesignSystemExtractor:
    def __init__(self, url: str):
        self.url = url
        self.base_url = urlparse(url).netloc
        self.html_content = ""
        self.css_variables = {}
        self.fonts = []
        self.colors = set()
        self.classes = set()
        self.components = []
        self.images = []
        self.icons = []

    def fetch_html(self) -> str:
        """Fetch HTML from the URL"""
        try:
            response = requests.get(self.url, timeout=30, verify=False)
            response.raise_for_status()
            self.html_content = response.text
            return self.html_content
        except Exception as e:
            print(f"Error fetching HTML: {e}")
            return ""

    def sanitize_html(self, html: str) -> str:
        """
        Removes unnecessary elements from HTML.
        Keeps only structure and relevant classes.
        """
        soup = BeautifulSoup(html, "html.parser")

        # Remove heavy/useless elements
        for tag in soup.find_all(["svg", "script", "noscript", "iframe", "style"]):
            tag.decompose()

        # Remove base64 data
        for tag in soup.find_all(src=re.compile(r"^data:")):
            tag.decompose()

        # Keep only relevant structural elements
        keep_tags = {
            "html",
            "head",
            "body",
            "header",
            "footer",
            "main",
            "nav",
            "section",
            "article",
            "aside",
            "div",
            "span",
            "h1",
            "h2",
            "h3",
            "h4",
            "h5",
            "h6",
            "p",
            "a",
            "button",
            "ul",
            "ol",
            "li",
            "form",
            "input",
            "select",
            "textarea",
            "label",
            "img",
            "picture",
            "figure",
            "figcaption",
        }

        # Remove non-essential tags
        for tag in soup.find_all():
            if tag.name not in keep_tags:
                tag.unwrap()

        # Extract only relevant classes (potential components)
        component_patterns = [
            r"btn",
            r"button",
            r"card",
            r"nav",
            r"menu",
            r"header",
            r"footer",
            r"hero",
            r"section",
            r"container",
            r"grid",
            r"flex",
            r"wrapper",
            r"title",
            r"text",
            r"label",
            r"input",
            r"form",
            r"chip",
            r"badge",
            r"project",
            r"partner",
            r"service",
            r"award",
            r"number",
            r"stat",
        ]

        for tag in soup.find_all(class_=True):
            classes = tag.get("class", [])
            for cls in classes:
                if any(pattern in cls.lower() for pattern in component_patterns):
                    self.classes.add(cls)

        # Extract images
        for img in soup.find_all("img", src=True):
            src = img.get("src")
            if src and not str(src).startswith("data:"):
                self.images.append(urljoin(self.url, str(src)))

        # Extract CSS links
        css_links = []
        for link in soup.find_all("link", rel="stylesheet", href=True):
            href = link.get("href")
            if href:
                css_links.append(urljoin(self.url, str(href)))

        # Extract Google Fonts
        for link in soup.find_all("link", href=re.compile(r"fonts\.googleapis\.com")):
            href = link.get("href")
            if href:
                self.fonts.append(str(href))

        return str(soup)

    def extract_css_variables(self, css_url: str) -> dict:
        """
        Extracts only CSS variables from a stylesheet.
        Does not read the whole file — focuses on :root block.
        """
        try:
            response = requests.get(css_url, timeout=30)
            response.raise_for_status()
            css_content = response.text

            # Extract :root block
            root_match = re.search(r":root\s*\{([^}]+)\}", css_content, re.DOTALL)
            if root_match:
                root_content = root_match.group(1)

                # Extract CSS variables
                var_pattern = r"--([\w-]+)\s*:\s*([^;]+);"
                for match in re.finditer(var_pattern, root_content):
                    var_name = match.group(1)
                    var_value = match.group(2).strip()
                    self.css_variables[var_name] = var_value

                    # Collect colors
                    if "color" in var_name.lower() or self.is_color(var_value):
                        self.colors.add(var_value)

            # Extract @font-face
            font_face_pattern = r"@font-face\s*\{([^}]+)\}"
            for match in re.finditer(font_face_pattern, css_content, re.DOTALL):
                font_content = match.group(1)
                font_family = re.search(
                    r"font-family:\s*['\"]?([^'\";]+)['\"]?", font_content
                )
                if font_family:
                    self.fonts.append(font_family.group(1).strip())

            return self.css_variables

        except Exception as e:
            print(f"Error extracting CSS from {css_url}: {e}")
            return {}

    def is_color(self, value: str) -> bool:
        """Checks if a value is a color"""
        color_patterns = [r"^#[0-9A-Fa-f]{3,8}$", r"^rgb", r"^hsl", r"^rgba", r"^hsla"]
        return any(re.match(pattern, value) for pattern in color_patterns)

    def extract_tailwind_classes(self, html: str) -> dict:
        """
        Detects Tailwind patterns to infer design tokens
        """
        tokens = {"colors": [], "spacing": [], "typography": []}

        colors_set = set()
        spacing_set = set()
        typography_set = set()

        # Tailwind patterns
        color_pattern = r"bg-\[?#?[\w]+\]?|text-\[?#?[\w]+\]?|border-\[?#?[\w]+\]?"
        spacing_pattern = r"m[p]?[tblrxy]?-\d+|p[p]?[tblrxy]?-\d+|gap-\d+|w-\d+|h-\d+"
        typo_pattern = r"text-\d+|font-\w+|leading-\w+|tracking-\w+"

        for match in re.finditer(color_pattern, html):
            colors_set.add(match.group())

        for match in re.finditer(spacing_pattern, html):
            spacing_set.add(match.group())

        for match in re.finditer(typo_pattern, html):
            typography_set.add(match.group())

        tokens["colors"] = list(colors_set)
        tokens["spacing"] = list(spacing_set)
        tokens["typography"] = list(typography_set)

        return tokens

    def detect_components(self, html: str) -> list:
        """
        Detects UI components based on class name patterns
        """
        components = []
        soup = BeautifulSoup(html, "html.parser")

        # Detect buttons
        btn_patterns = ["btn", "button", "cta"]
        for pattern in btn_patterns:
            elements = soup.find_all(class_=re.compile(pattern, re.I))
            if elements:
                components.append(
                    {
                        "type": "button",
                        "count": len(elements),
                        "classes": list(
                            set(
                                el.get("class", [""])[0]
                                for el in elements
                                if el.get("class")
                            )
                        ),
                    }
                )

        # Detect cards
        card_patterns = ["card", "project", "partner", "service", "feature"]
        for pattern in card_patterns:
            elements = soup.find_all(class_=re.compile(pattern, re.I))
            if elements:
                components.append(
                    {
                        "type": "card",
                        "subtype": pattern,
                        "count": len(elements),
                        "classes": list(
                            set(
                                el.get("class", [""])[0]
                                for el in elements
                                if el.get("class")
                            )
                        ),
                    }
                )

        # Detect navigation
        nav_elements = soup.find_all(["nav", "header"])
        if nav_elements:
            components.append({"type": "navigation", "count": len(nav_elements)})

        # Detect forms
        form_elements = soup.find_all(["form", "input", "select", "textarea"])
        if form_elements:
            components.append({"type": "form", "elements": len(form_elements)})

        return components

    def process(self) -> dict:
        """
        Main processing flow
        """
        print(f"Processing: {self.url}")

        # Step 1: Fetch HTML
        print("|- Fetching HTML...")
        html = self.fetch_html()
        if not html:
            return {"error": "Failed to fetch HTML"}

        # Step 2: Sanitize HTML
        print("|- Sanitizing HTML...")
        clean_html = self.sanitize_html(html)

        # Step 3: Extract CSS links from clean HTML
        soup = BeautifulSoup(clean_html, "html.parser")
        css_links = []
        for link in soup.find_all("link", rel="stylesheet", href=True):
            href = link.get("href")
            if href and not str(href).startswith("data:"):
                css_links.append(urljoin(self.url, str(href)))

        print(f"|- Found {len(css_links)} CSS files")

        # Step 4: Extract CSS variables
        for css_url in css_links[:5]:  # Limit to 5 CSS files
            print(f"|- Extracting variables from: {css_url}")
            self.extract_css_variables(css_url)

        # Step 5: Detect Tailwind patterns
        print("|- Detecting Tailwind patterns...")
        tailwind_tokens = self.extract_tailwind_classes(clean_html)

        # Step 6: Detect components
        print("|- Detecting components...")
        components = self.detect_components(clean_html)

        # Step 7: Compile result
        result = {
            "url": self.url,
            "fonts": list(set(self.fonts))[:10],
            "css_variables": self.css_variables,
            "colors": list(self.colors)[:20],
            "classes": list(self.classes)[:50],
            "tailwind_tokens": tailwind_tokens,
            "components": components,
            "images": self.images[:10],
            "clean_html_snippet": clean_html[:50000],
        }

        print("Processing complete!")
        return result


def main():
    if len(sys.argv) < 2:
        print("Usage: python design_system_extractor.py <url>")
        sys.exit(1)

    url = sys.argv[1]
    extractor = DesignSystemExtractor(url)
    result = extractor.process()

    # Output JSON for the LLM — write to file to avoid encoding issues
    print("\n" + "=" * 50)
    print("DESIGN SYSTEM DATA (JSON)")
    print("=" * 50)

    # Write to JSON file
    with open("design_system_data.json", "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2, ensure_ascii=False)
    print(f"Data saved to: design_system_data.json")

    # Print summary
    print("\n=== SUMMARY ===")
    print(f"URL: {result.get('url', 'N/A')}")
    print(f"Fonts: {len(result.get('fonts', []))} found")
    print(f"CSS Variables: {len(result.get('css_variables', {}))} found")
    print(f"Colors: {len(result.get('colors', []))} found")
    print(f"Components: {len(result.get('components', []))} detected")
    print(f"Images: {len(result.get('images', []))} found")


if __name__ == "__main__":
    main()
