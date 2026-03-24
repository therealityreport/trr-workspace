# Design System Extractor - Tools

Python tools for pre-processing Design System data from websites.

## Files

- `design_system_extractor.py` - Main extraction script
- `extract_tokens.py` - Standalone CSS token extractor
- `requirements.txt` - Python dependencies

## Installation

```bash
pip install -r requirements.txt
```

## Usage

### Full site extraction
```bash
python design_system_extractor.py https://example.com
```

### CSS token extraction only
```bash
python extract_tokens.py https://example.com/path/to/styles.css
```

## Output

JSON with:
- CSS variables from `:root`
- Detected colors
- Google Fonts
- Mapped components
- Tailwind patterns
- Sanitized HTML snippet

## AI Integration

1. Run the Python script
2. Copy the returned JSON
3. Send it to the AI with the `design-system-extractor` skill
4. AI generates the `design_pattern.html`

## Why Python?

- Avoids truncation (LLMs have token limits)
- Faster (regex vs LLM parsing)
- Cheaper (fewer tokens = lower cost)
- Deterministic CSS extraction

## Location

These files are part of the `design-system-extractor` skill:
```
.agents/skills/design-system-extractor/tools/
```

Always use this path when running the scripts.
