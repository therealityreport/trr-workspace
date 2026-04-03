# Pitfalls Research: Cloud-First / No-Docker Workspace Tooling

## Main Risks

- Replacing Docker assumptions with vague remote guidance that is not reproducible
- Accidentally steering validation toward shared production-like databases instead of isolated branches
- Leaving scripts and docs out of sync so developers still hit Docker expectations indirectly
- Overcorrecting and breaking legitimate local-infra workflows that still matter for special cases

## Prevention Strategy

- Every cloud-first recommendation must name the isolation boundary: branch, disposable project, or other non-production target
- Script defaults, docs, and doctor output must say the same thing
- Docker paths should stay available where necessary, but be labeled as opt-in
- Verification should include at least one real cloud-first path, not only docs updates

## Phase Placement

- Contract and docs alignment belongs first
- Script/default changes belong second
- Verification and adoption checks belong last
