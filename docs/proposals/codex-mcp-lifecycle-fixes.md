# Codex App-Server MCP Process Lifecycle Management
## Proposal for Upstream OpenAI Codex Team

**Date:** March 16, 2026  
**Category:** Process Lifecycle Management  
**Severity:** High  
**Status:** Proposal

---

## Executive Summary

The Codex app-server's MCP (Model Context Protocol) handling lacks explicit process lifecycle management for stdio MCP servers, resulting in persistent resource leaks. When threads terminate, MCP wrapper processes, Chrome instances, npm child processes, and ancillary daemons survive indefinitely, exhausing port ranges and consuming significant memory. The current safeguard—an orphan watchdog polling for PPID changes every 10 seconds—is insufficient for rapid lifecycle transitions and fails entirely when the app-server remains resident (as in the desktop application). This proposal describes five missing lifecycle features required to prevent resource exhaustion.

---

## Observed Evidence

Analysis of a production TRR workspace reveals systemic lifecycle management failures:

- **15 stale session environment files** (`codex-chrome-session-*.env`) with dead `WRAPPER_PID` values mapped to unreachable ports (9333–9348)
- **12 stale reserve files** containing dead process owner PIDs, blocking port allocation
- **12 stale chrome-agent pidfiles** with dead PIDs and endpoints unreachable on their assigned ports
- **Live orphan processes** observed for dead ports 9346–9348: wrapper scripts, npm exec processes, watchdog daemons, and telemetry collectors persisting after thread closure
- **Port exhaustion risk:** The configured range (9333–9399) provides only 67 ports; leaked sessions can exhaust this in a single work session

Validation note: when the compensating reaper is exercised inside Cowork-style mounted sandboxes, unlink operations may fail due to sandbox write restrictions on the mounted filesystem. That does not invalidate the stale-session detection or the process-lifecycle diagnosis; it only limits in-sandbox artifact removal during verification.

---

## Issue 1: MCP Disposal on Thread/Subagent Close

### Observed Symptom
Wrapper processes survive thread closure, leaving Chrome instances, npm exec processes, watchdog processes, and telemetry processes alive indefinitely. No automatic cleanup occurs when a Codex thread or subagent terminates.

### Reproduction Steps
1. Start a Codex thread with chrome-devtools-mcp configured
2. Use browser automation features to confirm the MCP is active
3. Close the thread or tab
4. Run `ps aux | grep codex-chrome-devtools-mcp.sh` — observe wrapper processes still running
5. Verify the corresponding port (e.g., 9346) is still bound and the Chrome instance still holds the user profile lock

### Root Cause Hypothesis
The Codex app-server closes the stdio pipes to the wrapper process but does not signal termination to the managed process tree. The wrapper's `cleanup()` function only triggers when:
1. A signal is delivered to the wrapper itself, or
2. The wrapper's orphan watchdog detects `PPID=1` (indicating the parent has exited)

In the desktop application context, the app-server remains resident, so `PPID=1` detection never fires. The wrapper has no other signal to exit cleanly.

### Evidence
- 15 session env files found in workspace with dead `WRAPPER_PID` values
- Wrapper script's cleanup function conditionally guarded by signal handlers and orphan detection
- Manual inspection of running processes confirms wrappers for ports 9346, 9347, 9348 remain active despite zero thread references

### Required Fix
When a thread, subagent, or conversation terminates, the Codex app-server must execute a guaranteed termination sequence:

1. Close stdin and stdout pipes to the wrapper process
2. Send `SIGTERM` to the wrapper's process group (to reach npm, Chrome, watchdog, and telemetry processes)
3. Wait up to 3 seconds for graceful shutdown
4. If any child processes remain, send `SIGKILL` to the process group
5. Update session registry to mark the MCP as disposed

### Acceptance Criteria
- After closing a thread, `pgrep -f codex-chrome-devtools-mcp.sh | grep <thread-id>` returns no results within 5 seconds
- No stale reserve files or pidfiles remain for the closed thread
- The port assigned to the wrapper is immediately available for reallocation

---

## Issue 2: Broken-Session Reaping (Health Check)

### Observed Symptom
If a browser URL endpoint (e.g., `http://127.0.0.1:9348/json/version`) becomes unreachable, the app-server continues holding references to the dead MCP instance, preventing reallocation of the port or recovery of the thread.

### Reproduction Steps
1. Start a Codex thread with chrome-devtools-mcp
2. Identify the assigned port from the session env file
3. Kill the Chrome process or wrapper without properly closing the thread (e.g., `killall chrome`)
4. Attempt a browser operation in the same or a new thread
5. Observe that the old port remains locked and unavailable, and no new wrapper is spawned

### Root Cause
The app-server lacks a health-check loop for managed stdio MCP servers. Once a wrapper is spawned and assigned, no periodic verification occurs that the server remains responsive or that its child browser is alive.

### Evidence
- Live wrapper processes found for ports 9346–9348 whose chrome-devtools endpoints returned connection refused errors
- Session env files persist with dead endpoints
- Manual `curl http://127.0.0.1:9348/json/version` from the workspace fails with "Connection refused," yet the app-server has not cleaned up

### Required Fix
Implement a health check mechanism in the app-server:

1. For each managed stdio MCP server, periodically (every 30 seconds) attempt a lightweight health probe
   - For chrome-devtools-mcp: `GET /json/version`
   - For other server types: a simple protocol echo or status endpoint
2. Track consecutive health check failures per server
3. After N consecutive failures (recommended: 3–4, representing 90–120 seconds of downtime), mark the server unhealthy
4. Dispose of unhealthy servers using the termination sequence from Issue 1
5. Log health check results for debugging and analytics

### Acceptance Criteria
- An MCP server whose child browser dies is automatically disposed and its port is freed within 2 minutes
- Health check failures are logged with timestamp, server ID, and error details
- A disposed server's session env and pidfiles are removed automatically

---

## Issue 3: Per-Thread Ownership Metadata

### Observed Symptom
Wrapper processes have no intrinsic knowledge of which Codex thread, conversation, or subagent owns them. Only the process's parent PID (PPID) is available, which becomes ambiguous when multiple threads share the same app-server parent process.

### Reproduction Steps
1. Start three separate Codex threads with chrome-devtools-mcp configured
2. From the wrapper's perspective (e.g., inside a wrapper diagnostic function), observe that all three have the same PPID (the app-server PID)
3. Attempt to correlate a wrapper to its owning thread using only PPID — the mapping is one-to-many and unresolvable

### Root Cause
The Codex app-server does not inject thread or session identity into the MCP server's environment variables. Currently, wrappers synthesize a pseudo-ID from PPID + port + timestamp, which is fragile and cannot be reversed reliably.

### Evidence
- Examined 15 session env files; none contain a `CODEX_THREAD_ID`, `CODEX_SESSION_ID`, or similar identifier
- Wrapper script generates internal pseudo-IDs from port arithmetic, making recovery and cleanup logic fragile
- Multiple wrappers cannot be conclusively mapped to their owning thread without external registry queries

### Required Fix
Before spawning a stdio MCP server, the app-server must inject two environment variables into the MCP process's environment:

1. **`CODEX_SESSION_ID`:** A stable, unique identifier for the app-server session (generated once at app startup, persists for the app's lifetime)
2. **`CODEX_THREAD_ID`:** A stable, unique identifier for the thread, subagent, or conversation, assigned at creation time and stable throughout its lifecycle

The MCP server (wrapper script) should log these values at startup for auditability:
```bash
echo "$(date) | Session: $CODEX_SESSION_ID | Thread: $CODEX_THREAD_ID | Port: $MCP_PORT" >> ~/.codex/mcp-lifecycle.log
```

### Acceptance Criteria
- `env | grep CODEX_THREAD_ID` executed in a running wrapper returns a non-empty, non-zero value
- `env | grep CODEX_SESSION_ID` returns the same value across all wrappers owned by the same app-server instance
- Each new thread generates a unique `CODEX_THREAD_ID`
- Session and thread IDs are persisted in the session env file for post-mortem analysis

---

## Issue 4: Session Close Hook

### Observed Symptom
Thread close, tab close, and subagent termination do not trigger explicit teardown procedures. Wrappers survive these lifecycle events and accumulate in the process table.

### Reproduction Steps
1. Start a Codex thread with chrome-devtools-mcp
2. Confirm the wrapper is running: `ps aux | grep codex-chrome-devtools-mcp.sh`
3. Close the tab or thread from the Codex UI
4. Re-run the ps command — the wrapper persists
5. Check the port: `lsof -i :9346` still shows the Chrome process bound to the port

### Root Cause
The app-server relies on stdio EOF (closing stdin/stdout) to signal the wrapper, but the wrapper's foreground npm exec process does not cleanly exit on stdin EOF. The npm process waits for the browser connection to close, which may never happen if the wrapper's cleanup logic is not triggered by a direct signal.

### Evidence
- Same evidence as Issue 1: 15 stale session env files with surviving wrappers
- Wrapper script's cleanup function is guarded by signal handlers and orphan detection; it does not activate on simple stdin EOF
- Manual testing shows wrapper persists after pipe closure

### Required Fix
The app-server must implement and invoke an explicit teardown hook at the following lifecycle events:

1. **Thread close:** When a user closes a conversation or thread
2. **Tab close:** When the Codex app tab is closed (for web-based clients) or when the conversation view is hidden
3. **Subagent termination:** When a subagent completes or is manually stopped
4. **MCP server rotation/replacement:** When the app-server decides to spawn a new MCP server instance to replace a live one

For each teardown event:
- Identify all MCP servers owned by the closing entity (using `CODEX_THREAD_ID` or `CODEX_SESSION_ID`)
- Execute the termination sequence from Issue 1 (SIGTERM → wait → SIGKILL)
- Remove session env files and pidfiles
- Update the MCP registry

### Acceptance Criteria
- No orphaned wrapper processes remain after any lifecycle event (thread close, tab close, subagent termination)
- All associated session files are removed within 1 second of teardown
- Ports are available for reallocation immediately after teardown
- Teardown operations are logged with timestamp and affected MCP server IDs

---

## Issue 5: MCP Registry Deduplication (Optional Enhancement)

### Observed Symptom
In some scenarios (subagent spawn, MCP server rotation, thread retry), Codex may start a fresh wrapper without checking whether the thread already owns a live instance of the same server type. This results in multiple wrapper instances and port allocations for a single thread.

### Reproduction Steps
1. Start a Codex thread with chrome-devtools-mcp
2. Trigger a subagent spawn or MCP server rotation within the same thread
3. Check `ps aux | grep codex-chrome-devtools-mcp.sh | grep <thread-id>` — observe two or more live wrappers
4. Check port bindings — multiple ports are allocated to the same thread

### Root Cause
The app-server's MCP registry lacks deduplication or reuse logic. When a new request requires an MCP server, the registry spawns a new instance without checking if the thread already owns a live, healthy instance of that server type.

### Evidence
- Multiple chrome-agent pidfiles found in workspace for sequential ports (e.g., 9346, 9347, 9348) with creation timestamps within seconds of each other, suggesting rapid wrapper spawning for the same thread
- Stale reserve files reference multiple dead PIDs, indicating multiple allocation attempts

### Required Fix
Before spawning a new stdio MCP server, the app-server must:

1. Query the MCP registry for existing live instances owned by the requesting thread
2. Filter by server type (e.g., chrome-devtools-mcp)
3. Perform a health check (Issue 2) on any candidates
4. If a healthy instance exists, reuse it instead of spawning a new one
5. Only spawn a new instance if no healthy candidate exists

The registry should maintain a per-thread, per-server-type map of live instances.

### Acceptance Criteria
- A thread never has more than one live instance of chrome-devtools-mcp at a time (barring intentional rotation)
- If a health check marks an instance unhealthy, a new instance is spawned only after the old one is disposed
- The MCP registry reuses healthy instances across multiple requests within the same thread
- Reuse events are logged and distinguishable from new spawn events

---

## Workarounds Currently Deployed

The TRR workspace implements several compensatory measures to mitigate resource leaks:

- **Orphan watchdog:** A polling daemon in the wrapper script that checks `PPID` every 10 seconds and calls `cleanup()` if the parent has changed or been reparented to init. Insufficient for fast lifecycle transitions and ineffective when the app-server remains resident.

- **Stale-session sweep on wrapper startup:** The wrapper script scans `/tmp/codex-*` for files referencing dead PIDs and removes them. A defensive measure but does not address live leaks.

- **Manual reaper script:** `codex-mcp-session-reaper.sh` runs periodically (typically via cron) to scan for dead ports, remove stale files, and kill orphaned processes. Requires external orchestration and introduces cleanup latency.

- **Port reservation with flock:** Session env files are protected by filesystem locks (`flock`) to prevent concurrent allocation of the same port. Prevents collisions but does not prevent exhaustion.

These workarounds do not address the root cause and introduce operational complexity. Implementation of Issues 1–4 would eliminate the need for these compensatory measures.

---

## Impact

### Port Exhaustion
The configured port range spans 9333–9399, providing only 67 available ports. A single work session generating multiple threads with uncleaned wrappers can exhaust this range within hours, making new threads unable to allocate ports and blocking user workflows.

### Resource Waste
Each leaked Chrome instance consumes 200–500 MB of physical RAM (depending on profile size and active tabs). Sixteen leaked instances—the count observed in this workspace—consume up to 8 GB of memory indefinitely.

### Profile Corruption
Stale Chrome instances hold filesystem locks on the user profile directory (typically `~/.codex/chrome-profiles/<thread-id>`). When a new thread attempts to start, Chrome may fail to acquire locks, resulting in profile corruption warnings or startup failures.

### Diagnostics Complexity
Operators and users lack visibility into which wrappers belong to which threads. Debugging requires manual correlation using process trees, ports, and timestamps. A centralized, queryable MCP registry with ownership metadata would dramatically improve diagnostics.

---

## Recommendations

1. **Implement Issues 1 and 4 first:** These address the core lifecycle management failure. They are high-impact, relatively straightforward, and eliminate the need for external workarounds.

2. **Implement Issue 2 concurrently:** Health checking is a low-cost addition that provides early detection of failed MCP servers and enables automatic recovery.

3. **Implement Issue 3 immediately:** Injecting `CODEX_THREAD_ID` and `CODEX_SESSION_ID` is a non-breaking change that vastly improves diagnostics and enables Issues 1, 2, 4, and 5.

4. **Implement Issue 5 as a follow-up:** Registry deduplication is an optimization that reduces port pressure and improves performance but is not critical for correctness.

5. **Deprecate external workarounds:** Once Issues 1–4 are in production, remove or disable the orphan watchdog, stale-session sweep, and cron-based reaper. Retain the manual reaper script as an emergency tool only.

---

## References

- **MCP Documentation:** [link to Codex MCP protocol specification]
- **Chrome DevTools Protocol:** https://chromedevtools.github.io/devtools-protocol/
- **TRR Workspace Evidence:** `/sessions/serene-loving-wozniak/mnt/thomashulihan/Projects/TRR/docs/proposals/` (original analysis and logs)

---

**Document Version:** 1.0  
**Last Updated:** March 16, 2026
