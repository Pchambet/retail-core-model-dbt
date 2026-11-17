from retail_core_model_dbt.mapping_doc import MAPPING_DOC, render


def test_committed_mapping_page_matches_the_seed():
    assert MAPPING_DOC.read_text(encoding="utf-8") == render()
