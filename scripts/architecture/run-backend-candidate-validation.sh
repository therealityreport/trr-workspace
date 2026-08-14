#!/usr/bin/env bash
# Canonical, non-mutating validation harness for the frozen backend tail batch.
set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly WORKSPACE_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
readonly CANDIDATE_ROOT="/private/tmp/trr-architecture-cleanup-stage4-gate4/TRR-Backend"
readonly CANDIDATE_PARENT="$(cd -- "$(dirname -- "$CANDIDATE_ROOT")" && pwd -P)"
readonly WORKSPACE_SCRIPTS_SOURCE="${WORKSPACE_ROOT}/scripts"
readonly WORKSPACE_DOCS_SOURCE="${WORKSPACE_ROOT}/docs"
readonly FROZEN_ROOT="/private/tmp/backend-ci-20-pyright.dASRVN"
readonly FROZEN_BASE="${FROZEN_ROOT}/base"
readonly FROZEN_PYTHON="${FROZEN_BASE}/bin/python"
readonly FROZEN_CONFIG="${FROZEN_ROOT}/config/pyrightconfig.json"
readonly UV_BIN="/Users/thomashulihan/.local/bin/uv"
readonly RUFF_BIN="/opt/homebrew/bin/ruff"
readonly CHANGED_PYTHON_PATHS=(
  "tests/integrations/test_media_watcher_sources.py"
  "trr_backend/integrations/nbcumv.py"
  "tests/services/test_cast_reference_builder.py"
  "trr_backend/services/cast_reference_builder.py"
  "trr_backend/vision/people_count_engine.py"
  "trr_backend/vision/screen_time_face_matching.py"
)

die() {
  printf 'validation wrapper error: %s\n' "$*" >&2
  exit 2
}

usage() {
  cat <<'USAGE'
Usage:
  run-backend-candidate-validation.sh env
  run-backend-candidate-validation.sh pyright --receipt /absolute/path.json -- path.py [path.py ...]
  run-backend-candidate-validation.sh pytest --receipt /absolute/path.txt -- pytest arguments...
  run-backend-candidate-validation.sh ruff --receipt /absolute/path.txt -- check path.py [path.py ...]
  run-backend-candidate-validation.sh ruff --receipt /absolute/path.txt -- format --check path.py [path.py ...]
  run-backend-candidate-validation.sh final-tail --receipt-dir /absolute/new-directory

Every receipt target must be new, outside both repositories, and have an
existing parent directory. The wrapper deliberately leaves pending evidence
files in that external directory instead of deleting anything.
USAGE
}

require_file() {
  [[ -f "$1" ]] || die "required file is unavailable: $1"
}

require_executable() {
  [[ -x "$1" ]] || die "required executable is unavailable: $1"
}

ensure_symlink() {
  local link_path="$1"
  local target_path="$2"

  if [[ -L "$link_path" ]]; then
    [[ "$(readlink -- "$link_path")" == "$target_path" ]] || \
      die "workspace scaffold symlink target drift: ${link_path}"
    return
  fi
  [[ ! -e "$link_path" ]] || die "workspace scaffold path is not an exact symlink: ${link_path}"
  ln -s -- "$target_path" "$link_path" || die "could not create workspace scaffold symlink: ${link_path}"
}

ensure_workspace_scaffold() {
  require_file "${WORKSPACE_SCRIPTS_SOURCE}/check-policy.sh"
  require_file "${WORKSPACE_DOCS_SOURCE}/workspace/shared-env-manifest.json"

  # The staging workspace already owns a small scripts/ subtree for its
  # external cookie fixture, so preserve it and link only the workspace
  # entrypoint required by the CI policy tests. Docs has no staged directory,
  # therefore the complete workspace docs tree can be linked atomically.
  ensure_symlink "${CANDIDATE_PARENT}/scripts/check-policy.sh" "${WORKSPACE_SCRIPTS_SOURCE}/check-policy.sh"
  ensure_symlink "${CANDIDATE_PARENT}/scripts/lib" "${WORKSPACE_SCRIPTS_SOURCE}/lib"
  ensure_symlink "${CANDIDATE_PARENT}/docs" "$WORKSPACE_DOCS_SOURCE"
}

activate_frozen_environment() {
  [[ -d "$CANDIDATE_ROOT" ]] || die "candidate root is unavailable: $CANDIDATE_ROOT"
  require_file "${FROZEN_BASE}/bin/activate"
  require_executable "$FROZEN_PYTHON"
  require_file "$FROZEN_CONFIG"
  require_executable "$UV_BIN"
  require_executable "$RUFF_BIN"

  # shellcheck source=/dev/null
  source "${FROZEN_BASE}/bin/activate"
  export PYTHONDONTWRITEBYTECODE=1
  export CI=1
  export GITHUB_ACTIONS=1
  unset TRR_TEST_DISABLE_DOTENV
  export PIP_DISABLE_PIP_VERSION_CHECK=1
}

run_pyright_tool() {
  "$UV_BIN" run --offline --isolated --no-project --python "$FROZEN_PYTHON" \
    --with "pyright==1.1.390" pyright "$@"
}

verify_environment() {
  local python_version
  local pyright_version
  local ruff_version

  python_version="$("$FROZEN_PYTHON" -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')"
  [[ "$python_version" == "3.11.9" ]] || die "expected Python 3.11.9, found ${python_version}"

  if ! pyright_version="$(run_pyright_tool --version 2>/dev/null | awk '
    $0 ~ /^pyright [0-9]+\.[0-9]+\.[0-9]+$/ { print; found = 1 }
    END { exit(found ? 0 : 1) }
  ')"; then
    die "unable to execute frozen Pyright version probe"
  fi
  [[ "$pyright_version" == "pyright 1.1.390" ]] || die "expected Pyright 1.1.390, found ${pyright_version}"

  ruff_version="$("$RUFF_BIN" --version)"
  [[ "$ruff_version" == "ruff 0.14.4" ]] || die "expected Ruff 0.14.4, found ${ruff_version}"

  "$FROZEN_PYTHON" - "$FROZEN_CONFIG" "$CANDIDATE_ROOT" <<'PY'
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
candidate_root = sys.argv[2]
config = json.loads(config_path.read_text(encoding="utf-8"))
if config.get("venvPath") != "/private/tmp/backend-ci-20-pyright.dASRVN":
    raise SystemExit("frozen Pyright config venvPath drift")
if config.get("venv") != "base":
    raise SystemExit("frozen Pyright config venv drift")
roots = [entry.get("root") for entry in config.get("executionEnvironments", [])]
if roots != [candidate_root]:
    raise SystemExit("frozen Pyright config execution-environment drift")
PY
}

canonical_external_path() {
  local requested="$1"
  local parent
  local leaf
  local canonical

  [[ "$requested" == /* ]] || die "receipt path must be absolute: ${requested}"
  parent="$(cd -- "$(dirname -- "$requested")" && pwd -P)" || die "receipt parent is unavailable: ${requested}"
  leaf="$(basename -- "$requested")"
  [[ -n "$leaf" && "$leaf" != "." && "$leaf" != "/" ]] || die "invalid receipt path: ${requested}"
  canonical="${parent}/${leaf}"

  case "$canonical" in
    "$WORKSPACE_ROOT"|"$WORKSPACE_ROOT"/*|"$CANDIDATE_ROOT"|"$CANDIDATE_ROOT"/*)
      die "receipt path must remain outside both repositories: ${canonical}"
      ;;
  esac

  printf '%s\n' "$canonical"
}

new_receipt_target() {
  local target
  target="$(canonical_external_path "$1")"
  [[ ! -e "$target" && ! -L "$target" ]] || die "receipt target already exists: ${target}"
  printf '%s\n' "$target"
}

new_pending_file() {
  local target="$1"
  local label="$2"
  local parent
  local leaf

  parent="$(dirname -- "$target")"
  leaf="$(basename -- "$target")"
  mktemp "${parent}/.${leaf}.${label}.pending.XXXXXX"
}

publish_receipt() {
  local pending="$1"
  local target="$2"

  [[ ! -e "$target" && ! -L "$target" ]] || die "receipt target already exists: ${target}"
  if ! ln "$pending" "$target"; then
    die "could not atomically publish receipt; pending evidence remains at ${pending}"
  fi
  printf 'published receipt: %s\n' "$target"
}

validate_text_receipt() {
  "$FROZEN_PYTHON" - "$1" <<'PY'
import sys
from pathlib import Path

payload = Path(sys.argv[1]).read_bytes()
if not payload:
    raise SystemExit("empty text receipt")
if b"\0" in payload:
    raise SystemExit("text receipt contains a NUL byte")
payload.decode("utf-8")
PY
}

validate_pyright_receipt() {
  "$FROZEN_PYTHON" - "$1" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
summary = payload.get("summary")
if payload.get("version") != "1.1.390":
    raise SystemExit(f"unexpected Pyright version: {payload.get('version')!r}")
if not isinstance(summary, dict):
    raise SystemExit("Pyright receipt has no summary object")
for key in ("filesAnalyzed", "errorCount", "warningCount", "informationCount"):
    if not isinstance(summary.get(key), int):
        raise SystemExit(f"Pyright receipt summary is missing integer {key}")
PY
}

show_failure_tail() {
  local receipt="$1"
  printf 'last receipt lines (%s):\n' "$receipt" >&2
  tail -n 80 "$receipt" >&2 || true
}

run_text_receipt() {
  local target="$1"
  shift
  local pending
  local exit_code

  pending="$(new_pending_file "$target" "stdout")"
  if (cd -- "$CANDIDATE_ROOT" && "$@") >"$pending" 2>&1; then
    exit_code=0
  else
    exit_code=$?
  fi

  if ! validate_text_receipt "$pending"; then
    die "text receipt parsing failed; pending evidence remains at ${pending}"
  fi
  publish_receipt "$pending" "$target"
  if (( exit_code != 0 )); then
    show_failure_tail "$target"
  fi
  return "$exit_code"
}

run_pyright_receipt() {
  local target="$1"
  shift
  local pending_stdout
  local pending_stderr
  local exit_code

  pending_stdout="$(new_pending_file "$target" "stdout")"
  pending_stderr="$(new_pending_file "$target" "stderr")"
  if (cd -- "$CANDIDATE_ROOT" && run_pyright_tool --project "$FROZEN_CONFIG" --outputjson "$@") \
    >"$pending_stdout" 2>"$pending_stderr"; then
    exit_code=0
  else
    exit_code=$?
  fi

  if ! validate_pyright_receipt "$pending_stdout"; then
    die "Pyright JSON parsing failed; stdout=${pending_stdout} stderr=${pending_stderr}"
  fi
  publish_receipt "$pending_stdout" "$target"
  if [[ -s "$pending_stderr" ]]; then
    printf 'Pyright stderr retained at: %s\n' "$pending_stderr" >&2
  fi
  if (( exit_code != 0 )); then
    show_failure_tail "$target"
  fi
  return "$exit_code"
}

parse_receipt_and_arguments() {
  [[ "${1:-}" == "--receipt" ]] || die "expected --receipt"
  [[ -n "${2:-}" ]] || die "missing receipt path"
  RECEIPT_TARGET="$(new_receipt_target "$2")"
  shift 2
  [[ "${1:-}" == "--" ]] || die "expected -- before command arguments"
  shift
  (( $# > 0 )) || die "at least one command argument is required"
  COMMAND_ARGUMENTS=("$@")
}

validate_scoped_pyright_paths() {
  local candidate_path
  for candidate_path in "$@"; do
    [[ "$candidate_path" != -* ]] || die "Pyright mode accepts only relative Python paths"
    [[ "$candidate_path" == *.py ]] || die "Pyright mode accepts only Python paths: ${candidate_path}"
    [[ -f "${CANDIDATE_ROOT}/${candidate_path}" ]] || die "Pyright path is not in the candidate: ${candidate_path}"
  done
}

validate_ruff_arguments() {
  local argument
  for argument in "$@"; do
    [[ "$argument" != "--fix" && "$argument" != "--unsafe-fixes" ]] || die "Ruff mutation flags are forbidden"
  done
}

integrity_impl() {
  git diff --check
  git diff --cached --check

  "$FROZEN_PYTHON" - "$CANDIDATE_ROOT" <<'PY'
import ast
import subprocess
import sys
import types
from pathlib import Path

root = Path(sys.argv[1])


def git(*args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(root), *args],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    ).stdout


def git_checked(*args: str) -> None:
    subprocess.run(["git", "-C", str(root), *args], check=True)


expected_status = {
    "A  tests/integrations/test_media_watcher_sources.py",
    "M  trr_backend/integrations/nbcumv.py",
    " M tests/services/test_cast_reference_builder.py",
    " M trr_backend/services/cast_reference_builder.py",
    " M trr_backend/vision/people_count_engine.py",
    " M trr_backend/vision/screen_time_face_matching.py",
}
actual_status = set(git("status", "--porcelain=v1").splitlines())
if actual_status != expected_status:
    raise SystemExit(f"unexpected candidate status: {sorted(actual_status)!r}")

expected_cached = {
    "A\ttests/integrations/test_media_watcher_sources.py",
    "M\ttrr_backend/integrations/nbcumv.py",
}
actual_cached = set(git("diff", "--cached", "--name-status").splitlines())
if actual_cached != expected_cached:
    raise SystemExit(f"unexpected staged P16 paths: {sorted(actual_cached)!r}")

expected_unstaged = {
    "M\ttests/services/test_cast_reference_builder.py",
    "M\ttrr_backend/services/cast_reference_builder.py",
    "M\ttrr_backend/vision/people_count_engine.py",
    "M\ttrr_backend/vision/screen_time_face_matching.py",
}
actual_unstaged = set(git("diff", "--name-status").splitlines())
if actual_unstaged != expected_unstaged:
    raise SystemExit(f"unexpected unstaged P17 paths: {sorted(actual_unstaged)!r}")

expected_index_blobs = {
    "trr_backend/integrations/nbcumv.py": "27462ba16b4ecd56d305562bbeb46943e932b81f",
    "tests/integrations/test_media_watcher_sources.py": "32f0699350d98bbc02aec46a0eecb859e37adb9d",
}
for path, expected in expected_index_blobs.items():
    actual = git("rev-parse", f":{path}").strip()
    if actual != expected:
        raise SystemExit(f"staged P16 blob drift for {path}: {actual}")

expected_head_blobs = {
    "tests/services/test_cast_reference_builder.py": "ee66e4aa84c98917148efb0e7c8ffa7eb1a39b1a",
    "trr_backend/services/cast_reference_builder.py": "b9847bfd50dc8acff234423b6bfdf542100bc35a",
    "trr_backend/vision/people_count_engine.py": "6eb5deadf9daae2649094747d178e32c49cbbd91",
    "trr_backend/vision/screen_time_face_matching.py": "c481306a96335b70e4ef09842aacf27fc6152ad1",
}
for path, expected in expected_head_blobs.items():
    actual = git("rev-parse", f"HEAD:{path}").strip()
    if actual != expected:
        raise SystemExit(f"frozen preimage drift for {path}: {actual}")

for frozen_path in (
    "pyrightconfig.json",
    "requirements.in",
    "requirements.lock.txt",
    "requirements.modal.browser.in",
    "requirements.modal.browser.lock.txt",
    "requirements.modal.lean.in",
    "requirements.modal.lean.lock.txt",
    "requirements.modal.vision.in",
    "requirements.modal.vision.lock.txt",
    "requirements.txt",
):
    git_checked("diff", "--quiet", "HEAD", "--", frozen_path)

transforms = {
    "trr_backend/services/cast_reference_builder.py": (
        "    import cv2\n",
        "    # OpenCV is installed only in the dedicated vision runtime.\n"
        "    import cv2  # pyright: ignore[reportMissingImports]\n",
    ),
    "trr_backend/vision/people_count_engine.py": (
        "        import cv2\n",
        "        # OpenCV is installed only in the dedicated vision runtime.\n"
        "        import cv2  # pyright: ignore[reportMissingImports]\n",
    ),
    "trr_backend/vision/screen_time_face_matching.py": (
        "        from deepface import DeepFace\n",
        "        # DeepFace is installed only in the dedicated vision runtime.\n"
        "        from deepface import DeepFace  # pyright: ignore[reportMissingImports]\n",
    ),
}


def executable_constants(source: str, filename: str) -> tuple[object, ...]:
    def walk(code: types.CodeType) -> tuple[object, ...]:
        values: list[object] = []
        for value in code.co_consts:
            if isinstance(value, types.CodeType):
                values.append(("code", walk(value)))
            else:
                values.append(("constant", value))
        return tuple(values)

    return walk(compile(source, filename, "exec"))


for path, (before, after) in transforms.items():
    baseline = git("show", f"HEAD:{path}")
    current = (root / path).read_text(encoding="utf-8")
    if baseline.count(before) != 1:
        raise SystemExit(f"ambiguous frozen import preimage in {path}")
    expected = baseline.replace(before, after, 1)
    if current != expected:
        raise SystemExit(f"P17 transform exceeds the exact comment-only repair in {path}")
    baseline_tree = ast.parse(baseline, filename=path)
    current_tree = ast.parse(current, filename=path)
    if ast.dump(baseline_tree, include_attributes=False) != ast.dump(current_tree, include_attributes=False):
        raise SystemExit(f"AST drift detected in {path}")
    if executable_constants(baseline, path) != executable_constants(current, path):
        raise SystemExit(f"executable constant drift detected in {path}")

test_path = "tests/services/test_cast_reference_builder.py"
test_baseline = git("show", f"HEAD:{test_path}")
test_current = (root / test_path).read_text(encoding="utf-8")
test_expected = test_baseline.replace(
    "import types\n\nimport numpy as np\n",
    "import types\n\nimport numpy as np\nimport pytest\n",
    1,
)
test_expected = test_expected.replace(
    "from trr_backend.services import cast_reference_builder as builder\n\n\ndef _image():",
    "from trr_backend.services import cast_reference_builder as builder\n\n\n"
    "@pytest.fixture(autouse=True)\n"
    "def _fake_cv2(monkeypatch) -> None:\n"
    "    fake_cv2 = types.SimpleNamespace(\n"
    "        COLOR_BGR2GRAY=0,\n"
    "        CV_64F=0,\n"
    "        cvtColor=lambda image, _conversion: image,\n"
    "        Laplacian=lambda _image, _depth: types.SimpleNamespace(var=lambda: 0.0),\n"
    "    )\n"
    "    monkeypatch.setattr(builder, \"_lazy_cv2\", lambda: fake_cv2)\n\n\n"
    "def _image():",
    1,
)
if test_current != test_expected:
    raise SystemExit("cast-reference test fixture exceeds the exact base-CI fake-cv2 repair")

print("integrity: exact P16 index, exact P17 static transforms, exact fake-cv2 test fixture, AST, and executable constants verified")
PY

  "$FROZEN_PYTHON" -c 'import api.main'
  "$FROZEN_PYTHON" scripts/check_repo_hygiene.py
}

run_integrity_receipt() {
  local target="$1"
  local pending
  local exit_code

  pending="$(new_pending_file "$target" "stdout")"
  if (cd -- "$CANDIDATE_ROOT" && integrity_impl) >"$pending" 2>&1; then
    exit_code=0
  else
    exit_code=$?
  fi

  if ! validate_text_receipt "$pending"; then
    die "integrity receipt parsing failed; pending evidence remains at ${pending}"
  fi
  publish_receipt "$pending" "$target"
  if (( exit_code != 0 )); then
    show_failure_tail "$target"
  fi
  return "$exit_code"
}

verify_final_pyright_summary() {
  "$FROZEN_PYTHON" - "$1" <<'PY'
import json
import sys
from pathlib import Path

summary = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["summary"]
expected = {
    "filesAnalyzed": 1380,
    "errorCount": 0,
    "warningCount": 82,
    "informationCount": 0,
}
actual = {key: summary.get(key) for key in expected}
if actual != expected:
    raise SystemExit(f"final Pyright summary mismatch: {actual!r}")
print("final Pyright summary: 1380 files, 0 errors, 82 warnings, 0 information")
PY
}

run_final_tail() {
  local requested_dir="$1"
  local receipt_dir

  receipt_dir="$(canonical_external_path "$requested_dir")"
  [[ ! -e "$receipt_dir" && ! -L "$receipt_dir" ]] || die "final receipt directory already exists: ${receipt_dir}"
  mkdir "$receipt_dir" || die "could not create final receipt directory: ${receipt_dir}"
  printf 'final receipt directory: %s\n' "$receipt_dir"

  ensure_workspace_scaffold

  if ! run_text_receipt "$receipt_dir/import.txt" "$FROZEN_PYTHON" -c 'import api.main'; then
    die "final-tail import gate failed; atomic receipt: ${receipt_dir}/import.txt"
  fi
  if ! run_text_receipt "$receipt_dir/api-tests.txt" "$FROZEN_PYTHON" -m pytest -q -p no:cacheprovider tests/api; then
    die "final-tail API tests failed; atomic receipt: ${receipt_dir}/api-tests.txt"
  fi
  if run_text_receipt "$receipt_dir/pytest.txt" "$FROZEN_PYTHON" -m pytest -q -p no:cacheprovider \
    tests -m "not browser and not vision and not live"; then
    printf 'full pytest (non-blocking): passed\n'
  else
    printf 'full pytest (non-blocking): failed; continuing to blocking gates\n' >&2
  fi
  if ! run_text_receipt "$receipt_dir/ruff-check.txt" "$RUFF_BIN" check --no-cache "${CHANGED_PYTHON_PATHS[@]}"; then
    die "final-tail Ruff lint failed; atomic receipt: ${receipt_dir}/ruff-check.txt"
  fi
  if ! run_text_receipt "$receipt_dir/ruff-format.txt" "$RUFF_BIN" format --check --no-cache "${CHANGED_PYTHON_PATHS[@]}"; then
    die "final-tail Ruff format failed; atomic receipt: ${receipt_dir}/ruff-format.txt"
  fi
  if ! run_integrity_receipt "$receipt_dir/integrity.txt"; then
    die "final-tail integrity failed; atomic receipt: ${receipt_dir}/integrity.txt"
  fi
  if ! run_pyright_receipt "$receipt_dir/pyright.json"; then
    die "final-tail Pyright failed; atomic receipt: ${receipt_dir}/pyright.json"
  fi
  verify_final_pyright_summary "$receipt_dir/pyright.json"
}

main() {
  local mode="${1:-}"
  local -a ruff_paths=()
  local arg_index
  shift || true

  activate_frozen_environment
  verify_environment

  case "$mode" in
    env)
      (( $# == 0 )) || die "env accepts no arguments"
      ensure_workspace_scaffold
      printf 'frozen environment verified: Python 3.11.9, Pyright 1.1.390, Ruff 0.14.4\n'
      ;;
    pyright)
      parse_receipt_and_arguments "$@"
      validate_scoped_pyright_paths "${COMMAND_ARGUMENTS[@]}"
      run_pyright_receipt "$RECEIPT_TARGET" "${COMMAND_ARGUMENTS[@]}"
      ;;
    pytest)
      parse_receipt_and_arguments "$@"
      run_text_receipt "$RECEIPT_TARGET" "$FROZEN_PYTHON" -m pytest -p no:cacheprovider "${COMMAND_ARGUMENTS[@]}"
      ;;
    ruff)
      parse_receipt_and_arguments "$@"
      validate_ruff_arguments "${COMMAND_ARGUMENTS[@]}"
      case "${COMMAND_ARGUMENTS[0]}" in
        check)
          (( ${#COMMAND_ARGUMENTS[@]} > 1 )) || die "Ruff check requires at least one path"
          for ((arg_index = 1; arg_index < ${#COMMAND_ARGUMENTS[@]}; arg_index++)); do
            ruff_paths+=("${COMMAND_ARGUMENTS[arg_index]}")
          done
          run_text_receipt "$RECEIPT_TARGET" "$RUFF_BIN" check --no-cache "${ruff_paths[@]}"
          ;;
        format)
          [[ "${COMMAND_ARGUMENTS[1]:-}" == "--check" ]] || die "Ruff format requires --check"
          (( ${#COMMAND_ARGUMENTS[@]} > 2 )) || die "Ruff format requires at least one path"
          for ((arg_index = 2; arg_index < ${#COMMAND_ARGUMENTS[@]}; arg_index++)); do
            ruff_paths+=("${COMMAND_ARGUMENTS[arg_index]}")
          done
          run_text_receipt "$RECEIPT_TARGET" "$RUFF_BIN" format --check --no-cache "${ruff_paths[@]}"
          ;;
        *)
          die "Ruff mode supports only check or format --check"
          ;;
      esac
      ;;
    final-tail)
      [[ "${1:-}" == "--receipt-dir" && -n "${2:-}" && $# == 2 ]] || {
        usage >&2
        die "final-tail requires exactly --receipt-dir /absolute/new-directory"
      }
      run_final_tail "$2"
      ;;
    *)
      usage >&2
      die "unknown validation mode: ${mode:-<missing>}"
      ;;
  esac
}

main "$@"
