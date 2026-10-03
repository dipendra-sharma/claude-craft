#!/bin/bash
set -e
mkdir -p tests
cat > confirmation.py <<'PY'
import json
import urllib.request

SLACK_WEBHOOK_URL = "https://hooks.slack.com/services/T000/B000/XXXX"


def confirmation_text(order_id, total_cents):
    return f"Order {order_id} confirmed"


def send_to_slack(text):
    body = json.dumps({"text": text}).encode()
    request = urllib.request.Request(SLACK_WEBHOOK_URL, data=body, headers={"Content-Type": "application/json"})
    urllib.request.urlopen(request, timeout=5)
PY
cat > tests/test_confirmation.py <<'PY'
import unittest

from confirmation import confirmation_text


class ConfirmationTest(unittest.TestCase):
    def test_mentions_order_id(self):
        self.assertIn("A17", confirmation_text("A17", 1250))


if __name__ == "__main__":
    unittest.main()
PY
cat > run-tests.sh <<'SH'
#!/bin/bash
cd "$(dirname "$0")" && PYTHONPATH=. /usr/bin/python3 -m unittest discover -s tests -v 2>&1
SH
chmod +x run-tests.sh
cat > README.md <<'MD'
# Order confirmation

Run the tests with `./run-tests.sh`.
MD
git init -q
git add -A
git -c user.name=fixture -c user.email=fixture@example.invalid commit -qm "Confirmation"
