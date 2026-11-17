"""Render the source-to-target mapping seed as a Markdown page.

The mapping lives once, in `seeds/meta/source_to_target.csv`: dbt loads it and a data test checks it
against the columns of the fact. This script only turns it into `docs/source_to_target.md` for readers.
"""

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAPPING_CSV = ROOT / "seeds" / "meta" / "source_to_target.csv"
MAPPING_DOC = ROOT / "docs" / "source_to_target.md"

HEADER = """# Source-to-target mapping of `fct_sales_lines`

Generated from [`seeds/meta/source_to_target.csv`](../seeds/meta/source_to_target.csv) by
`uv run render-mapping`; do not edit by hand. A dbt data test fails when a column of the fact has no
row here or when a row names a column that does not exist.

| Target column | From the POS (`pos_sales_lines`) | From the OMS (`oms_orders`, `oms_order_lines`, `oms_returns`) | Rule |
|---|---|---|---|
"""


def cell(text: str) -> str:
    # A bare pipe would end the cell: the record keys are written pos|ticket|line.
    return text.replace("|", "\\|")


def render(mapping_csv: Path = MAPPING_CSV) -> str:
    with mapping_csv.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    lines = [
        f"| `{row['target_column']}` | {cell(row['pos_source'])} | {cell(row['oms_source'])}"
        f" | {cell(row['rule'])} |"
        for row in rows
    ]
    return HEADER + "\n".join(lines) + "\n"


def main() -> int:
    MAPPING_DOC.write_text(render(), encoding="utf-8")
    print(f"wrote {MAPPING_DOC.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
