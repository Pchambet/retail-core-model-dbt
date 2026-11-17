from retail_core_model_dbt import main


def test_main_succeeds():
    assert main([]) == 0
