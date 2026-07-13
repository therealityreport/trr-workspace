# Plan 003: Validate Getty prefetch tokens as UUIDs to close a filesystem path-traversal vector

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the next
> step. If anything in the "STOP conditions" section occurs, stop and report —
> do not improvise. When done, update the status row for this plan in
> `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: from `TRR-APP/`, run
> `git diff --stat 83778e5c..HEAD -- apps/web/src/lib/server/admin/getty-local-scrape.ts`
> If it changed since this plan was written, compare the "Current state"
> excerpts against live code before proceeding; on a mismatch, treat it as a
> STOP condition. If SHA `83778e5c` does not resolve, compare excerpts to live
> code by hand and note it in your report.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `83778e5c` (TRR-APP), 2026-07-06

## Why this matters

`getty-local-scrape.ts` reads, writes, and deletes files whose path is built by
interpolating a caller-supplied `token` into
`path.join(os.tmpdir(), "trr-getty-prefetch", ${token}.json)`. The token is
trimmed but never checked for `../` or path separators. Legitimate tokens are
always `randomUUID()` values, but two entry points accept an externally-supplied
token: `hydrateGettyPrefetchPayload` reads `getty_prefetch_token` straight from a
request JSON body, and `createGettyPrefetchJob` honors an optional
`options.prefetchToken`. Both are reachable from admin API routes
(`api/admin/trr-api/people/[personId]/refresh-images` and its `stream` variant,
and `api/admin/trr-api/bravotv/images/...`). Because `path.join` resolves `..`
segments, a token like `../../<something>` escapes the intended directory, giving
an authenticated admin the ability to read, overwrite, or delete arbitrary
`.json`-suffixed files on the server. It is admin-gated, so the blast radius is
limited to authenticated operators — but the repos are **public**, the fix is a
few lines, and input that flows from a request body into a filesystem path
should always be validated. A single shared guard removes the whole class.

## Current state

- `apps/web/src/lib/server/admin/getty-local-scrape.ts:10` — the base directory:

  ```ts
  const GETTY_PREFETCH_TMP_DIR = path.join(os.tmpdir(), "trr-getty-prefetch");
  ```

- Tokens are minted as UUIDs (`apps/web/src/lib/server/admin/getty-local-scrape.ts:2`
  imports `randomUUID`; line 699 and 772 mint them). The externally-influenced
  entry points:

  - `readGettyPrefetchPayload` (`getty-local-scrape.ts:707-719`):

    ```ts
    export const readGettyPrefetchPayload = async (token: string): Promise<GettyPrefetchState | null> => {
      const normalizedToken = token.trim();
      if (!normalizedToken) return null;
      try {
        const raw = await readFile(path.join(GETTY_PREFETCH_TMP_DIR, `${normalizedToken}.json`), "utf8");
        return JSON.parse(raw) as GettyPrefetchState;
      } catch {
        return null;
      }
    };
    ```

  - `updateGettyPrefetchPayload` (`getty-local-scrape.ts:721-731`) — same
    `path.join(..., ${normalizedToken}.json)` for `writeFile`.
  - `createGettyPrefetchJob` (`getty-local-scrape.ts:761-778`) — uses
    `options?.prefetchToken` when provided: `const token = requestedToken || randomUUID();`
    then writes `path.join(GETTY_PREFETCH_TMP_DIR, ${token}.json)`.
  - `startGettyPrefetchJob` (~line 803) and `deleteGettyPrefetchPayload`
    (~line 929) — both build `path.join(GETTY_PREFETCH_TMP_DIR, ${normalizedToken}.json)`
    for read/`rm`.
  - `hydrateGettyPrefetchPayload` (`getty-local-scrape.ts:944-955`) reads the
    token from the request body and passes it on:

    ```ts
    const parsed = JSON.parse(rawBody) as Record<string, unknown>;
    const prefetchToken =
      typeof parsed.getty_prefetch_token === "string" ? parsed.getty_prefetch_token.trim() : "";
    if (!prefetchToken) { return rawBody; }
    // ... eventually reaches readGettyPrefetchPayload(prefetchToken)
    ```

- Reachable from (admin-gated) routes — confirmed importers:
  `apps/web/src/app/api/admin/trr-api/people/[personId]/refresh-images/route.ts`,
  `.../refresh-images/stream/route.ts`,
  `.../refresh-images/getty-enrichment/route.ts`,
  `apps/web/src/app/api/admin/trr-api/bravotv/images/people/[personId]/stream/route.ts`,
  `apps/web/src/app/api/admin/trr-api/bravotv/images/shows/[showId]/stream/route.ts`.

- **Convention**: server-only helpers under `apps/web/src/lib/server/admin/`
  (`shell-exec.ts` already uses `import "server-only"` and validates inputs
  before filesystem/exec use — mirror that validation posture). Tests live in
  `apps/web/tests/`; vitest is the runner. TypeScript strict.

## Commands you will need

Run from `TRR-APP/`.

| Purpose | Command | Expected on success |
|---|---|---|
| Typecheck | `pnpm -C apps/web run typecheck` | exit 0, no errors |
| New unit test (Step 3) | `pnpm -C apps/web exec vitest run tests/getty-prefetch-token.test.ts` | all pass |
| Lint | `pnpm -C apps/web run lint` | exit 0 |

## Scope

**In scope**:
- `apps/web/src/lib/server/admin/getty-local-scrape.ts` (add + apply a token guard)
- `apps/web/tests/getty-prefetch-token.test.ts` (create)

**Out of scope**:
- The admin route handlers themselves — they stay as-is; the guard belongs in
  the shared helper so every caller is covered.
- `shell-exec.ts` — related but separate (see backlog).
- Any change to the token *format* (keep `randomUUID`) or to the storage
  location.

## Git workflow

- Branch: `advisor/003-getty-prefetch-token-path-traversal`
- Conventional-commit messages (e.g. `fix(admin): reject non-UUID getty prefetch tokens`).
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Add a single token-validation helper

Near the top of `getty-local-scrape.ts` (after the imports / `GETTY_PREFETCH_TMP_DIR`
definition), add:

```ts
// Prefetch tokens are always randomUUID() values. Reject anything else so a
// request-supplied token can never traverse out of GETTY_PREFETCH_TMP_DIR.
const GETTY_PREFETCH_TOKEN_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const normalizeGettyPrefetchToken = (token: string): string | null => {
  const trimmed = token.trim();
  return GETTY_PREFETCH_TOKEN_RE.test(trimmed) ? trimmed : null;
};
```

**Verify**: `pnpm -C apps/web run typecheck` → exit 0.

### Step 2: Apply the guard at every token→path site

Replace each `const normalizedToken = token.trim();` (and the equivalent inline
trims) with the validated form, returning the function's existing "not found" /
no-op value on rejection so behavior for *valid* tokens is unchanged and invalid
tokens are treated as "no such payload":

- `readGettyPrefetchPayload`:
  ```ts
  const normalizedToken = normalizeGettyPrefetchToken(token);
  if (!normalizedToken) return null;
  ```
- `updateGettyPrefetchPayload`: same guard, `return null` on rejection.
- `deleteGettyPrefetchPayload`: same guard; return its existing no-op result on
  rejection (do not attempt the `rm`).
- `startGettyPrefetchJob`: this function **throws** on a bad token today
  (`throw new Error("Getty prefetch token is required.")` at ~line 791) — it has
  no null/not-found return branch. To preserve that fail-loud behavior, on an
  invalid token throw the same error type (its only caller always passes a
  post-guard UUID, so this is defense-in-depth and never fires in practice). Do
  **not** convert it to a silent null return.
- `createGettyPrefetchJob`: when `options?.prefetchToken` is provided, validate
  it; if it is non-empty **and** invalid, fall back to `randomUUID()` (do **not**
  write to a caller-controlled path). Keep the `requestedToken || randomUUID()`
  behavior but only accept `requestedToken` when it passes the guard:
  ```ts
  const requestedToken =
    typeof options?.prefetchToken === "string" ? normalizeGettyPrefetchToken(options.prefetchToken) : null;
  const token = requestedToken || randomUUID();
  ```
- `hydrateGettyPrefetchPayload`: it delegates to `readGettyPrefetchPayload`, which
  is now guarded — but also apply `normalizeGettyPrefetchToken` to the
  body-derived `prefetchToken` so an invalid token short-circuits to
  `return rawBody` (its existing "no token" branch) rather than reaching the
  filesystem at all.

Do not change any other logic (JSON parsing, state building, error handling).

**Verify**: `pnpm -C apps/web run typecheck` → exit 0; `pnpm -C apps/web run lint` → exit 0.

### Step 3: Add tests

Create `apps/web/tests/getty-prefetch-token.test.ts`. Model imports/structure on
an existing server-lib test in `apps/web/tests/` (e.g.
`tests/server-auth-adapter.test.ts` for the import style).

**Critical — make the tests actually discriminate the guard.** A plain
`expect(readGettyPrefetchPayload("../../evil")).toBe(null)` does NOT test the
fix: `readGettyPrefetchPayload` wraps its read in `try/catch → null`, so a
traversal token returns `null` whether or not the guard exists (the file just
doesn't exist → `readFile` throws → `null`). To prove the guard works you must
`vi.mock("node:fs/promises")` (or `vi.spyOn`) and assert the underlying
`readFile` was **never called** for an invalid token:

- Mock `node:fs/promises`. For a traversal token
  (`readGettyPrefetchPayload("../../evil")`), assert the result is `null` **and**
  `readFile` was not called (`expect(readFileMock).not.toHaveBeenCalled()`). This
  is the assertion that fails without the guard and passes with it.
- Repeat for a second invalid shape (e.g. `"../secret"`, `"a/b"`, or a non-UUID
  like `"not-a-uuid"`).
- For `createGettyPrefetchJob(..., { prefetchToken: "../evil" })`: note this
  function DOES write to disk (`mkdir` + `writeFile`), so mock `node:fs/promises`
  here too. Assert the resulting state's token is a fresh UUID (matches the UUID
  regex), not `"../evil"`, and that any `writeFile` path passed to the mock stays
  within the prefetch dir (assert the path does not contain `..`).
- Happy path: a valid UUID token is accepted — with `node:fs/promises` mocked so
  `readFile` returns a JSON payload, assert `readGettyPrefetchPayload(<uuid>)`
  parses and returns it (proves the guard does not reject legitimate tokens).

Do NOT write these tests against the real filesystem — `GETTY_PREFETCH_TMP_DIR`
is a fixed module constant (`os.tmpdir()/trr-getty-prefetch`) with no injection
point, so a real-FS test would touch a shared directory and race other runs.
Mock `node:fs/promises`. (`normalizeGettyPrefetchToken` is module-internal and
not exported, so it can only be exercised through the public functions above —
that is intended; do not export it just to test it.)

**Verify**: `pnpm -C apps/web exec vitest run tests/getty-prefetch-token.test.ts` → all pass, and confirm at least one test asserts `readFile`/`writeFile` was
not reached (or stayed in-dir) for an invalid token.

### Step 4: Regression check

**Verify**: `pnpm -C apps/web run typecheck` → exit 0. Run any existing tests
that import the refresh-images routes if present:
`pnpm -C apps/web exec vitest run tests/ --run 2>/dev/null | tail -5` (or the
repo's `pnpm -C apps/web run test`) → no new failures.

## Test plan

- New tests in `apps/web/tests/getty-prefetch-token.test.ts`: valid-token happy
  path (or absent-valid-token null), and 2–3 traversal-rejection cases across
  `readGettyPrefetchPayload` and `createGettyPrefetchJob`.
- Structural pattern: `apps/web/tests/server-auth-adapter.test.ts`.
- Verification: Step 3 command passes with the new tests.

## Done criteria

ALL must hold:

- [ ] A single `normalizeGettyPrefetchToken` guard exists and is applied at every
      **caller-controlled** token→`path.join` site listed in Step 2
      (`readGettyPrefetchPayload`, `updateGettyPrefetchPayload`,
      `deleteGettyPrefetchPayload`, `startGettyPrefetchJob`,
      `createGettyPrefetchJob`'s `prefetchToken`, and `hydrateGettyPrefetchPayload`'s
      body token). The two sites that use a freshly-minted `randomUUID()` or a
      `.json`-filtered `readdir` entry are already safe and need no guard.
- [ ] `pnpm -C apps/web run typecheck` → exit 0
- [ ] `pnpm -C apps/web exec vitest run tests/getty-prefetch-token.test.ts` → all pass
- [ ] `pnpm -C apps/web run lint` → exit 0
- [ ] `git status` shows only the two in-scope files
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- The functions or `GETTY_PREFETCH_TMP_DIR` definition differ from the "Current
  state" excerpts (drift).
- A legitimate caller relies on a non-UUID token (e.g. some code passes a
  human-readable slug as `prefetchToken`) — the typecheck/tests will reveal it;
  report the caller rather than widening the regex.
- Applying the guard requires changing a route handler's contract — it should
  not; report why if it appears to.

## Maintenance notes

- Backlog follow-up: `shell-exec.ts` hardcodes developer-absolute
  `ALLOWED_DIRS` (`/Users/thomashulihan/Projects/TRR/...`), which makes the
  feature inert on deployed hosts and is a portability/security smell — its own
  small plan.
- A reviewer should confirm the regex is anchored (`^...$`) and case-insensitive,
  and that `createGettyPrefetchJob` *falls back to a fresh UUID* on an invalid
  requested token rather than throwing (so the happy path for callers that omit
  the token is unaffected).
- Because the repos are public, this file's fix should not include any example
  traversal path that resolves to a real sensitive location — the test strings
  above are inert placeholders; keep them that way.
