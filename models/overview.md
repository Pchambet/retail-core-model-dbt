{% docs __overview__ %}

# Retail core model: US migration (synthetic)

Two local US platforms of a fictitious house, « Maison Démo », are migrated to the group's core
retail model: a legacy store point of sale (`us_pos`) and an e-commerce order-management system
(`us_oms`). All data is synthetic.

Start with:

- **`fct_sales_lines`**: one row per sale or return line, the grain of the core model;
- **`audit_migration_parity`**: the legacy store datamart against the new model, per store and day;
- **`audit_data_defects`** and **`audit_quarantined_lines`**: what the pipeline refuses, and why;
- the lineage graph (bottom right), from the two platforms to the Power BI exposure.

The source-to-target mapping and the decisions are in the repository's `docs/` folder.

{% enddocs %}
