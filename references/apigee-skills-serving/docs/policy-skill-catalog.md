# `apigee-policy-top10` example skill

`skills/apigee-policy-top10/` is a worked example of a non-trivial
skill: one that bundles operator-facing instructions (`SKILL.md`) with
a Python helper (`scripts/top10.py`) and produces structured output
the agent can interpret.

## What the skill does

When an agent loads this skill, it learns about the ten Apigee policies
that the field engineering team most often recommends to customers:

| Policy                       | Typical use                                            |
| ---------------------------- | ------------------------------------------------------ |
| `VerifyAPIKey`               | Validate consumer API keys.                            |
| `OAuthV2` (verify/generate)  | OAuth 2.0 token issuance and validation.               |
| `Quota`                      | Per-consumer or per-product rate limits.               |
| `SpikeArrest`                | Smooth traffic spikes; protect backends.               |
| `ResponseCache`              | Cache backend responses by key.                        |
| `JSONThreatProtection`       | Reject malicious JSON payloads.                        |
| `XMLThreatProtection`        | Reject malicious XML payloads.                         |
| `AssignMessage`              | Mutate request/response messages.                      |
| `ExtractVariables`           | Pull values from path, header, query, body.            |
| `JavaScript` / `JavaCallout` | Custom logic when out-of-the-box policies are not enough. |

The agent uses the skill's `SKILL.md` to recognize when a user's
question maps to one of these patterns ("how do I rate-limit by
consumer?" → recommend `Quota`).

The bundled `scripts/top10.py` enumerates which of these ten policies
are present in your Apigee organization, by querying the proxy
inventory and parsing each proxy's `apiproxy/policies/` directory. The
agent can invoke this script to ground its recommendations in what the
user actually has deployed.

## Why ship this as a skill rather than a doc?

The information *is* in Apigee's documentation. Skills add three
things:

1. **Discoverability through API hub.** The skill is registered with
   `skill-compatible=true` and queryable by name or keyword. An agent
   searching for "Apigee policy guidance" finds it without an out-of-
   band link.
2. **Runtime verification.** The bundled script tells the agent which
   policies are *actually* deployed, so its recommendations target the
   user's environment, not a generic Apigee install.
3. **Versioning.** The list of "top 10" evolves. Publishing as a
   versioned skill lets operators upgrade or pin specific revisions in
   the same way they pin API proxy versions.

## Output contract

The script emits a deterministic announcement string as its first line
of stdout, before any work begins:

```text
Querying your Apigee org now — this enumerates every deployed proxy
revision and may take 20-60 seconds for orgs with 50+ proxies. No data
is modified.
```

This is a deliberate "Hyrum's Law" contract: agents that parse the
script's output rely on this line appearing first and verbatim. Any
change to the wording will surface in the test suite via
`tests/test_apigee_top10.py` (which byte-compares the line against
`tests/fixtures/announcement.txt`).

Subsequent log lines are operator-facing and use the
`[apigee-policy-top10]` prefix so they can be filtered from agent
console output.

The script exits `0` on success; non-zero with a `FAILED` line
prefixed `[apigee-policy-top10]` on any error. Exit codes follow the
same convention as the publisher scripts (see
[`architecture.md`](architecture.md#failure-modes)).

## How to invoke

After installing the skill (via the publish-and-install walkthrough),
an agent runtime that loads it will have the `SKILL.md` in context. A
user prompt like *"What policies do I have deployed that I should be
using more of?"* will cause the agent to invoke `top10.py`, parse its
JSON output, and reason about the gaps.

To run the script manually:

```bash
export APIGEE_ORG="your-apigee-org"
python3 skills/apigee-policy-top10/scripts/top10.py
```

The script uses Application Default Credentials; ensure
`gcloud auth application-default login` is set up first.

## When to copy this pattern

Use `apigee-policy-top10` as a template when your skill needs to:

- Combine static guidance (in `SKILL.md`) with a runtime probe of the
  user's environment.
- Surface structured data the agent will interpret (e.g., a JSON
  inventory).
- Emit a verbatim operator-facing line that consumers may parse.

Use the simpler `currency-converter` or `weather-lookup` examples
when your skill is just instructions plus optional HTTP-call recipes,
without a local helper script.
