---
name: weather-lookup
description: Returns a stub weather forecast for a given location.
  Demo-only catalog filler.
license: Apache-2.0
compatibility: opencode
metadata:
  runtime_iam: []
---

# weather-lookup

Use this skill when the user asks for the weather, temperature,
or forecast for a named city or region (for example, "what's
the weather in Tokyo?").

This is a demonstration skill. It does not consult any live
meteorology API and ships no helper script; the agent surfaces
a canned forecast inline so the demo catalog has a second skill
to rank against `apigee-policy-top10` without consuming external
quota.

When invoked, do this:

1. Surface a stub response to the user in the form
   `weather-lookup: stub forecast -- <city>: <temperature>, <condition>`
   using a plausible canned reading (e.g. `Tokyo: 21C, partly
   cloudy`).
2. Explicitly tell the user this is a demonstration skill that does
   NOT consult a live meteorology provider; production use would
   require wiring a real weather API and adding the corresponding
   `runtime_iam` permissions.
