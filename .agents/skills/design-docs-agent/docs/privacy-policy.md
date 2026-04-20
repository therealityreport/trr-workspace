# Design Docs Agent Privacy Policy

This package is an internal tooling package for The Reality Report.

## Scope

This package processes article URLs, caller-provided source bundles, locally
saved HTML captures, screenshots, and repository files in order to generate or
update TRR design-docs pages.

## Data Handling

- The package is intended for internal operator use.
- Inputs are limited to the article and source artifacts supplied by the
  operator or acquired through the package acquisition flow.
- The package does not define a separate analytics, tracking, or resale layer.
- Generated artifacts remain in the owning repository and local tool caches
  used by the active host.

## Host Services

Codex, Claude Code, browser tooling, and repository infrastructure may process
the files and commands needed to execute this package according to their own
platform policies.

## Contact

Questions about this package should be routed to The Reality Report
engineering team.
