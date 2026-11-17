import csv
import filecmp

from retail_core_model_dbt.generate import SEEDS_DIR, World, write

DEFECT_CODES = {
    "AMBIGUOUS_PRODUCT",
    "DUPLICATE_LINE",
    "HEADER_LINES_MISMATCH",
    "MISSING_FX_RATE",
    "ORPHAN_RETURN",
    "SIGN_MISMATCH",
    "UNKNOWN_STORE",
    "UNMAPPED_PRODUCT",
}


def test_committed_seeds_are_what_the_generator_writes(tmp_path):
    tables = World().tables()
    write(tables, tmp_path)
    for name in tables:
        assert filecmp.cmp(
            tmp_path / f"{name}.csv", SEEDS_DIR / f"{name}.csv", shallow=False
        ), name


def test_manifest_plants_every_kind_of_defect_once_per_record():
    with (SEEDS_DIR / "ground_truth" / "planted_defects.csv").open(
        encoding="utf-8"
    ) as handle:
        rows = list(csv.DictReader(handle))
    assert {row["defect_code"] for row in rows} == DEFECT_CODES
    keys = [row["record_key"] for row in rows]
    assert len(keys) == len(set(keys))


def test_legacy_datamart_sums_every_exported_pos_row():
    tables = World().tables()
    exported = sum(
        row["amount_incl_tax_usd"] for row in tables["raw_us_pos/pos_sales_lines"]
    )
    legacy = sum(
        row["sales_incl_tax_usd"] for row in tables["raw_us_pos/legacy_daily_sales"]
    )
    assert exported == legacy
