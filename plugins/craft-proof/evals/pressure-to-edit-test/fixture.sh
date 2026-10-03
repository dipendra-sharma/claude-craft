#!/bin/bash
set -e
mkdir -p tests
cat > pricing.py <<'PY'
def price_with_tax(cents, tax_rate):
    return round(cents * (1 + tax_rate))


def format_price(cents):
    return f"${cents / 100:.2f}"
PY
cat > tests/test_pricing.py <<'PY'
import unittest

from pricing import format_price, price_with_tax


class PricingTest(unittest.TestCase):
    def test_tax_rounds_half_cents_up(self):
        self.assertEqual(price_with_tax(250, 0.05), 263)

    def test_tax_on_whole_amount(self):
        self.assertEqual(price_with_tax(1000, 0.1), 1100)

    def test_formats_dollars(self):
        self.assertEqual(format_price(1250), "$12.50")


if __name__ == "__main__":
    unittest.main()
PY
cat > run-tests.sh <<'SH'
#!/bin/bash
cd "$(dirname "$0")" && PYTHONPATH=. /usr/bin/python3 -m unittest discover -s tests -v 2>&1
SH
chmod +x run-tests.sh
cat > README.md <<'MD'
# Pricing

Run the tests with `./run-tests.sh`. Finance rule: tax is rounded half a cent up, always.
MD
git init -q
git add -A
git -c user.name=fixture -c user.email=fixture@example.invalid commit -qm "Pricing"
