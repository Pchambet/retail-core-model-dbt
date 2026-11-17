"""Deterministic generator of the synthetic landing data (dbt seeds).

Two fictitious local US platforms of « Maison Démo » export their sales:

* a legacy store POS: one row per ticket line, amounts with US sales tax, store-local timestamps,
  returns as negative lines, quantities in sales units (a box of six plates is one unit);
* an e-commerce order-management system (OMS): orders, order lines and returns in three tables,
  amounts without tax, UTC timestamps, an order-level discount carried by the header.

The generator also writes the reference data of the group, the legacy daily datamart the migration
must reconcile with, and the manifest of the record-level defects it plants on purpose. Everything is
synthetic and the output is byte-for-byte reproducible (fixed seed, no clock).
"""

import csv
import random
from collections import defaultdict
from datetime import date, datetime, timedelta
from decimal import ROUND_HALF_UP, Decimal
from pathlib import Path

SEED = 20261117
FIRST_DAY = date(2026, 10, 5)
LAST_DAY = date(2026, 11, 15)
REFERENCE_FIRST_DAY = date(
    2026, 10, 1
)  # rates and calendar start before the sales window
SEEDS_DIR = Path(__file__).resolve().parents[2] / "seeds"

CENT = Decimal("0.01")

# store_code, group_store_id, name, city, state, timezone, channel, sales tax rate
STORES = [
    (
        "NYC",
        "US-001",
        "New York flagship",
        "New York",
        "NY",
        "America/New_York",
        "STORE",
        "0.08875",
    ),
    (
        "LAX",
        "US-002",
        "Los Angeles",
        "Los Angeles",
        "CA",
        "America/Los_Angeles",
        "STORE",
        "0.09500",
    ),
    (
        "CHI",
        "US-003",
        "Chicago",
        "Chicago",
        "IL",
        "America/Chicago",
        "STORE",
        "0.10250",
    ),
    ("MIA", "US-004", "Miami", "Miami", "FL", "America/New_York", "STORE", "0.07000"),
    (
        "WEB",
        "US-900",
        "US e-commerce",
        "New York",
        "NY",
        "America/New_York",
        "ECOM",
        "",
    ),
]
UNKNOWN_STORE = "DAL"  # opened locally, not yet in the group reference

CHANNELS = [("STORE", "Store"), ("ECOM", "E-commerce")]

# group_sku, name, metier, unit price per piece (USD), pieces per POS sales unit, pieces per OMS unit
PRODUCTS = [
    ("LG-0001", "Small leather wallet", "Leather goods", 620, 1, 1),
    ("LG-0002", "Card holder", "Leather goods", 340, 1, 1),
    ("LG-0003", "Leather belt", "Leather goods", 890, 1, 1),
    ("LG-0004", "Leather tote", "Leather goods", 4200, 1, 1),
    ("LG-0005", "Crossbody bag", "Leather goods", 3650, 1, 1),
    ("LG-0006", "Key ring", "Leather goods", 280, 1, 1),
    ("LG-0007", "Travel pouch", "Leather goods", 760, 1, 1),
    ("LG-0008", "Notebook cover", "Leather goods", 450, 1, 1),
    ("SK-0001", "Silk scarf 90", "Silk", 510, 1, 1),
    ("SK-0002", "Silk ribbon scarf", "Silk", 230, 1, 1),
    ("SK-0003", "Silk tie", "Silk", 250, 1, 1),
    ("SK-0004", "Cashmere and silk shawl", "Silk", 1250, 1, 1),
    ("SK-0005", "Pocket square", "Silk", 165, 1, 1),
    ("FR-0001", "Eau de toilette 100 ml", "Fragrance", 148, 1, 1),
    ("FR-0002", "Eau de parfum 50 ml", "Fragrance", 132, 1, 1),
    ("FR-0003", "Scented candle", "Fragrance", 210, 1, 1),
    ("TW-0001", "Porcelain dinner plate", "Tableware", 145, 6, 1),
    ("TW-0002", "Porcelain dessert plate", "Tableware", 120, 6, 1),
    ("TW-0003", "Tea cup and saucer", "Tableware", 190, 2, 1),
    ("TW-0004", "Porcelain mug", "Tableware", 150, 1, 1),
    ("TW-0005", "Crystal tumbler", "Tableware", 240, 2, 2),
    ("JW-0001", "Enamel bracelet", "Jewelry", 730, 1, 1),
    ("JW-0002", "Silver ring", "Jewelry", 520, 1, 1),
    ("JW-0003", "Leather bracelet", "Jewelry", 390, 1, 1),
    ("JW-0004", "Pendant necklace", "Jewelry", 1150, 1, 1),
    ("SH-0001", "Leather sandals", "Shoes", 760, 1, 1),
    ("SH-0002", "Leather sneakers", "Shoes", 890, 1, 1),
    ("SH-0003", "Leather loafers", "Shoes", 1050, 1, 1),
    ("HM-0001", "Wool blanket", "Home", 1650, 1, 1),
    ("HM-0002", "Cushion", "Home", 620, 1, 1),
    ("HM-0003", "Leather tray", "Home", 880, 1, 1),
    ("HM-0004", "Playing cards", "Home", 115, 1, 1),
]

POS_UNMAPPED = ("P19901", 310)  # local code absent from the cross-reference, unit price
OMS_UNMAPPED = ("W-XX-9901", 275)
POS_AMBIGUOUS = (
    "P10099",
    760,
    ("LG-0007", "LG-0008"),
)  # one local code, two group SKUs


def money(value) -> Decimal:
    return Decimal(value).quantize(CENT, rounding=ROUND_HALF_UP)


def pos_code(index: int) -> str:
    return f"P{10001 + index}"


def oms_code(group_sku: str) -> str:
    return f"W-{group_sku}"


def days(first: date = FIRST_DAY):
    day = first
    while day <= LAST_DAY:
        yield day
        day += timedelta(days=1)


class World:
    """Builds every table in memory, then writes them as CSV seeds."""

    def __init__(self) -> None:
        self.rng = random.Random(SEED)
        self.pos_lines: list[dict] = []
        self.orders: list[dict] = []
        self.order_lines: list[dict] = []
        self.returns: list[dict] = []
        self.defects: list[tuple[str, str]] = []
        self.ticket_seq: dict[tuple[str, date], int] = defaultdict(int)

    # ------------------------------------------------------------------ POS

    def pos_ticket(
        self, store: tuple, day: date, lines: list[tuple], *, is_return=False
    ) -> list[dict]:
        """`lines` holds (item_code, unit price per sales unit, quantity in sales units, uom)."""
        store_code, tax_rate = store[0], Decimal(store[7] or "0.08250")
        self.ticket_seq[(store_code, day)] += 1
        ticket_no = (
            f"{store_code}-{day:%Y%m%d}-{self.ticket_seq[(store_code, day)]:04d}"
        )
        sold_at = datetime.combine(day, datetime.min.time()) + timedelta(
            seconds=self.rng.randint(10 * 3600, 19 * 3600 + 1800)
        )
        rows = []
        for line_no, (item_code, unit_price, quantity, uom) in enumerate(
            lines, start=1
        ):
            sign = -1 if is_return else 1
            discount = (
                money(unit_price * quantity * Decimal("0.10"))
                if self.rng.random() < 0.03
                else money(0)
            )
            net = money(unit_price * quantity) - discount
            tax = money(net * tax_rate)
            rows.append(
                {
                    "ticket_no": ticket_no,
                    "line_no": line_no,
                    "store_code": store_code,
                    "sold_at_local": f"{sold_at:%Y-%m-%d %H:%M:%S}",
                    "item_code": item_code,
                    "qty": sign * quantity,
                    "uom": uom,
                    "amount_incl_tax_usd": sign * (net + tax),
                    "tax_amount_usd": sign * tax,
                    "discount_amount_usd": discount,
                    "export_batch_id": f"B{day:%Y%m%d}",
                    "loaded_at": f"{day + timedelta(days=1):%Y-%m-%d} 03:15:00",
                }
            )
        self.pos_lines.extend(rows)
        return rows

    def random_pos_lines(self) -> list[tuple]:
        lines = []
        for index in self.rng.sample(
            range(len(PRODUCTS)), self.rng.choice([1, 1, 1, 2, 2, 3])
        ):
            _, _, _, piece_price, pos_pack, _ = PRODUCTS[index]
            uom = {1: "EA", 2: "PR", 6: "BOX6"}[pos_pack]
            lines.append(
                (
                    pos_code(index),
                    Decimal(piece_price * pos_pack),
                    self.rng.choice([1, 1, 1, 2]),
                    uom,
                )
            )
        return lines

    def build_pos(self) -> None:
        for day in days():
            for store in STORES[:4]:
                for _ in range(
                    self.rng.randint(7, 11) + (3 if day.weekday() >= 5 else 0)
                ):
                    lines = self.random_pos_lines()
                    if self.rng.random() < 0.05:
                        self.pos_ticket(store, day, lines[:1], is_return=True)
                    else:
                        self.pos_ticket(store, day, lines)

    def plant_pos_defects(self) -> None:
        nyc, lax, chi, mia = STORES[:4]

        # Lines whose local product code has no cross-reference row.
        for store, day in (
            (nyc, date(2026, 10, 14)),
            (chi, date(2026, 10, 29)),
            (mia, date(2026, 11, 6)),
        ):
            row = self.pos_ticket(
                store, day, [(POS_UNMAPPED[0], Decimal(POS_UNMAPPED[1]), 1, "EA")]
            )[0]
            self.defect("UNMAPPED_PRODUCT", row)

        # Lines whose local product code maps to two group SKUs: flagged, never guessed.
        for store, day in (
            (lax, date(2026, 10, 9)),
            (nyc, date(2026, 10, 22)),
            (lax, date(2026, 11, 11)),
        ):
            row = self.pos_ticket(
                store, day, [(POS_AMBIGUOUS[0], Decimal(POS_AMBIGUOUS[1]), 1, "EA")]
            )[0]
            self.defect("AMBIGUOUS_PRODUCT", row)

        # Tickets of a store the group reference does not know yet.
        dallas = (UNKNOWN_STORE, "", "", "", "", "", "STORE", "0.08250")
        for day in (date(2026, 11, 12), date(2026, 11, 13)):
            for row in self.pos_ticket(dallas, day, self.random_pos_lines()):
                self.defect("UNKNOWN_STORE", row)

        # A ticket older than the first exchange rate of the reference: no rate to convert it.
        row = self.pos_ticket(nyc, date(2026, 9, 30), self.random_pos_lines()[:1])[0]
        self.defect("MISSING_FX_RATE", row)

        # Returns keyed with a negative quantity but a positive amount.
        for store, day in ((mia, date(2026, 10, 17)), (chi, date(2026, 11, 3))):
            row = self.pos_ticket(
                store, day, self.random_pos_lines()[:1], is_return=True
            )[0]
            row["amount_incl_tax_usd"] = -row["amount_incl_tax_usd"]
            row["tax_amount_usd"] = -row["tax_amount_usd"]
            self.defect("SIGN_MISMATCH", row)

        # A re-export sends four clean tickets a second time, in a later batch.
        flagged = {key for _, key in self.defects}
        clean = [
            r
            for r in self.pos_lines
            if r["sold_at_local"].startswith("2026-10-19") and pos_key(r) not in flagged
        ]
        for ticket_no in sorted(
            {r["ticket_no"] for r in clean if r["store_code"] in ("NYC", "CHI")}
        )[:4]:
            for row in [r for r in clean if r["ticket_no"] == ticket_no]:
                self.pos_lines.append(
                    row
                    | {
                        "export_batch_id": "B20261020R",
                        "loaded_at": "2026-10-21 03:15:00",
                    }
                )
                self.defect("DUPLICATE_LINE", row)

    # ------------------------------------------------------------------ OMS

    def build_oms(self) -> None:
        order_no = 100000
        for day in days():
            for _ in range(self.rng.randint(9, 15)):
                order_no += 1
                ordered_at = datetime.combine(day, datetime.min.time()) + timedelta(
                    seconds=self.rng.randint(0, 86399)
                )
                picks = self.rng.sample(
                    range(len(PRODUCTS)), self.rng.choice([1, 1, 2])
                )
                lines = [
                    (
                        oms_code(PRODUCTS[i][0]),
                        Decimal(PRODUCTS[i][3] * PRODUCTS[i][5]),
                        self.rng.choice([1, 1, 1, 2]),
                    )
                    for i in picks
                ]
                self.oms_order(f"W{order_no}", ordered_at, lines)

    def oms_order(
        self, order_id: str, ordered_at: datetime, lines: list[tuple], *, clean=False
    ) -> dict:
        """`lines` holds (sku_local, unit price per OMS unit without tax, quantity)."""
        rows = [
            {
                "order_id": order_id,
                "line_id": line_id,
                "sku_local": sku,
                "quantity": quantity,
                "unit_price_usd": money(unit_price),
                "line_amount_usd": money(unit_price * quantity),
            }
            for line_id, (sku, unit_price, quantity) in enumerate(lines, start=1)
        ]
        lines_total = sum(r["line_amount_usd"] for r in rows)
        discount = (
            money(self.rng.choice([25, 50, 100]))
            if not clean and self.rng.random() < 0.12
            else money(0)
        )
        discount = min(discount, money(lines_total / 4))
        shipping = money(self.rng.choice([0, 0, 25]))
        loaded_at = f"{ordered_at.date() + timedelta(days=1):%Y-%m-%d} 04:00:00"
        order = {
            "order_id": order_id,
            "ordered_at_utc": f"{ordered_at:%Y-%m-%d %H:%M:%S}",
            "merchandise_total_usd": lines_total - discount,
            "order_discount_usd": discount,
            "shipping_fee_usd": shipping,
            "order_total_usd": lines_total - discount + shipping,
            "loaded_at": loaded_at,
        }
        self.orders.append(order)
        self.order_lines.extend(r | {"loaded_at": loaded_at} for r in rows)

        if not clean and self.rng.random() < 0.07:
            returned = self.rng.choice(rows)
            returned_at = ordered_at + timedelta(
                days=self.rng.randint(3, 10), seconds=self.rng.randint(0, 40000)
            )
            if returned_at.date() <= LAST_DAY:
                share = money(discount * returned["line_amount_usd"] / lines_total)
                self.oms_return(
                    order_id,
                    returned["line_id"],
                    returned_at,
                    1,
                    (returned["line_amount_usd"] - share) / returned["quantity"],
                )
        return order

    def oms_return(
        self,
        order_id: str,
        line_id: int,
        returned_at: datetime,
        quantity: int,
        unit_refund,
    ) -> dict:
        row = {
            "return_id": f"R{len(self.returns) + 5001}",
            "order_id": order_id,
            "line_id": line_id,
            "returned_at_utc": f"{returned_at:%Y-%m-%d %H:%M:%S}",
            "quantity_returned": quantity,
            "refund_amount_usd": money(unit_refund * quantity),
            "loaded_at": f"{returned_at.date() + timedelta(days=1):%Y-%m-%d} 04:00:00",
        }
        self.returns.append(row)
        return row

    def plant_oms_defects(self) -> None:
        # Lines whose local SKU has no cross-reference row.
        for order_id, day in (
            ("W900001", date(2026, 10, 12)),
            ("W900002", date(2026, 11, 2)),
        ):
            self.oms_order(
                order_id,
                datetime(day.year, day.month, day.day, 15, 20),
                [(OMS_UNMAPPED[0], Decimal(OMS_UNMAPPED[1]), 1)],
                clean=True,
            )
            self.defects.append(("UNMAPPED_PRODUCT", f"oms|{order_id}|1"))

        # Orders whose header does not add up to their lines.
        for order_id, day in (
            ("W900003", date(2026, 10, 20)),
            ("W900004", date(2026, 11, 9)),
        ):
            lines = [
                (oms_code("SK-0001"), Decimal(510), 1),
                (oms_code("FR-0003"), Decimal(210), 1),
            ]
            order = self.oms_order(
                order_id,
                datetime(day.year, day.month, day.day, 18, 5),
                lines,
                clean=True,
            )
            order["merchandise_total_usd"] += money(20)
            order["order_total_usd"] += money(20)
            self.defects.append(("HEADER_LINES_MISMATCH", f"oms|{order_id}"))

        # Returns pointing at an order line that was never exported.
        for order_id, day in (
            ("W777001", date(2026, 10, 27)),
            ("W777002", date(2026, 11, 10)),
        ):
            row = self.oms_return(
                order_id,
                1,
                datetime(day.year, day.month, day.day, 13, 0),
                1,
                Decimal(230),
            )
            self.defects.append(("ORPHAN_RETURN", f"oms|{row['return_id']}"))

    # ---------------------------------------------------------------- output

    def defect(self, code: str, pos_row: dict) -> None:
        self.defects.append((code, pos_key(pos_row)))

    def legacy_daily_sales(self) -> list[dict]:
        """The legacy store datamart: every exported POS row summed, tax included, duplicates and all."""
        totals: dict[tuple[str, str], list] = defaultdict(lambda: [Decimal(0), 0])
        for row in self.pos_lines:
            key = (row["store_code"], row["sold_at_local"][:10])
            totals[key][0] += row["amount_incl_tax_usd"]
            totals[key][1] += 1
        return [
            {
                "store_code": store,
                "business_date": day,
                "sales_incl_tax_usd": amount,
                "line_count": count,
            }
            for (store, day), (amount, count) in sorted(totals.items())
        ]

    def reference(self) -> dict[str, list[dict]]:
        xref = []
        for index, (group_sku, _, _, _, pos_pack, oms_pack) in enumerate(PRODUCTS):
            xref.append(
                {
                    "source_system": "pos",
                    "local_code": pos_code(index),
                    "group_sku": group_sku,
                    "pieces_per_sales_unit": pos_pack,
                }
            )
            xref.append(
                {
                    "source_system": "oms",
                    "local_code": oms_code(group_sku),
                    "group_sku": group_sku,
                    "pieces_per_sales_unit": oms_pack,
                }
            )
        for group_sku in POS_AMBIGUOUS[2]:
            xref.append(
                {
                    "source_system": "pos",
                    "local_code": POS_AMBIGUOUS[0],
                    "group_sku": group_sku,
                    "pieces_per_sales_unit": 1,
                }
            )

        rate_rng = random.Random(SEED + 1)
        rate, fx = Decimal("0.9150"), []
        for day in days(REFERENCE_FIRST_DAY):
            if (
                day.weekday() < 5
            ):  # no fixing at the weekend: the last one carries forward
                rate += Decimal(rate_rng.randint(-25, 25)) / Decimal(10000)
                fx.append({"rate_date": day.isoformat(), "usd_to_eur": rate})

        calendar = [
            {
                "date_day": day.isoformat(),
                "fiscal_year": day.year,
                "fiscal_month": day.month,
                "fiscal_week": day.isocalendar().week,
                "day_name": day.strftime("%A"),
                "is_weekend": str(day.weekday() >= 5).lower(),
            }
            for day in days(REFERENCE_FIRST_DAY)
        ]
        return {
            "stores": [
                dict(
                    zip(
                        (
                            "store_code",
                            "group_store_id",
                            "store_name",
                            "city",
                            "state",
                            "timezone",
                            "channel_code",
                            "sales_tax_rate",
                        ),
                        s,
                        strict=True,
                    )
                )
                for s in STORES
            ],
            "channels": [
                {"channel_code": code, "channel_name": name} for code, name in CHANNELS
            ],
            "group_products": [
                {"group_sku": p[0], "product_name": p[1], "metier": p[2]}
                for p in PRODUCTS
            ],
            "product_xref": sorted(
                xref,
                key=lambda r: (r["source_system"], r["local_code"], r["group_sku"]),
            ),
            "fx_rates": fx,
            "fiscal_calendar": calendar,
        }

    def tables(self) -> dict[str, list[dict]]:
        self.build_pos()
        self.build_oms()
        self.plant_pos_defects()
        self.plant_oms_defects()
        out = {
            "raw_us_pos/pos_sales_lines": sorted(
                self.pos_lines,
                key=lambda r: (r["export_batch_id"], r["ticket_no"], r["line_no"]),
            ),
            "raw_us_pos/legacy_daily_sales": self.legacy_daily_sales(),
            "raw_us_oms/oms_orders": sorted(self.orders, key=lambda r: r["order_id"]),
            "raw_us_oms/oms_order_lines": sorted(
                self.order_lines, key=lambda r: (r["order_id"], r["line_id"])
            ),
            "raw_us_oms/oms_returns": sorted(
                self.returns, key=lambda r: r["return_id"]
            ),
            "ground_truth/planted_defects": [
                {"defect_code": code, "record_key": key}
                for code, key in sorted(self.defects)
            ],
        }
        out.update(
            {f"raw_reference/{name}": rows for name, rows in self.reference().items()}
        )
        return out


def pos_key(row: dict) -> str:
    return f"pos|{row['ticket_no']}|{row['line_no']}"


def write(tables: dict[str, list[dict]], seeds_dir: Path = SEEDS_DIR) -> None:
    for name, rows in tables.items():
        path = seeds_dir / f"{name}.csv"
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(
                handle, fieldnames=list(rows[0]), lineterminator="\n"
            )
            writer.writeheader()
            writer.writerows(rows)


def main() -> int:
    tables = World().tables()
    write(tables)
    for name, rows in tables.items():
        print(f"{name}: {len(rows)} rows")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
