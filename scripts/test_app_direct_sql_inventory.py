#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import sys
from datetime import date
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = ROOT / "scripts" / "app-direct-sql-inventory.py"


def load_inventory_module():
    spec = importlib.util.spec_from_file_location(
        "app_direct_sql_inventory_under_test", SCRIPT_PATH
    )
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def test_scanner_supports_plain_and_generic_calls_for_all_symbols() -> None:
    module = load_inventory_module()
    source = """
import { query, withTransaction, withAuthTransaction, queryWithAuth } from "@/lib/server/postgres";
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
import { query } from "@/lib/server/postgres";
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
import { query } from "@/lib/server/postgres";
// query<CommentOnly>(sql)
/* withTransaction<BlockComment>(callback) */
const text = "query<StringLiteral>(sql)";
const template = `query<TemplateLiteral>(sql)`;
const queryResult = 1;
config.query(context);
query<Actual> /* trivia */ (sql);
"""

    assert [symbol for symbol, _ in module.scan_call_sites(source)] == ["query"]


def test_scanner_resolves_aliased_generic_postgres_call() -> None:
    module = load_inventory_module()
    source = """
import { query as pgQuery } from "@/lib/server/postgres";
const result = await pgQuery<Record<string, unknown>>(sql);
"""

    assert [symbol for symbol, _ in module.scan_call_sites(source)] == ["query"]


def test_scanner_resumes_after_regex_literals_with_quote_characters() -> None:
    module = load_inventory_module()
    source = """
import { query as pgQuery } from "@/lib/server/postgres";
const anchor = /href="([^"]+)"/gi;
const result = await pgQuery<Row>(sql);
"""

    assert [symbol for symbol, _ in module.scan_call_sites(source)] == ["query"]


def test_scanner_skips_regex_literals_after_control_flow_keywords() -> None:
    module = load_inventory_module()
    source = """
import { query as pgQuery } from "@/lib/server/postgres";
function returned(value) {
  return /pgQuery<Row>(sql)/.test(value);
}
function thrown() {
  throw /pgQuery<Row>(sql)/;
}
switch (value) {
  case /pgQuery<Row>(sql)/.source:
    break;
  default:
    break;
}
if (value) {
  value = false;
} else /pgQuery<Row>(sql)/.test(value);
const result = await pgQuery<Row>(sql);
"""

    assert [symbol for symbol, _ in module.scan_call_sites(source)] == ["query"]


def test_scanner_resolves_namespace_postgres_call() -> None:
    module = load_inventory_module()
    source = """
import * as postgres from "@/lib/server/postgres";
const result = await postgres.query<Row>(sql);
"""

    assert [symbol for symbol, _ in module.scan_call_sites(source)] == ["query"]


def test_scanner_ignores_unrelated_query_member_in_file_with_postgres_import() -> None:
    module = load_inventory_module()
    source = """
import { query as pgQuery } from "@/lib/server/postgres";
const sqlResult = await pgQuery(sql);
const queryValue = await config.query(context);
"""

    assert [symbol for symbol, _ in module.scan_call_sites(source)] == ["query"]


def test_scanner_counts_transaction_client_receiver_but_not_other_members() -> None:
    module = load_inventory_module()
    source = """
import { withTransaction } from "@/lib/server/postgres";
await withTransaction(async (client) => {
  await client.query<Row>(sql);
  await config.query(context);
});
"""

    assert [symbol for symbol, _ in module.scan_call_sites(source)] == [
        "withTransaction",
        "query",
    ]


def test_line_number_scanner_advances_without_prefix_recounts() -> None:
    module = load_inventory_module()

    class CountGuard(str):
        def count(self, _sub: str, _start: int = 0, _end: int = sys.maxsize) -> int:
            raise AssertionError("line extraction must not rescan source prefixes")

    source = CountGuard(
        'import { query } from "@/lib/server/postgres";\n'
        "query(first); query(second);\n\nquery<Third>(third);\n"
    )
    offsets = [offset for _, offset in module.scan_call_sites(source)]

    assert list(module._iter_line_numbers(source, offsets)) == [2, 2, 4]


def test_collect_uses_emits_each_multiline_call_once(
    tmp_path: Path, monkeypatch
) -> None:
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


def test_collect_uses_ignores_non_database_query_callbacks_without_postgres_import(
    tmp_path: Path,
    monkeypatch,
) -> None:
    module = load_inventory_module()
    source_root = tmp_path / "src" / "lib" / "server" / "trr-api"
    source_root.mkdir(parents=True)
    (source_root / "admin-backend-proxy-route.ts").write_text(
        "const queryValue = await config.query(context);\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(module, "ROOT", tmp_path)
    monkeypatch.setattr(module, "APP_ROOT", tmp_path)
    monkeypatch.setattr(module, "SCAN_ROOTS", (tmp_path / "src" / "lib" / "server",))

    assert module.collect_uses() == []


def _valid_exception(module, use, **overrides):
    record = {
        "id": use.row_id,
        "source": {
            "path": use.path.as_posix(),
            "symbol": use.symbol,
            "ordinal": use.ordinal,
            "context": use.context,
        },
        "classification": use.owner_alias,
        "durable_owner": use.owner_alias,
        "execution_owner": "Task 3",
        "reason": "Temporary direct-SQL exception until the named FastAPI migration target is cut over.",
        "packet": "packet-2-shows-seasons-people-media",
        "migration_target": "GET /api/v2/admin/covered-shows",
        "reauthorized_at": "2026-07-15",
        "review_by": "2026-08-14",
    }
    record.update(overrides)
    return record


def _sample_use(module):
    return module.DirectSqlUse(
        path=Path("TRR-APP/apps/web/src/lib/server/admin/covered-shows-repository.ts"),
        line_number=2,
        symbol="query",
        ordinal=1,
        row_id="app-sql-test",
        owner_alias="admin-read-model",
        risk="medium",
        context="getCoveredShows",
        excerpt="query(sql)",
    )


def test_stable_row_id_does_not_depend_on_line_number() -> None:
    module = load_inventory_module()
    source_path = Path("TRR-APP/apps/web/src/lib/server/admin/example.ts")

    assert module.stable_row_id(source_path, "query", 3) == module.stable_row_id(
        source_path, "query", 3
    )
    assert module.stable_row_id(source_path, "query", 3) != module.stable_row_id(
        source_path, "query", 4
    )


def test_retired_call_ordinals_preserve_surviving_trr_shows_row_ids() -> None:
    module = load_inventory_module()
    source_path = Path(
        "TRR-APP/apps/web/src/lib/server/trr-api/trr-shows-repository.ts"
    )

    assert module.stable_ordinal(source_path, "query", 1) == 10
    assert module.stable_ordinal(source_path, "query", 2) == 35
    assert module.stable_ordinal(source_path, "query", 3) == 36
    assert module.stable_ordinal(source_path, "query", 4) == 79


def test_retired_call_ordinals_reserve_removed_packet_2c_rows() -> None:
    module = load_inventory_module()
    source_path = Path(
        "TRR-APP/apps/web/src/lib/server/trr-api/trr-shows-repository.ts"
    )

    retired = module.RETIRED_CALL_ORDINALS[(source_path.as_posix(), "query")]
    assert {32, 37, 38, 39, 40, 41, 73, 75, 76, 77, 78}.issubset(retired)
    assert (
        module.stable_row_id(
            source_path,
            "query",
            module.stable_ordinal(source_path, "query", 2),
        )
        == "app-sql-cec04b3b62c24cec"
    )


def test_retired_call_ordinals_reserve_removed_packet_2d_rows() -> None:
    module = load_inventory_module()
    trr_shows_path = Path(
        "TRR-APP/apps/web/src/lib/server/trr-api/trr-shows-repository.ts"
    )
    image_repository_path = Path(
        "TRR-APP/apps/web/src/lib/server/admin/images-repository.ts"
    )
    media_link_repository_path = Path(
        "TRR-APP/apps/web/src/lib/server/trr-api/media-links-repository.ts"
    )
    media_link_route_path = Path(
        "TRR-APP/apps/web/src/app/api/admin/trr-api/media-links/route.ts"
    )

    retired_trr_shows = module.RETIRED_CALL_ORDINALS[
        (trr_shows_path.as_posix(), "query")
    ]
    assert {
        9,
        42,
        43,
        44,
        45,
        46,
        47,
        61,
        62,
        63,
        64,
        65,
        66,
        67,
        68,
        69,
        70,
        71,
        72,
    }.issubset(retired_trr_shows)
    assert module.RETIRED_CALL_ORDINALS[
        (image_repository_path.as_posix(), "query")
    ] == tuple(range(1, 10))
    assert module.RETIRED_CALL_ORDINALS[
        (media_link_repository_path.as_posix(), "query")
    ] == tuple(range(1, 7))
    assert module.RETIRED_CALL_ORDINALS[
        (media_link_route_path.as_posix(), "query")
    ] == (1,)


def test_retired_call_ordinals_reserve_removed_network_streaming_row_ids() -> None:
    module = load_inventory_module()
    source_path = Path(
        "TRR-APP/apps/web/src/lib/server/admin/networks-streaming-repository.ts"
    )

    assert module.stable_ordinal(source_path, "query", 1) == 8


def test_retired_call_ordinals_reserve_removed_person_media_row_ids() -> None:
    module = load_inventory_module()
    cover_path = Path(
        "TRR-APP/apps/web/src/lib/server/admin/person-cover-photos-repository.ts"
    )
    crop_path = Path(
        "TRR-APP/apps/web/src/lib/server/admin/person-thumbnail-crops-repository.ts"
    )

    assert module.stable_ordinal(cover_path, "query", 1) == 5
    assert module.stable_ordinal(cover_path, "withAuthTransaction", 1) == 3
    assert module.stable_ordinal(crop_path, "query", 1) == 3


def test_covered_shows_migration_target_has_no_patch_endpoint() -> None:
    module = load_inventory_module()
    use = module.DirectSqlUse(
        path=Path("TRR-APP/apps/web/src/lib/server/admin/covered-shows-repository.ts"),
        line_number=1,
        symbol="query",
        ordinal=1,
        row_id="app-sql-test",
        owner_alias="admin-read-model",
        risk="medium",
        context="getCoveredShows",
        excerpt="query(",
    )

    plan = module._migration_plan_for(use)

    assert plan.migration_target == (
        "GET/POST /api/v2/admin/covered-shows and "
        "GET/DELETE /api/v2/admin/covered-shows/{show_id}"
    )
    assert "PATCH" not in plan.migration_target


def test_exception_validator_fails_missing_orphaned_and_duplicate_rows() -> None:
    module = load_inventory_module()
    use = _sample_use(module)
    valid = _valid_exception(module, use)
    orphaned = {
        **valid,
        "id": "app-sql-orphaned",
        "source": {**valid["source"], "ordinal": 999},
    }

    errors = module.validate_exception_records(
        [use], [valid, valid, orphaned], fail_expired=False
    )

    assert any("duplicate exception id" in error for error in errors)
    assert any("duplicate exception source" in error for error in errors)
    assert any("orphaned exception" in error for error in errors)
    assert not any("missing exception" in error for error in errors)

    missing_errors = module.validate_exception_records([use], [], fail_expired=False)
    assert any("missing exception" in error for error in missing_errors)


def test_exception_validator_is_clock_aware_and_rejects_over_30_day_windows() -> None:
    module = load_inventory_module()
    use = _sample_use(module)
    valid = _valid_exception(module, use)

    assert (
        module.validate_exception_records(
            [use],
            [valid],
            fail_expired=True,
            as_of=date(2026, 8, 14),
        )
        == []
    )
    expired_errors = module.validate_exception_records(
        [use],
        [valid],
        fail_expired=True,
        as_of=date(2026, 8, 15),
    )
    assert any("expired exception" in error for error in expired_errors)

    # Existing non-expiry checks remain compatible: expiry is opt-in.
    assert (
        module.validate_exception_records(
            [use],
            [valid],
            fail_expired=False,
            as_of=date(2026, 8, 15),
        )
        == []
    )

    overlong = _valid_exception(module, use, review_by="2026-08-15")
    overlong_errors = module.validate_exception_records(
        [use], [overlong], fail_expired=False
    )
    assert any("exceeds 30 days" in error for error in overlong_errors)


def test_exception_validator_does_not_consult_clock_without_expiry_checks(
    monkeypatch,
) -> None:
    module = load_inventory_module()
    use = _sample_use(module)
    valid = _valid_exception(module, use)

    class DateWithoutClock(date):
        @classmethod
        def today(cls):
            raise AssertionError("non-expiry validation must not consult the clock")

    monkeypatch.setattr(module, "date", DateWithoutClock)

    assert module.validate_exception_records([use], [valid], fail_expired=False) == []


def test_exception_validator_rejects_stale_function_context() -> None:
    module = load_inventory_module()
    use = _sample_use(module)
    record = _valid_exception(
        module,
        use,
        source={
            "path": use.path.as_posix(),
            "symbol": use.symbol,
            "ordinal": use.ordinal,
            "context": "staleFunctionContext",
        },
    )

    errors = module.validate_exception_records([use], [record], fail_expired=False)

    assert any("function context mismatch" in error for error in errors)


def test_default_run_is_clean_checkout_safe_and_explicit_outputs_are_reproducible(
    tmp_path: Path,
    monkeypatch,
    capsys,
) -> None:
    module = load_inventory_module()
    source_root = tmp_path / "src" / "lib" / "server" / "admin"
    source_root.mkdir(parents=True)
    (source_root / "covered-shows-repository.ts").write_text(
        'import { query } from "@/lib/server/postgres";\n'
        "export async function getCoveredShows() {\n"
        "  return query(sql);\n"
        "}\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(module, "ROOT", tmp_path)
    monkeypatch.setattr(module, "APP_ROOT", tmp_path)
    monkeypatch.setattr(module, "SCAN_ROOTS", (tmp_path / "src" / "lib" / "server",))

    assert module.main(["--check"]) == 0
    assert capsys.readouterr().out == ""
    assert module.main([]) == 0
    assert "Total direct SQL call sites:" in capsys.readouterr().out
    assert not (tmp_path / "docs").exists()

    uses = module.collect_uses()
    records = module.build_exception_records(
        uses,
        reauthorized_at="2026-08-01",
        review_by="2026-08-14",
    )
    exceptions = tmp_path / "explicit-exceptions.json"
    exceptions.write_text(module.render_exception_manifest(records), encoding="utf-8")
    markdown = tmp_path / "explicit-inventory.md"
    inventory = tmp_path / "explicit-inventory.json"
    ledger = tmp_path / "explicit-api-ledger.json"
    argv = [
        "--output",
        str(markdown),
        "--inventory-json",
        str(inventory),
        "--api-ledger",
        str(ledger),
        "--exceptions",
        str(exceptions),
    ]

    assert module.main([*argv, "--check"]) == 1
    assert module.main(argv) == 0
    assert module.main([*argv, "--check"]) == 0
    assert markdown.is_file()
    assert inventory.is_file()
    assert ledger.is_file()


def test_default_run_does_not_render_unrequested_json_outputs(
    monkeypatch,
    capsys,
) -> None:
    module = load_inventory_module()
    monkeypatch.setattr(module, "collect_uses", lambda: [])
    monkeypatch.setattr(module, "render_markdown", lambda *_args: "# Inventory\n")

    def fail_if_rendered(*_args):
        raise AssertionError("unrequested JSON output must not be rendered")

    monkeypatch.setattr(module, "render_inventory_json", fail_if_rendered)
    monkeypatch.setattr(module, "render_api_ledger_json", fail_if_rendered)

    assert module.main([]) == 0
    assert capsys.readouterr().out == "# Inventory\n"
