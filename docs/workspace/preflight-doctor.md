# Preflight Doctor Notes

`make preflight` runs `scripts/doctor.sh` before any workspace startup.

Preflight modes:
- `make preflight` is the default local developer gate. It still fails on Node baseline, policy drift, and Chrome DevTools MCP readiness; env-contract drift is auto-healed in-place and then re-checked.
- `make preflight-strict` enables `WORKSPACE_PREFLIGHT_STRICT=1` and fails on env-contract drift as well.
- `make env-contract` regenerates `docs/workspace/env-contract.md` directly when you want to refresh the contract without running the full preflight chain.

Node baseline behavior:
- Required local baseline is Node `24.x`.
- If current `node` is lower than `24`, doctor attempts an in-process auto-switch using `nvm`.
- Doctor reads workspace `/.nvmrc` first (currently `24`) and runs `nvm use --silent <target>`.
- If auto-switch fails or Node is still below `24`, preflight fails with explicit remediation commands.

Manual fallback:
```bash
source ~/.nvm/nvm.sh && nvm use 24
# if 24 is not installed yet:
source ~/.nvm/nvm.sh && nvm install 24
```

Interrupt diagnostics:
- Run `make preflight-diagnostics` to enable opt-in tracing for the full preflight chain.
- Diagnostics logs are written to `.logs/workspace/preflight-diagnostics/<timestamp>-preflight-<pid>.log`.
- The log records:
  - `session_start`
  - `phase_start`
  - `phase_end`
  - `signal_received`
  - `process_snapshot`
  - `exit`
- Each event includes the current script, phase, pid, ppid, pgid, sid, tty, pwd, and parent command.

Intentional interrupt reproduction:
```bash
WORKSPACE_PREFLIGHT_DIAGNOSTICS=1 make preflight &
job_pid=$!
sleep 2
pgid="$(ps -o pgid= -p "$job_pid" | awk '{$1=$1; print}')"
kill -INT "-$pgid"
wait "$job_pid"
```

Reading the log:
- `phase_start` and `phase_end` show which preflight phase was active and the child pid/elapsed time.
- `signal_received` shows which script observed the signal.
- `process_snapshot` is the key section for root cause:
  - it captures the current script pid,
  - the parent pid,
  - every process still attached to the same process group.
- If the snapshot shows `make` or a parent shell/task runner taking the signal first, the interrupt came from outside the repo scripts.
