# Preflight Doctor Notes

`make preflight` runs `scripts/doctor.sh` before any workspace startup.

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
