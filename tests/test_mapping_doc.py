import re

from retail_core_model_dbt.mapping_doc import MAPPING_DOC, render


def test_committed_mapping_page_matches_the_seed():
    assert MAPPING_DOC.read_text(encoding="utf-8") == render()


def test_every_table_row_has_four_cells():
    # A bare "|" inside a cell (pos|ticket|line) would split the row on GitHub.
    rows = [line for line in render().splitlines() if line.startswith("|")]
    for row in rows:
        assert len(re.findall(r"(?<!\\)\|", row)) == 5, row
