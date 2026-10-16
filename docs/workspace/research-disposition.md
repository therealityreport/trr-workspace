# Retained research and historical artifacts

Disposition selected for this documentation packet: retain in place as
historical/research sources so existing references remain stable. These files
are not current runtime, deployment, installed-tool or implementation authority.
The canonical owner below is the responsible maintainer role for future review,
not a claim about the original author or receiver acceptance.

Source snapshot: 2026-10-04 working tree. The four root files and both research
trees were tracked and clean at inspection. Dates/provenance below come from
the artifacts themselves; missing provenance remains unknown.

| Retained path | Classification | Provenance and limits | Canonical review owner / current authority | Current source SHA-256 |
|---|---|---|---|---|
| [plan.md](../../plan.md) | Historical performance audit plan | Self-dated 2026-06-16; performance-audit proposal. Original author and acceptance history not established. | Workspace operations maintainer; current [commands](dev-commands.md) and [runtime authority](backend-runtime-ownership.md) | `42acb3544f1985b6169b3e0a12c7b89e146f8ed546d3a206d294b920b710a903` |
| [instagram-backfill-debug-report.md](../../instagram-backfill-debug-report.md) | Historical debugging report | Self-dated 2026-04-07; mentions revisions 4de3be8 and 2c7901a. Historical live-state claims not reverified. | Backend social maintainer; [social glossary](../../TRR-Backend/CONTEXT.md) and [runtime authority](backend-runtime-ownership.md) | `589eba90d84f68f1d0ac52cd61eb8e9dc992e1f16e2e5902d1b8f2c17fc8d238` |
| [claude-desktop-ui-mod-plan.html](../../claude-desktop-ui-mod-plan.html) | Tooling/design research | Footer says generated 2026-04-14 and unofficial. Generator, original author and acceptance unknown. | Workspace tooling maintainer; [tool inventory](../agent-governance/mcp_inventory.md) | `873f4549c4a248cac7407e9b4a40a003430558f3ed8ae6b5d4204264ef62408e` |
| [design-docs-agent-comparison.html](../../design-docs-agent-comparison.html) | Tooling/design research | Footer says generated 2026-04-15, version comparison. Generator and original author unknown. | Workspace tooling maintainer; [design routing](domain-routing.md) | `a25dd01409c1bdf2606f526ea6be82bef8cacf773ebc556a4fb603b48a8dcb1c` |
| [tool-finder-reddit-post-count](../../tool-finder-reddit-post-count/TOOLS.md) | Research shortlist tree | TOOLS.md describes Tool Finder candidates for Reddit post counting. Generation date, raw provider provenance and accepted integration unknown. | Backend social/Reddit maintainer; [Reddit router](../../TRR-Backend/api/routers/socials/reddit.py) | `8cd302c178698865a8f0b0c771fffe8b4f632709b838e4fe99520cb6e00fa1f3` |
| [tool-finder-reddit-post-count-pushshift](../../tool-finder-reddit-post-count-pushshift/TOOLS.md) | Research shortlist tree | TOOLS.md describes Pushshift/Arctic Shift count candidates. Generation date, raw provider provenance and accepted integration unknown. | Backend social/Reddit maintainer; [Reddit router](../../TRR-Backend/api/routers/socials/reddit.py) | `63f07e17af3ec46611b55bde67af67f79526a67ee0ad7630413d719ea39ee263` |

For a file the hash is SHA-256 of its bytes. For a tree it is SHA-256 of UTF-8
lines `relative/path<TAB>file_sha256<LF>` for all `git ls-files -- <tree>`
paths sorted lexically, using paths relative to the workspace root. The trees
contain 12 and 11 tracked files respectively. This fingerprints the source set;
it does not prove research claims or accepted integration.

## References and physical cleanup gates

The current [test skip inventory](test-skip-inventory.md) refers to root
`plan.md`; its reference and the original path are retained. Historical plans
and evidence also remain untouched. No source file is moved, deleted or rewritten
by this classification.

[Plan 019](../../plans/019-clean-tracked-root-artifacts.md) physical cleanup is
still open: retained classification does not satisfy its move/remove criteria.
Any later relocation or removal needs a fresh hash/reference review, a selected
receiver, receiver acceptance, matching destination bytes and a reversible
archive. Promoting research into durable guidance additionally requires current
source/provider evidence and review by the canonical owner above.

## Existing output ledger

[output-disposition.json](output-disposition.json) remains the authoritative
row-level classification for the 57 tracked legacy output items. This index
neither duplicates those rows nor changes their dispositions or hashes. The
items stay in place pending the ledger's receiver, destination-hash,
reference and coordination gates. Fixture/evidence acceptance remains
unresolved; new fixture/test assets are not authorized by this packet. No
physical output cleanup completion is claimed.
