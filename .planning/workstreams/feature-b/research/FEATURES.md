# Feature Research: Cloud-First / No-Docker Workspace Tooling

## Table Stakes

- A documented no-Docker happy path for backend and schema validation
- Clear separation between normal cloud-first development and special-case local infra workflows
- Doctor/preflight output that explains when Docker is optional versus required
- Safe guidance for remote branch or disposable DB validation without risking shared production state

## Differentiators

- One obvious recommended path for milestone verification that does not require a running Docker daemon
- Workspace scripts that degrade gracefully when Docker is unavailable instead of treating that as a generic failure
- Shared handoffs and status notes that point to the same preferred validation flow

## Anti-Features

- Hidden Docker assumptions behind “default” commands
- Validation recipes that imply production/shared DB mutation is acceptable
- Multiple competing env contracts for the same remote DB workflow

## UX Implication For Developers

The ideal experience is:
1. Start workspace in cloud-first mode
2. Run backend/app checks against remote services or branch credentials
3. Use Docker only when a clearly labeled local-infra case requires it
