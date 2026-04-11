---
name: validate-inputs
description: Validate the public design-docs-agent input contract, resolve source mode, and enforce paywall plus external-app preflight rules.
metadata:
  version: 1.0.0
---

# Validate Inputs

## Purpose

Run the canonical preflight gate for the shared Design Docs package. This skill
owns the public `sourceBundle` contract, mode detection, paywall enforcement,
and the entry assertions against the external TRR-APP contract.

## Use When

1. The orchestrator enters the `validation` phase.
2. A caller provides `articleUrl` and `sourceBundle` and the package must fail
   early on malformed or underspecified input.

## Do Not Use For

1. Extraction work after preflight has already passed.
2. Brand-tab synchronization or verification gates.

## Inputs

- `articleUrl`
- `sourceBundle`
- `contracts/source-bundle.schema.json`
- `contracts/publisher-policy.yaml`
- `contracts/external-app-contract.yaml`
- `TRR-APP/apps/web/src/lib/admin/design-docs-config.ts`
- `TRR-APP/apps/web/src/lib/admin/design-docs-pipeline-types.ts`

## Procedure

1. Require both `articleUrl` and `sourceBundle`.
2. Validate `sourceBundle` against `contracts/source-bundle.schema.json`.
3. Read `contracts/publisher-policy.yaml` and classify the source host as:
   - paywalled article source
   - allowed public supporting source
   - unknown host treated as paywalled
4. Resolve one orchestration mode:
   - `add-article`
   - `add-first-article`
   - `create-brand`
   - `update-article`
5. Resolve source mode per `references/source-html-modes.md`:
   - Mode A browser-save
   - Mode B view-source
   - merged Mode A + Mode B bundle
   - rendered bundle with companion assets
6. Record rendered-source authority and component-inventory authority from the
   supplied bundle fields before extraction starts.
7. Enforce paywall policy from `contracts/publisher-policy.yaml`.
   - Paywalled article sources require saved HTML.
   - Allowed public supporting sources may be fetched live.
   - Unknown article hosts are treated as paywalled by default.
8. Run the external-app preflight assertions described by
   `contracts/external-app-contract.yaml`.
9. Return the resolved mode, source-mode classification, authority notes, and
   any blocking input errors.

## Rule

Do not duplicate source-bundle shape, paywall domains, or external-app contract
details here. The contract files under `contracts/` are canonical.
