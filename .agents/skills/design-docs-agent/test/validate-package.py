#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import urlparse

import yaml

PACKAGE_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = PACKAGE_ROOT.parents[2]
APP_WEB_ROOT = REPO_ROOT / "TRR-APP" / "apps" / "web"
CONTRACTS_DIR = PACKAGE_ROOT / "contracts"
ROSTER_PATH = PACKAGE_ROOT / "agents" / "openai.yaml"
PACKAGE_SKILL_PATH = PACKAGE_ROOT / "SKILL.md"
EXTRACTION_HELPER_PATH = PACKAGE_ROOT / "agents" / "extraction-orchestrator.md"
VERIFICATION_HELPER_PATH = PACKAGE_ROOT / "agents" / "verification-gate.md"
VALIDATE_INPUTS_PATH = PACKAGE_ROOT / "validate-inputs" / "SKILL.md"
RUNTIME_BASELINE_PATH = PACKAGE_ROOT / "test" / "runtime-order-baseline.yaml"
EXTERNAL_VALIDATOR_PATH = PACKAGE_ROOT / "test" / "validate-external-contract.mjs"
CLAUDE_WRAPPER_PATH = REPO_ROOT / "TRR-APP" / ".claude" / "skills" / "design-docs-agent" / "SKILL.md"
SKILL_VERSION_POLICY = {
    "major": "breaking input/output contract or behavior changes",
    "minor": "additive input/output fields or additive behavior",
    "patch": "wording or non-contract clarifications",
}
METADATA_DIRS = {"agents", "adapters", "references", "test", "contracts", ".codex-plugin", ".claude-plugin"}


def fail(message: str) -> None:
    raise SystemExit(f"[validate-package] {message}")


def run_command(command: list[str], cwd: Path | None = None) -> str:
    result = subprocess.run(
        command,
        cwd=str(cwd) if cwd else None,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        stderr = result.stderr.strip()
        stdout = result.stdout.strip()
        details = stderr or stdout or f"command exited {result.returncode}"
        fail(f"{' '.join(command)} failed: {details}")
    return result.stdout


def load_yaml(path: Path) -> dict:
    return yaml.safe_load(path.read_text())


def parse_frontmatter(path: Path) -> dict:
    text = path.read_text()
    if not text.startswith("---\n"):
        fail(f"{path} is missing YAML frontmatter")
    _, _, remainder = text.partition("---\n")
    frontmatter_text, separator, _ = remainder.partition("\n---\n")
    if not separator:
        fail(f"{path} has unterminated YAML frontmatter")
    return yaml.safe_load(frontmatter_text) or {}


def validate_yaml_against_schema(schema_path: Path, yaml_path: Path) -> None:
    node_script = r"""
const fs = require('fs');
const path = require('path');
const { createRequire } = require('module');
const appPackageJson = process.argv[1];
const schemaPath = process.argv[2];
const yamlPath = process.argv[3];
const appRequire = createRequire(appPackageJson);
const Ajv2020 = appRequire('ajv/dist/2020');
const YAML = appRequire('yaml');
const schema = JSON.parse(fs.readFileSync(schemaPath, 'utf8'));
const data = YAML.parse(fs.readFileSync(yamlPath, 'utf8'));
const ajv = new Ajv2020({ strict: false, allErrors: true });
const validate = ajv.compile(schema);
if (!validate(data)) {
  console.error(JSON.stringify(validate.errors, null, 2));
  process.exit(1);
}
"""
    run_command(
        [
            "node",
            "-e",
            node_script,
            str(APP_WEB_ROOT / "package.json"),
            str(schema_path),
            str(yaml_path),
        ],
        cwd=APP_WEB_ROOT,
    )


def validate_json_schema_file(schema_path: Path) -> None:
    node_script = r"""
const fs = require('fs');
const { createRequire } = require('module');
const appRequire = createRequire(process.argv[1]);
const Ajv2020 = appRequire('ajv/dist/2020');
const schema = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const ajv = new Ajv2020({ strict: false, allErrors: true });
ajv.compile(schema);
"""
    run_command(
        [
            "node",
            "-e",
            node_script,
            str(APP_WEB_ROOT / "package.json"),
            str(schema_path),
        ],
        cwd=APP_WEB_ROOT,
    )


def validate_json_payload(schema_path: Path, payload: dict) -> None:
    node_script = r"""
const fs = require('fs');
const { createRequire } = require('module');
const appRequire = createRequire(process.argv[1]);
const Ajv2020 = appRequire('ajv/dist/2020');
const schema = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const payload = JSON.parse(process.argv[3]);
const ajv = new Ajv2020({ strict: false, allErrors: true });
const validate = ajv.compile(schema);
if (!validate(payload)) {
  console.error(JSON.stringify(validate.errors, null, 2));
  process.exit(1);
}
"""
    run_command(
        [
            "node",
            "-e",
            node_script,
            str(APP_WEB_ROOT / "package.json"),
            str(schema_path),
            json.dumps(payload),
        ],
        cwd=APP_WEB_ROOT,
    )


def list_owned_skill_dirs() -> list[str]:
    skill_dirs = []
    for child in sorted(PACKAGE_ROOT.iterdir()):
        if child.name in METADATA_DIRS or not child.is_dir():
            continue
        if (child / "SKILL.md").exists():
            skill_dirs.append(child.name)
    return skill_dirs


def host_matches(host: str, expected_domain: str) -> bool:
    return host == expected_domain or host.endswith(f".{expected_domain}")


def is_paywalled_article(article_url: str, policy: dict) -> bool:
    host = (urlparse(article_url).hostname or "").lower()
    paywalled = any(host_matches(host, domain) for domain in policy["paywalled_domains"])
    if paywalled:
        return True
    return bool(policy["defaults"]["treat_unknown_domains_as_paywalled"])


def is_allowed_live_supporting_source(url: str, policy: dict) -> bool:
    host = (urlparse(url).hostname or "").lower()
    return any(host_matches(host, domain) for domain in policy["allowed_live_supporting_domains"])


def detect_source_mode(source_bundle: dict) -> str:
    html = source_bundle["html"]
    if isinstance(html, dict):
        keys = set(html)
        if {"modeA", "modeB"} <= keys:
            return "merged"
        if "modeB" in keys:
            return "mode-b"
        return "mode-c"

    html_path = Path(html)
    text = html_path.read_text()
    if '<table class="highlight"' in text and 'line-content' in text:
        return "mode-b"
    return "mode-a"


def validate_contract_shapes() -> tuple[dict, dict]:
    publisher_policy = load_yaml(CONTRACTS_DIR / "publisher-policy.yaml")
    if set(publisher_policy) != {"version", "defaults", "paywalled_domains", "allowed_live_supporting_domains"}:
        fail("publisher-policy.yaml has unexpected top-level keys")
    if not isinstance(publisher_policy["paywalled_domains"], list) or not publisher_policy["paywalled_domains"]:
        fail("publisher-policy.yaml must define paywalled_domains")

    external_contract = load_yaml(CONTRACTS_DIR / "external-app-contract.yaml")
    if "files" not in external_contract:
        fail("external-app-contract.yaml must define files")
    return publisher_policy, external_contract


def validate_bidirectional_skill_roster(roster: dict) -> None:
    skill_dirs = set(list_owned_skill_dirs())
    owned_entries = {entry["skill"] for entry in roster["skillset"]["owned"]}
    if skill_dirs != owned_entries:
        missing_in_roster = sorted(skill_dirs - owned_entries)
        missing_on_disk = sorted(owned_entries - skill_dirs)
        fail(
            "owned skill roster/filesystem mismatch: "
            f"missing_in_roster={missing_in_roster}, missing_on_disk={missing_on_disk}"
        )


def validate_skill_versions(roster: dict) -> None:
    owned_map = {entry["skill"]: entry for entry in roster["skillset"]["owned"]}
    for skill_name in list_owned_skill_dirs():
        frontmatter = parse_frontmatter(PACKAGE_ROOT / skill_name / "SKILL.md")
        version = (frontmatter.get("metadata") or {}).get("version")
        if version != owned_map[skill_name]["version"]:
            fail(
                f"version mismatch for {skill_name}: frontmatter={version}, "
                f"roster={owned_map[skill_name]['version']}"
            )
    if not SKILL_VERSION_POLICY:
        fail("skill version policy is not defined")


def validate_supporting_sources(roster: dict) -> None:
    for entry in roster["skillset"]["supporting"]:
        source = entry["source"]
        if Path(source).is_absolute():
            fail(f"supporting skill source must be repo-relative: {source}")
        if source.startswith("skill://"):
            if source == "skill://" or source.endswith("/"):
                fail(f"supporting skill source token is malformed: {source}")
            continue
        if not (REPO_ROOT / source).exists():
            fail(f"supporting skill source does not exist: {source}")


def load_manifest(path: Path) -> dict:
    return json.loads(path.read_text())


def validate_manifest_parity() -> None:
    codex_manifest = load_manifest(PACKAGE_ROOT / ".codex-plugin" / "plugin.json")
    claude_manifest = load_manifest(PACKAGE_ROOT / ".claude-plugin" / "plugin.json")
    shared_fields = ["name", "version", "description", "author", "homepage", "repository", "license", "keywords"]
    for field in shared_fields:
        if codex_manifest.get(field) != claude_manifest.get(field):
            fail(f"manifest parity mismatch for field '{field}'")


def extract_adapter_capabilities(path: Path) -> list[str]:
    capabilities: list[str] = []
    pattern = re.compile(r"\|\s*`([^`]+)`\s*\|")
    for line in path.read_text().splitlines():
        match = pattern.search(line)
        if match:
            capabilities.append(match.group(1))
    return capabilities


def validate_adapter_capabilities(roster: dict) -> None:
    shared_capabilities = set(roster["shared_capabilities"])
    for adapter_path in (PACKAGE_ROOT / "adapters" / "claude.md", PACKAGE_ROOT / "adapters" / "codex.md"):
        for capability in extract_adapter_capabilities(adapter_path):
            if capability not in shared_capabilities:
                fail(f"{adapter_path.name} references undeclared capability '{capability}'")


def validate_no_phase_reenumeration(roster: dict) -> None:
    extraction_skills = [
        entry["skill"]
        for entry in sorted(
            (entry for entry in roster["skillset"]["owned"] if "extraction" in entry["phases"]),
            key=lambda entry: entry["order"],
        )
    ]
    verification_skills = [
        member["skill"]
        for step in roster["pipeline"]
        if step["phase"] == "verification"
        for member in step.get("members", [])
        if "skill" in member
    ]
    for path in (PACKAGE_SKILL_PATH, EXTRACTION_HELPER_PATH, VERIFICATION_HELPER_PATH):
        text = path.read_text()
        for skill_name in extraction_skills + verification_skills:
            if re.search(rf"\b{re.escape(skill_name)}\b", text):
                fail(f"{path.name} still re-enumerates runtime sub-skill '{skill_name}'")


def validate_runtime_baseline(roster: dict) -> None:
    baseline = load_yaml(RUNTIME_BASELINE_PATH)
    phases = [step["phase"] for step in roster["pipeline"]]
    if phases != baseline["top_level_sequence"]:
        fail(f"pipeline phase order drifted: {phases} != {baseline['top_level_sequence']}")

    extraction_membership = [
        entry["skill"]
        for entry in sorted(
            (entry for entry in roster["skillset"]["owned"] if "extraction" in entry["phases"]),
            key=lambda entry: entry["order"],
        )
    ]
    if extraction_membership != baseline["extraction_membership"]:
        fail("extraction membership drifted from runtime-order-baseline.yaml")

    verification_sequence = []
    for step in roster["pipeline"]:
        if step["phase"] != "verification":
            continue
        for member in step.get("members", []):
            verification_sequence.append(member.get("skill") or member.get("capability"))
    if verification_sequence != baseline["verification_sequence"]:
        fail("verification sequence drifted from runtime-order-baseline.yaml")


def validate_validate_inputs_contract_references() -> None:
    text = VALIDATE_INPUTS_PATH.read_text()
    required_refs = [
        "contracts/source-bundle.schema.json",
        "contracts/publisher-policy.yaml",
        "contracts/external-app-contract.yaml",
    ]
    for ref in required_refs:
        if ref not in text:
            fail(f"validate-inputs/SKILL.md must reference {ref}")


def validate_wrapper_deleted() -> None:
    if CLAUDE_WRAPPER_PATH.exists():
        fail("broken Claude wrapper still exists under TRR-APP/.claude/skills/design-docs-agent")


def validate_fixture_scenarios(policy: dict) -> None:
    schema_path = CONTRACTS_DIR / "source-bundle.schema.json"
    existing_fixture = REPO_ROOT / "TRR-APP" / "apps" / "web" / "tests" / "fixtures" / "design-docs-agent" / "athletic-article.html"
    if not existing_fixture.exists():
        fail("expected existing design-docs-agent fixture is missing")

    mode_a_bundle = {
        "canonicalSourceUrl": "https://www.theathletic.com/example-article",
        "html": str(existing_fixture),
        "authoritativeViewport": "desktop",
    }
    validate_json_payload(schema_path, mode_a_bundle)
    if detect_source_mode(mode_a_bundle) != "mode-a":
        fail("mode-a fixture scenario did not resolve as mode-a")

    with tempfile.TemporaryDirectory() as temp_dir:
        mode_b_path = Path(temp_dir) / "view-source.html"
        mode_b_path.write_text(
            "<table class=\"highlight\"><tr><td class=\"line-content\">&lt;html&gt;</td></tr></table>"
        )
        mode_b_bundle = {
            "canonicalSourceUrl": "https://www.wsj.com/story/example",
            "html": str(mode_b_path),
        }
        validate_json_payload(schema_path, mode_b_bundle)
        if detect_source_mode(mode_b_bundle) != "mode-b":
            fail("mode-b fixture scenario did not resolve as mode-b")

    merged_bundle = {
        "canonicalSourceUrl": "https://www.nytimes.com/interactive/example",
        "html": {
            "modeA": str(existing_fixture),
            "modeB": str(existing_fixture),
        },
        "css": ["styles.css"],
        "js": ["runtime.js"],
        "authoritativeViewport": "both",
    }
    validate_json_payload(schema_path, merged_bundle)
    if detect_source_mode(merged_bundle) != "merged":
        fail("merged fixture scenario did not resolve as merged")

    invalid_bundle = {
        "canonicalSourceUrl": "https://www.example.com/article",
        "screenshots": {"desktop": ["desktop.png"]},
    }
    try:
        validate_json_payload(schema_path, invalid_bundle)
    except SystemExit:
        pass
    else:
        fail("malformed source bundle unexpectedly passed schema validation")

    paywalled_url = "https://www.ft.com/content/example"
    if not is_paywalled_article(paywalled_url, policy):
        fail("paywalled URL was not detected as paywalled")

    public_supporting_url = "https://datawrapper.de/example"
    if not is_allowed_live_supporting_source(public_supporting_url, policy):
        fail("allowed public supporting live URL was rejected")


def main() -> None:
    validate_yaml_against_schema(CONTRACTS_DIR / "roster.schema.json", ROSTER_PATH)
    validate_json_schema_file(CONTRACTS_DIR / "source-bundle.schema.json")
    publisher_policy, _external_contract = validate_contract_shapes()

    roster = load_yaml(ROSTER_PATH)
    validate_bidirectional_skill_roster(roster)
    validate_skill_versions(roster)
    validate_supporting_sources(roster)
    validate_manifest_parity()
    validate_adapter_capabilities(roster)
    validate_no_phase_reenumeration(roster)
    validate_runtime_baseline(roster)
    validate_validate_inputs_contract_references()
    validate_wrapper_deleted()
    validate_fixture_scenarios(publisher_policy)
    run_command(["node", str(EXTERNAL_VALIDATOR_PATH)])
    print("[validate-package] OK")


if __name__ == "__main__":
    main()
