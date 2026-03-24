import requests
import re
import sys

if len(sys.argv) < 2:
    print("Usage: python extract_tokens.py <css_url>")
    sys.exit(1)

# Fetch CSS from the provided URL
css_url = sys.argv[1]
r = requests.get(css_url)
css = r.text

# Extract colors (hex)
colors = set(re.findall(r"#(?:[0-9a-fA-F]{3}){1,2}(?:[0-9a-fA-F]{2})?", css))
print("=== COLORS ===")
for c in sorted(colors)[:40]:
    print(c)

# Extract font families
fonts = list(set(re.findall(r'font-family:\s*([\'"]?)([^\'";,}]+)\1', css)))
print("\n=== FONTS ===")
for f in fonts[:10]:
    print(f[1].strip())

# Extract font sizes
font_sizes = set(re.findall(r"font-size:\s*([^;]+)", css))
print("\n=== FONT SIZES ===")
for fs in sorted(font_sizes)[:20]:
    print(fs.strip())

# Extract line heights
line_heights = set(re.findall(r"line-height:\s*([^;]+)", css))
print("\n=== LINE HEIGHTS ===")
for lh in sorted(line_heights)[:10]:
    print(lh.strip())

# Extract common class patterns
classes = set(re.findall(r"\.([a-zA-Z0-9_-]+)\s*\{", css))
print("\n=== COMPONENT CLASSES ===")
component_classes = [
    c
    for c in classes
    if any(
        x in c.lower()
        for x in [
            "btn",
            "button",
            "card",
            "nav",
            "header",
            "footer",
            "hero",
            "project",
            "text",
            "title",
        ]
    )
]
for c in sorted(component_classes)[:30]:
    print(c)
