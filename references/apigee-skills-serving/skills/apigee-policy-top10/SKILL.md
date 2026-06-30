---
name: apigee-policy-top10
description: Reports the top 10 Apigee policy types currently in use
  across deployed proxy revisions in the caller's Apigee org. Reads
  the Apigee Management API only; modifies nothing. Authenticates
  with Application Default Credentials.
license: Apache-2.0
compatibility: opencode
metadata:
  runtime_iam:
    - apigee.proxies.list
    - apigee.deployments.list
    - apigee.proxyrevisions.get
---

# apigee-policy-top10

Use this skill when the user asks "what are the top N policies in
use in my Apigee org" or any close paraphrase.

## Runtime dispatch

This skill ships ONE behavioural contract that runs on two
runtimes. Choose the invocation path that matches the runtime you
are running in. The downstream behaviour and output contract are
identical.

| Runtime | How you invoke `top10.py` |
|:--------|:--------------------------|
| **OpenCode** | Use the `!`bash`` injection below. OpenCode auto-executes the bash on SKILL.md load. |
| Gemini CLI / Claude Code / other agents | (install location varies; consult the agent's documentation) |
| **Any other runtime** | Invoke `top10.py` via whatever bash mechanism the runtime provides, substituting `${SKILL_DIR}` with the install path and `${APIGEE_ORG}` with the value from the shell environment. |

## Steps

1. Resolve the target organization from the environment variable
   `APIGEE_ORG`. If unset, ask the user once for the org id and
   then proceed.

2. Invoke the bundled enumerator using the runtime path from the
   table above. The exact command is:

   **Command** (this is what OpenCode runs automatically; in
   other agent runtimes you run it yourself via the bash tool):

   !`python3 ${SKILL_DIR}/scripts/top10.py --org "${APIGEE_ORG}"`

3. The enumerator's FIRST line of stdout is a customer-facing
   announcement that begins `Querying your Apigee org now —`.
   Surface this line verbatim to the user as it appears, before
   anything else. Do not paraphrase it. (The script is the source
   of truth for the announcement string; the SKILL.md does NOT
   contain a verbatim copy that the agent must remember.)

4. After the announcement, the script prints a markdown table with
   two columns (`policy_type`, `count`) sorted descending.
   Reproduce the table verbatim as the answer. Add a brief preface
   ("Here are the top 10 policy types in use…") and stop.

5. Lines beginning `[apigee-policy-top10]` are log lines for
   operator debugging; do NOT surface them in the answer unless
   they say `FAILED`. On any `FAILED` line, surface the verbatim
   error to the user; do not retry.
