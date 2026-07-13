#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = ROOT / "scripts" / "app-direct-sql-inventory.py"


def load_inventory_module():
    spec = importlib.util.spec_from_file_location("app_direct_sql_inventory_under_test", SCRIPT_PATH)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def test_scanner_supports_plain_and_generic_calls_for_all_symbols() -> None:
    module = load_inventory_module()
    source = """
query(sql)
query<Row>(sql)
withTransaction(callback)
withTransaction<Result>(callback)
withAuthTransaction(auth, callback)
withAuthTransaction<Result>(auth, callback)
queryWithAuth(auth, sql)
queryWithAuth<Result>(auth, sql)
"""

    assert [symbol for symbol, _ in module.scan_call_sites(source)] == [
        "query",
        "query",
        "withTransaction",
        "withTransaction",
        "withAuthTransaction",
        "withAuthTransaction",
        "queryWithAuth",
        "queryWithAuth",
    ]


def test_scanner_balances_nested_multiline_and_complex_type_syntax() -> None:
    module = load_inventory_module()
    source = """
const nested = query<Record<string, unknown>>(sql);
const multiline = query<
  Record<
    \"row>name\",
    { tuple: [string, number]; map: (value: string) => Promise<Record<string, unknown>> }
  >
>(sql);
const objectType = query<{
  tuple: [string, { ok: true }];
  transform: (input: { value: string }) => [number, () => void];
}>(sql);
"""

    calls = module.scan_call_sites(source)

    assert [symbol for symbol, _ in calls] == ["query", "query", "query"]
    assert len({offset for _, offset in calls}) == 3


def test_scanner_ignores_symbols_in_comments_strings_and_non_calls() -> None:
    module = load_inventory_module()
    source = """
// query<CommentOnly>(sql)
/* withTransaction<BlockComment>(callback) */
const text = "query<StringLiteral>(sql)";
const template = `query<TemplateLiteral>(sql)`;
const queryResult = 1;
query<Actual> /* trivia */ (sql);
"""

    assert [symbol for symbol, _ in module.scan_call_sites(source)] == ["query"]


def test_collect_uses_emits_each_multiline_call_once(tmp_path: Path, monkeypatch) -> None:
    module = load_inventory_module()
    source_root = tmp_path / "src" / "lib" / "server" / "admin"
    source_root.mkdir(parents=True)
    source_file = source_root / "fixture.ts"
    source_file.write_text(
        """import { query } from \"@/lib/server/postgres\";
const result = await query<
  Record<string, { convert: (value: string) => [string, unknown] }>
>(sql);
""",
        encoding="utf-8",
    )
    monkeypatch.setattr(module, "ROOT", tmp_path)
    monkeypatch.setattr(module, "APP_ROOT", tmp_path)
    monkeypatch.setattr(module, "SCAN_ROOTS", (tmp_path / "src" / "lib" / "server",))

    uses = module.collect_uses()

    assert [(use.symbol, use.line_number) for use in uses] == [("query", 2)]
    assert uses[0].owner_alias == "admin-read-model"
