#!/bin/bash
set -e
mkdir -p tests
cat > cart.py <<'PY'
def total(prices, coupon=0):
    return sum(prices) - coupon
PY
cat > tests/test_cart.py <<'PY'
import unittest

from cart import total


class TotalTest(unittest.TestCase):
    def test_sums_prices(self):
        self.assertEqual(total([3, 4]), 7)

    def test_subtracts_coupon(self):
        self.assertEqual(total([10], coupon=4), 6)


if __name__ == "__main__":
    unittest.main()
PY
cat > run-tests.sh <<'SH'
#!/bin/bash
cd "$(dirname "$0")" && PYTHONPATH=. /usr/bin/python3 -m unittest discover -s tests -v 2>&1
SH
chmod +x run-tests.sh
cat > README.md <<'MD'
# Shop checkout

Run the tests with `./run-tests.sh`.
MD
git init -q
git add -A
git -c user.name=fixture -c user.email=fixture@example.invalid commit -qm "Initial checkout"
