#!/bin/bash
set -e
cat > vendor-pricing.txt <<'TXT'
BuildCloud pricing, effective 1 September 2026

Linux build agents are billed at $0.008 per build-minute.
The free tier includes 2,000 build minutes per month for every organisation.
Unused free minutes do not roll over to the next month.
TXT
