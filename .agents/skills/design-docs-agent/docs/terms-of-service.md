# Design Docs Agent Terms Of Service

This package is provided for internal The Reality Report workflows.

## Permitted Use

- Use this package to generate or update TRR design-docs content from
  article URLs, saved source bundles, HTML captures, and source inventories.
- Follow the package contracts in `SKILL.md`, `agents/openai.yaml`, and
  `contracts/`.

## Restrictions

- Do not treat internal pipeline skills as standalone public tools.
- Do not redefine workflow behavior in host wrappers or generated manifests.
- Do not fabricate source-faithful output when acquisition or fidelity
  verification failed.

## Ownership

All package code, prompts, contracts, and generated outputs remain subject to
The Reality Report repository ownership and access controls.

## Changes

Shared package behavior is versioned through the package release and roster
metadata. Host-specific manifests must stay aligned to the shared package.
