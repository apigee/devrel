---
name: skill-finder
description: Discovers and installs agentic skills from the customer
  API hub. Two modes — (1) SEARCH AND INSTALL one matching skill by
  natural-language query, verifying its ed25519 signature against
  the trust root(s) installed under keys/; (2) LIST every available
  skill in the catalog as a markdown table, with cursor pagination,
  so the user can browse what's offered before installing.
license: Apache-2.0
compatibility: opencode, antigravity, gemini-cli
metadata:
  # Trust roots are per-deployment: each install has one or more
  # <fingerprint>.pem files under keys/, populated at install time
  # by bin/provision.sh or by the operator. See keys/README.md.
  trusted_signing_key_ids: keys/*.pem
---

# skill-finder

## ⚠️ Runtime requirements (read this first)

This skill **requires** its bundled venv wrapper. The Python
scripts depend on `cryptography`, `google-auth`, `requests`, and
`pyyaml`, which are installed into a per-user venv by the
installer (`bin/install-skill-finder.sh`). They are **not**
available to the system `python3`.

**Always invoke scripts via the wrapper, never via bare
`python3`:**

```bash
# CORRECT - invokes the venv Python via the wrapper:
${SKILL_DIR}/bin/run-with-venv.sh ${SKILL_DIR}/scripts/<script>.py <args>

# WRONG - system python3 will hit ModuleNotFoundError:
python3 ${SKILL_DIR}/scripts/<script>.py <args>
```

The `Command` blocks in this file use the wrapper form. Do not
"simplify" them to `python3 …` — the scripts will fail with
`ModuleNotFoundError: No module named 'cryptography'` (or similar)
and the agent will then waste a turn debugging a configuration
issue that doesn't exist.

If the wrapper at `${SKILL_DIR}/bin/run-with-venv.sh` is missing,
the skill was installed by a pre-v0.1.4 installer. Re-run
`bin/install-skill-finder.sh` to regenerate the wrapper. The
scripts themselves also detect this case at startup and emit an
actionable error pointing back here.

---

This skill has **two modes**. Choose the one that fits the user's
intent:

| User intent | Use this mode | Script |
|:------------|:--------------|:-------|
| "What skills are available?" / "Show me the catalog" / "Browse skills" / "What can the agent do via API hub?" | **List** (browse, no install) | `list_skills.py` |
| "Find a skill that does X" / "Install a skill for Y" / "Look that up in API hub" (where there is one stated need) | **Install** (search + verify + install) | `find_install.py` |

If the user is browsing or exploring, use **List** first; the user
can then ask "install <name>" and you switch to Install with that
name as the query.

## Runtime dispatch

Both modes ship as one behavioural contract that runs on two
runtimes. Pick the invocation path that matches the runtime:

| Runtime | How you invoke the scripts |
|:--------|:---------------------------|
| **OpenCode** | Use the `!`bash`` injection blocks below. OpenCode auto-executes them on SKILL.md load. |
| **Gemini CLI** | Use your bash tool. Run the exact command from the matching `Command` block — substitute `${SKILL_DIR}` with the install path (`~/.gemini/skills/skill-finder` for global installs; `<project>/.agents/skills/skill-finder` for workspace installs), substitute `${ARGUMENTS}` with the user's verbatim query, and `${APIHUB_PROJECT}` / `${APIHUB_LOCATION}` with the values from the shell environment. |
| **Antigravity** | Same as Gemini CLI but `${SKILL_DIR}` is `~/.gemini/antigravity/skills/skill-finder` for global installs (or `<project>/.agents/skills/skill-finder` for workspace installs). |
| **Any other runtime** | Same as Antigravity / Gemini CLI: invoke via whatever bash mechanism the runtime provides. |

---

## Mode 1: Install (search + verify + install one skill)

Use this when the user has a stated need they want fulfilled now.

### Steps

1. Take the user's natural-language need verbatim as the search
   query. Do not paraphrase or simplify.

1a. Before invoking `find_install.py`, verify the user query
    contains NONE of these characters:
    `$` `` ` `` `\` `"` `'` `;` `&` `|` `<` `>` `(` `)` `{` `}`
    (shell metacharacters; they may trigger command injection in
    the bash layer because POSIX double quotes do not suppress
    `$(...)` command substitution or backtick expansion). If any
    are present, REFUSE to invoke and ask the user to rephrase
    the query without special characters.

2. Invoke the bundled discovery script using the runtime path
   from the table above. The exact command is:

   **Command** (OpenCode auto-runs this; on Antigravity / Gemini
   CLI you run it via your bash tool):

   !`python3 ${SKILL_DIR}/scripts/find_install.py \
        --query "${ARGUMENTS}" \
        --project "${APIHUB_PROJECT}" \
        --location "${APIHUB_LOCATION}"`

3. The script prints structured progress; reproduce every printed
   line verbatim to the user — DO NOT summarize. The lines are a
   stable contract. On Antigravity / Gemini CLI, this means: after
   your bash tool returns, surface its full stdout verbatim in
   your reply. Do not edit, reorder, or collapse the
   `[skill-finder]` lines.

4. On success, the script's final line is the runtime-aware
   trailer. On OpenCode, it tells the user to type
   `/reload-skills`. On Antigravity / Gemini CLI, it tells the
   user to re-ask their question. Surface that line verbatim and
   STOP. Do not invoke the newly-installed skill yourself; let
   the user re-ask.

5. On any FAILED line, STOP. Surface the failure to the user with
   the verbatim error message. Do NOT attempt installation again
   on the same invocation.

---

## Mode 2: List (browse the catalog)

Use this when the user wants to see what's available before
committing to install anything.

### Steps

1. Invoke the bundled browse script. The exact command is:

   **Command** (OpenCode auto-runs this; on Antigravity / Gemini
   CLI you run it via your bash tool):

   !`python3 ${SKILL_DIR}/scripts/list_skills.py \
        --project "${APIHUB_PROJECT}" \
        --location "${APIHUB_LOCATION}" \
        --page-size 20`

2. The script prints a markdown table of `name | keywords |
   description`. Surface the table verbatim to the user — DO NOT
   summarize and DO NOT drop the `[skill-finder]` diagnostic
   lines.

3. If the last line of the output is `next-page-token: <token>`,
   there are more skills available. Offer the user the option:
   "There are more skills. Want me to show the next page?". If
   the user says yes, re-invoke with `--page-token "<token>"`
   added to the command (keep the other flags the same).

4. If the user then picks a specific skill name and wants to
   install it, switch to **Mode 1: Install** with that name as
   the `--query` value.

5. On any FAILED line, STOP. Surface the failure verbatim.

---

## Runtime notes

- **OpenCode** auto-detects its skills root at
  `~/.config/opencode/skills/`. `find_install.py` writes there.
  `/reload-skills` rescans.
- **Antigravity / Gemini CLI** auto-detects
  `~/.gemini/config/skills/` (the canonical global skills root).
  `find_install.py` writes there. Both runtimes rescan on the
  next conversation turn — there is no `/reload-skills` slash
  command. The script emits a runtime-aware trailer (`re-ask
  your question — the agent runtime will pick up <name> on the
  next turn`) so the user is not told to type a non-existent
  slash command.
- **APIGEE_SKILLS_INSTALL_ROOT** env var overrides the
  auto-detection if the operator wants to pin install location.
