# 0003. Tax and currency convention

## Decision

- **Net amounts exclude sales tax.** The POS exports amounts with US sales tax and the tax next to
  them; staging restates `net = amount including tax - tax` and keeps the tax in its own column.
  The OMS exports amounts without tax; its tax column is empty in the fact, not zero.
- **Amounts stay in US dollars and are also given in euros**, converted line by line at the latest
  USD to EUR fixing on or before the business day, and rounded to the cent. The date of the fixing
  used is a column of the fact.
- **A line with no rate is quarantined** (`MISSING_FX_RATE`), not converted at a guessed rate.

## Why

- US sales tax depends on where the sale happens and is not revenue. A group that compares regions
  compares amounts without tax; the legacy store datamart did not, which is the first reason it
  does not match the core model. The parity audit adds the tax back to prove that this is the only
  difference of definition.
- An empty tax for the OMS says "not exported"; a zero would say "no tax was charged".
- There is no fixing at the weekend. Carrying the last one forward is the usual convention, and
  keeping its date makes the conversion checkable line by line.
- Rounding each line, then summing, keeps the datamarts equal to the fact to the cent, whatever the
  aggregation (a test checks it).

## Set aside

- **A monthly average rate**: common in finance reporting, but a second convention to explain and
  to reconcile; it can be added as another column if the group reports that way.
- **Computing the POS tax from the store's rate** instead of reading it: the export already holds
  the tax the customer paid, cents included.
