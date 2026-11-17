#!/usr/bin/env bash
# Build a small demo repo for recording a hunk review.
# Usage: demo/setup-demo-repo.sh <parent-dir>
# Creates <parent-dir>/invoice-demo (branch round-lines-and-discount, checked out)
# and <parent-dir>/invoice-demo-origin.git (so that origin/main exists).
set -eu

[ $# -eq 1 ] || { echo "usage: $0 <parent-dir>" >&2; exit 2; }
PARENT=$1
REPO="$PARENT/invoice-demo"
ORIGIN="$PARENT/invoice-demo-origin.git"

[ ! -e "$REPO" ] && [ ! -e "$ORIGIN" ] || { echo "already exists: $REPO or $ORIGIN" >&2; exit 1; }
mkdir -p "$PARENT"

git init -q --bare -b main "$ORIGIN"
git init -q -b main "$REPO"
cd "$REPO"
git config user.name "Demo Author"
git config user.email "demo@example.com"
git remote add origin "$ORIGIN"

cat >README.md <<'EOF'
# invoice-demo

A tiny invoice calculator. Run it with:

    python3 cli.py items.csv
EOF

printf '__pycache__/\n' >.gitignore

cat >items.csv <<'EOF'
description,quantity,unit_price
Consulting hour,12,95.00
Domain renewal,1,14.99
Sticker pack,30,0.335
EOF

cat >invoice.py <<'EOF'
"""Tiny invoice calculator."""
from dataclasses import dataclass


@dataclass
class LineItem:
    description: str
    quantity: int
    unit_price: float


def line_total(item):
    return item.quantity * item.unit_price


def format_money(amount):
    return f"${amount:,.2f}"


def format_line(item):
    total = format_money(line_total(item))
    return f"{item.description:<24} {item.quantity:>3} x {format_money(item.unit_price):>9} = {total:>10}"


def invoice_total(items):
    return sum(line_total(item) for item in items)


def render_invoice(items):
    lines = [format_line(item) for item in items]
    lines.append("-" * 52)
    lines.append(f"{'TOTAL':<42} {format_money(invoice_total(items)):>10}")
    return "\n".join(lines)
EOF

cat >cli.py <<'EOF'
"""Command line entry point: python3 cli.py items.csv"""
import csv
import sys

from invoice import LineItem, render_invoice


def load_items(path):
    with open(path, newline="") as handle:
        return [
            LineItem(row["description"], int(row["quantity"]), float(row["unit_price"]))
            for row in csv.DictReader(handle)
        ]


def main(argv):
    if len(argv) != 2:
        print("usage: python3 cli.py items.csv")
        return 2
    print(render_invoice(load_items(argv[1])))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
EOF

git add -A
git commit -q -m "Add invoice calculator and CLI"
git push -q origin main
git fetch -q origin

git switch -q -c round-lines-and-discount

cat >invoice.py <<'EOF'
"""Tiny invoice calculator."""
from dataclasses import dataclass
from decimal import ROUND_HALF_UP, Decimal

CENT = Decimal("0.01")


@dataclass
class LineItem:
    description: str
    quantity: int
    unit_price: Decimal


def line_total(item):
    return (item.quantity * item.unit_price).quantize(CENT, rounding=ROUND_HALF_UP)


def format_money(amount):
    return f"${amount:,.2f}"


def format_line(item):
    total = format_money(line_total(item))
    return f"{item.description:<24} {item.quantity:>3} x {format_money(item.unit_price):>9} = {total:>10}"


def apply_discount(subtotal, discount_percent):
    discount = subtotal * Decimal(discount_percent) / 100
    return (subtotal - discount).quantize(CENT, rounding=ROUND_HALF_UP)


def invoice_total(items, discount_percent=0):
    subtotal = sum(line_total(item) for item in items)
    return apply_discount(subtotal, discount_percent)


def render_invoice(items, discount_percent=0):
    lines = [format_line(item) for item in items]
    lines.append("-" * 52)
    if discount_percent:
        lines.append(f"{'DISCOUNT':<42} {discount_percent:>9}%")
    lines.append(f"{'TOTAL':<42} {format_money(invoice_total(items, discount_percent)):>10}")
    return "\n".join(lines)
EOF

cat >cli.py <<'EOF'
"""Command line entry point: python3 cli.py items.csv [--discount PERCENT]"""
import argparse
import csv
import sys
from decimal import Decimal

from invoice import LineItem, render_invoice


def load_items(path):
    with open(path, newline="") as handle:
        return [
            LineItem(row["description"], int(row["quantity"]), Decimal(row["unit_price"]))
            for row in csv.DictReader(handle)
        ]


def main(argv):
    parser = argparse.ArgumentParser(prog="cli.py")
    parser.add_argument("csv_path")
    parser.add_argument("--discount", type=int, default=0, help="percent off the subtotal")
    args = parser.parse_args(argv[1:])
    print(render_invoice(load_items(args.csv_path), args.discount))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
EOF

cat >test_invoice.py <<'EOF'
import unittest
from decimal import Decimal

from invoice import LineItem, apply_discount, invoice_total, line_total


class InvoiceTests(unittest.TestCase):
    def test_line_total_rounds_half_up(self):
        item = LineItem("Sticker", 3, Decimal("0.335"))
        self.assertEqual(line_total(item), Decimal("1.01"))

    def test_total_sums_rounded_lines(self):
        items = [LineItem("A", 1, Decimal("0.005")), LineItem("B", 1, Decimal("0.005"))]
        self.assertEqual(invoice_total(items), Decimal("0.02"))

    def test_ten_percent_discount(self):
        self.assertEqual(apply_discount(Decimal("200.00"), 10), Decimal("180.00"))

    def test_no_discount_by_default(self):
        items = [LineItem("A", 2, Decimal("9.99"))]
        self.assertEqual(invoice_total(items), Decimal("19.98"))


if __name__ == "__main__":
    unittest.main()
EOF

git add -A
git commit -q -m "Round line items to cents and add a percent discount"
echo "Built $REPO on branch round-lines-and-discount"
