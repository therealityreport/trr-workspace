# 15-Section Taxonomy

Every Design Docs brand page uses the same 15 top-level sections:

1. Design Tokens
2. Primitives
3. Feedback & Overlays
4. Navigation
5. Data Display
6. Chart Types
7. Layout
8. Forms & Composition
9. Other Components
10. A/B Testing
11. Dev Stack
12. Social Media
13. Emails
14. Pages
15. Other Resources

## Cross-Population Rules

- New article extraction data must flow into the matching brand tabs through
  aggregation from `ARTICLES`, not through article-specific hardcoding.
- In `create-brand` mode, scaffold all 15 brand tabs immediately.
- In non-`create-brand` modes, create sub-pages lazily only when the extracted
  article introduces a newly qualifying component type.
- Empty sections should render the standard placeholder rather than bespoke copy.
- Section 11 is populated from publisher classification and tech detection.
- Section 14 is populated from article config data, not bespoke page logic.
