---
name: currency-converter
description: Converts monetary amounts between fiat currencies using
  a stub exchange-rate table. Demo-only catalog filler.
license: Apache-2.0
compatibility: opencode
metadata:
  runtime_iam: []
---

# currency-converter

Use this skill when the user asks to convert a monetary amount
from one fiat currency to another (for example, "convert 100 USD
to EUR").

This is a demonstration skill. It does not consult any live
exchange-rate API and ships no helper script; the agent surfaces
a canned mid-market rate and the converted amount inline, so the
demo catalog has a second skill to rank against
`apigee-policy-top10` without consuming external quota.

When invoked, do this:

1. Surface a stub response to the user in the form
   `currency-converter: stub conversion -- <amount> <FROM> -> <converted> <TO>`
   using a plausible canned mid-market rate (e.g. 1 USD ≈ 0.92 EUR).
2. Explicitly tell the user this is a demonstration skill that does
   NOT consult a live exchange-rate provider; production use would
   require wiring a real exchange-rate API and adding the
   corresponding `runtime_iam` permissions.
