---
name: skill-publisher
description: Publishes a local skill directory to the API hub catalog and
  the GCS bundle store. Runs the four-step author pipeline end to end,
  packing the source tree into a deterministic .skill zip, signing the
  manifest with an ed25519 private key, uploading the zip to GCS, and
  registering the signed manifest with API hub as an API plus Version
  plus Spec triple along with its four attribute values. Idempotent
  by design; re-running with identical inputs produces byte-identical
  output. Includes a bootstrap mode for first-time self-publication.
license: Apache-2.0
compatibility: opencode, antigravity, gemini-cli
metadata:
  pipeline_scripts:
    - scripts.pack_skill
    - scripts.sign_skill
    - scripts.upload_skill
    - scripts.register_skill
---

# skill-publisher

## ⚠️ Runtime requirements (read this first)

This skill **requires** its bundled venv wrapper. `publish.sh`
internally invokes the four `scripts/*` Python modules
(`pack_skill`, `sign_skill`, `upload_skill`, `register_skill`),
which depend on `cryptography`, `google-auth`, `requests`, and
`pyyaml`. Those are installed into a per-user venv by the
installer (`bin/install-skill-publisher.sh`). They are **not**
available to the system `python3`.

**Always invoke `publish.sh` via the wrapper, never via bare
`bash`:**

```bash
# CORRECT - the wrapper exports PYTHON to point at the venv:
${SKILL_DIR}/bin/run-with-venv.sh <args>

# WRONG - publish.sh will fall back to system python3 which
# will hit ModuleNotFoundError mid-pipeline:
bash ${SKILL_DIR}/scripts/publish.sh <args>
```

The `Command` blocks in this file use the wrapper form. Do not
"simplify" them — `publish.sh` reads `$PYTHON` from its
environment and the wrapper is the only thing that sets it
correctly. If you invoke `publish.sh` directly, the four
sub-scripts will fail with `ModuleNotFoundError`.

If the wrapper at `${SKILL_DIR}/bin/run-with-venv.sh` is missing,
the skill was installed by a pre-v0.1.4 installer. Re-run
`bin/install-skill-publisher.sh` to regenerate the wrapper.

---

Use this skill when the user asks to "publish a skill", "ship this
skill to API hub", "upload and register my skill", "release the
skill", or any close paraphrase. This is the single entry point for
author-side distribution; it wraps the four `scripts/*` CLIs from
the upstream source repo into one orchestrated sequence with
fail-fast semantics.

## What this skill does NOT do

- It does **not** create the GCS bucket. The bucket must already
  exist (see repo README §2).
- It does **not** create API hub attribute definitions. Run
  `python3 -m scripts.update_taxonomy` once per project first
  (see repo README §4).
- It does **not** generate or rotate signing keys. The
  ed25519 private key path is an input.
- It does **not** install the published skill into any local
  runtime. That is `skill-finder`'s job.

If any prerequisite is missing the underlying script returns a
non-zero exit code and this skill surfaces it verbatim and stops.

## Inputs

| Variable | Source | Required | Notes |
|:---------|:-------|:---------|:------|
| `SKILL_SRC` | User / agent | yes | Path to a `skills/<name>/` source directory containing `manifest.yaml` and (at minimum) `SKILL.md`. |
| `SKILL_OUT` | Operator | no | Output path for the packed zip. Defaults to `/tmp/${name}-${version}.skill` derived from the manifest. |
| `GCS_BUCKET` | Operator (`${GCS_BUCKET}`) | yes | GCS bucket name (no `gs://` prefix). Must match the bucket portion of the manifest's `gs_uri`. |
| `SIGNING_PRIV_KEY` | Operator (`${SIGNING_PRIV_KEY}`) | yes | Path to the raw 32-byte ed25519 private key. See the upstream README's author-flow section for how to generate one. |
| `APIHUB_PROJECT` | Operator (`${APIHUB_PROJECT}`) | yes | GCP project hosting the API hub instance. |
| `APIHUB_LOCATION` | Operator (`${APIHUB_LOCATION}`) | yes | API hub region (e.g. `us-central1`). |
| `REPO_ROOT` | Auto | no | Root of the upstream source checkout. Defaults to the current working directory. The four `scripts/*` modules must be importable from there. |
| `BOOTSTRAP` | User / agent | no | If set to `1` or `true`, runs the bootstrap path that publishes `skill-publisher` itself. See "Bootstrap mode" below. |

## Runtime dispatch

This skill ships one orchestration contract that runs on multiple
runtimes. Pick the invocation path that matches your runtime; the
behaviour and stdout contract are identical.

| Runtime | How you invoke the publish script |
|:--------|:----------------------------------|
| **OpenCode** | Use the `!`bash`` injection blocks below. OpenCode auto-executes them on SKILL.md load. |
| **Gemini CLI** | Use your bash tool. Run the matching `Command` block, substituting `${SKILL_DIR}` with the install path (`~/.gemini/skills/skill-publisher` for global; `<project>/.agents/skills/skill-publisher` for workspace) and the operator-controlled env vars from the table above. |
| **Antigravity** | Same as Gemini CLI but `${SKILL_DIR}` is `~/.gemini/antigravity/skills/skill-publisher` for global installs. |
| **Any other runtime** | Same as Antigravity / Gemini CLI: invoke via whatever bash mechanism the runtime provides. |

---

## Mode 1: Publish a third-party skill

Use this when the user wants to publish any skill **other than**
`skill-publisher` itself.

### Steps

1. **Resolve the source path.** Take the value from `SKILL_SRC`
   verbatim if provided. Otherwise ask the user once: "Which skill
   directory do you want to publish?" Expect a path like
   `skills/apigee-policy-top10`. Do not paraphrase the answer.

2. **Validate the inputs before invoking bash.** Verify that the
   following are all set and non-empty: `SKILL_SRC`, `GCS_BUCKET`,
   `SIGNING_PRIV_KEY`, `APIHUB_PROJECT`, `APIHUB_LOCATION`. If any
   is missing, REFUSE to invoke and tell the user which one is
   missing. Do not guess.

3. **Reject shell metacharacters in `SKILL_SRC`.** The path is
   interpolated into a bash command via POSIX double quotes, which
   do not suppress `$(...)` command substitution or backtick
   expansion. If `SKILL_SRC` contains any of
   `` ` `` `$` `\` `"` `;` `&` `|` `<` `>` `(` `)` `{` `}`
   REFUSE to invoke and ask the user to rephrase.

4. **Invoke the publish script using the runtime path from the
   table above.** The exact command is:

   **Command** (OpenCode auto-runs this; on Antigravity / Gemini
   CLI run it via your bash tool):

   !`bash ${SKILL_DIR}/scripts/publish.sh \
        --src "${SKILL_SRC}" \
        --bucket "${GCS_BUCKET}" \
        --priv-key "${SIGNING_PRIV_KEY}" \
        --project "${APIHUB_PROJECT}" \
        --location "${APIHUB_LOCATION}"`

5. **Surface the script's stdout verbatim.** The script prints
   one `[skill-publisher] step N/4 ...` line per pipeline step,
   followed by the GCS URI and the API hub resource path on
   success. Reproduce every line as-is; do NOT summarize. The
   lines are a stable contract for log parsing.

6. **On non-zero exit, stop.** Surface the failing step's stderr
   verbatim. Do not retry, do not "fix" the manifest, do not
   re-sign with a different key. The four underlying scripts have
   distinct exit codes (see "Exit code mapping" below); use them
   to give the user an accurate diagnosis.

---

## Mode 2: Bootstrap — publish skill-publisher itself

Use this when the user wants to publish `skill-publisher` for the
first time, or republish it after editing its own source.

### The bootstrap problem

`skill-publisher` cannot use its own installed copy to publish
itself: at first run the installed copy does not yet exist in the
API hub catalog. Once published, subsequent versions of
`skill-publisher` *can* be republished by the currently-installed
copy — but the very first publish is a chicken-and-egg situation.

### Steps

1. **Confirm the user actually means bootstrap.** Ask once: "Do
   you want to publish `skill-publisher` itself (bootstrap mode)?
   This is normally only done by repo maintainers." If the user
   says no, switch to Mode 1.

2. **Validate the inputs** exactly as Mode 1 step 2. `SKILL_SRC`
   for bootstrap is always the path to the in-repo
   `skills/skill-publisher/` directory; default to that if the
   user does not specify.

3. **Invoke with `--bootstrap`.** The bootstrap flag tells
   `publish.sh` to use the repo-local `scripts/publish.sh` (this
   file) directly via the four sibling Python modules in
   `${REPO_ROOT}/scripts/`, rather than relying on any installed
   copy. The exact command is:

   **Command:**

   !`bash ${SKILL_DIR}/scripts/publish.sh \
        --src "${SKILL_SRC:-skills/skill-publisher}" \
        --bucket "${GCS_BUCKET}" \
        --priv-key "${SIGNING_PRIV_KEY}" \
        --project "${APIHUB_PROJECT}" \
        --location "${APIHUB_LOCATION}" \
        --bootstrap`

4. **Surface stdout verbatim** (same as Mode 1 step 5).

5. **On success, advise the user to re-run with Mode 1.** Tell
   them: "skill-publisher is now in the catalog. Any future
   publish — including republishing skill-publisher itself — can
   use the installed copy via skill-finder + this skill, without
   --bootstrap."

---

## Exit code mapping

`publish.sh` exits with the exit code of the **first failing
step**. The mapping below is the union of the four underlying
scripts' exit codes (see each script's docstring for detail):

| Exit code | Meaning | Where it comes from |
|:----------|:--------|:--------------------|
| `0` | All four steps succeeded. | n/a |
| `1` | User error: bad CLI args, missing file, invalid YAML, ADC unavailable, or empty required env var. | any step |
| `2` | System error: filesystem write failure, GCS network error, GCS 404 (bucket not found), or API hub network error. | pack / upload / register |
| `3` | Either (a) cryptographic error during sign (priv key unreadable / wrong length) OR (b) GCS IAM denial (403) during upload OR (c) API hub IAM denial (403) during register. The failing-step log line in stdout disambiguates. | sign / upload / register |
| `4` | API hub rejected the registration because the four attribute definitions are not initialised. Run `python3 -m scripts.update_taxonomy` once and retry. | register only |
| `5` | Packaging policy violation: `scripts/common/` has the wrong file set (missing or extra files), or the source dir is missing `SKILL.md`. | pack only (originally exit 3 in pack_skill; remapped here to disambiguate from sign/IAM). |

The `[skill-publisher] step N/4 FAILED` line printed by
`publish.sh` immediately before exit tells the user which step
failed and what the underlying script's raw exit code was, so the
remap above is auditable, not opaque.

---

## Idempotency

All four underlying scripts are idempotent by design:

- `pack_skill.py` writes the zip with sorted entry order, so
  `sha256(zip)` is stable across builds.
- `sign_skill.py` produces byte-identical output for identical
  inputs (ed25519 is deterministic per RFC 8032; YAML is dumped
  with `sort_keys=True`).
- `upload_skill.py` overwrites the object at the same name —
  re-running uploads the same bytes to the same key.
- `register_skill.py` reads first, only POSTs/PATCHes on diff;
  re-running with no changes makes only `GET` calls.

Therefore re-running `publish.sh` with the same inputs is safe
and observable as zero mutating API calls after the first
successful publish. The skill does NOT need a "dry-run" mode of
its own; pass `--dry-run` through to `register_skill` if you want
to skip the registration step entirely (currently not wired —
file an issue if needed).

---

## Security notes

- The ed25519 private key path is the only secret this skill
  touches. It is read by `sign_skill.py`, never logged, never
  uploaded. The key file should have mode `0600`.
- The signature is computed over the **canonical** manifest bytes
  (see `scripts/common/canonical.py`). Any post-signing edit to
  the manifest invalidates the signature; `skill-finder` will
  refuse to install the skill.
- The `signing_key_id` field is the sha256 of the **public** key,
  not the private key. It is safe to publish. `skill-finder`
  cross-checks it against installed trust roots
  (`keys/*.pem`); a manifest signed by a key not in
  the trust root is rejected client-side. Multiple keys can be
  installed side-by-side to support multi-publisher orgs and
  zero-downtime key rotation.
- GCS uploads use ADC. The operator must have
  `storage.objects.create` on the target bucket. The skill does
  not run a permission pre-flight; it relies on the upload itself
  to surface 403 as exit code 3.

---

## Common rationalizations

| Rationalization | Why it fails here |
|:----------------|:------------------|
| "I'll skip the pack step — the zip already exists on disk." | `sign_skill.py` writes `zip_sha256` from a fresh sha256 of the zip bytes. If the zip on disk is stale (e.g. a SKILL.md edit hasn't been re-packed), the manifest commits to a hash that does not match the bytes `skill-finder` will fetch from GCS, and every install fails signature verification. Always run pack-then-sign in one sequence. |
| "I'll re-sign without re-packing — only the manifest changed." | Same trap. If the manifest text changed but the zip bytes also changed (because `pack_skill` would have noticed a source-tree edit), `zip_sha256` is wrong. The pipeline is a unit; do not split it. |
| "I'll upload before signing — saves a round trip." | If signing fails (bad key, invalid manifest), the GCS object now points at a zip whose manifest is unsigned. Any client that fetches it gets a manifest that fails schema validation. Sign first, upload second, register third — this order is enforced by `publish.sh`. |
| "I'll register before uploading — the catalog can wait for the zip." | `skill-finder` fetches the zip immediately after the manifest passes signature check. A registered manifest pointing at a non-existent `gs_uri` returns 404 to every install attempt. Upload before register. |
| "I'll use `gcloud storage cp` instead of `upload_skill.py`." | The script uses ADC + the GCS JSON API directly (the runtime tree is capped at four packages, so no `google-cloud-storage` dependency). It also has structured exit codes that this skill remaps. Using `gcloud` breaks the exit-code contract and the offline test suite. |
| "I'll skip `update_taxonomy.py` — the attributes will auto-create." | They will not. `register_skill.py` PATCHes attribute *values* by reference to attribute *definitions* that must already exist. Without `update_taxonomy.py` having run once, the PATCH returns 400 and this skill exits 4. The first publish in a new project always needs `update_taxonomy.py` first. |
| "I'll catch the failure of step 2 and retry step 2 only." | Don't. If sign fails after pack succeeded, the zip on disk is fine but the manifest is broken — re-running the whole pipeline is safe (pack is deterministic) and avoids the "stale zip" trap above. Always retry the whole pipeline, never a single step. |

---

## Layout

```
skills/skill-publisher/
  SKILL.md                # this file
  manifest.yaml           # unsigned template; sign-step rewrites
                          # zip_sha256, signing_key_id, signature
                          # in place
  scripts/
    publish.sh            # the bash orchestrator that runs the
                          # four scripts/* modules in order
```

`publish.sh` is the entire runtime surface of this skill. It
shells out to:

- `python3 -m scripts.pack_skill   --src <SKILL_SRC> --out <SKILL_OUT>`
- `python3 -m scripts.sign_skill   --manifest <SKILL_SRC>/manifest.yaml --zip <SKILL_OUT> --priv-key <SIGNING_PRIV_KEY> --in-place`
- `python3 -m scripts.upload_skill --zip <SKILL_OUT> --bucket <GCS_BUCKET> --object-name <name>-<version>.skill`
- `python3 -m scripts.register_skill --manifest <SKILL_SRC>/manifest.yaml --project <APIHUB_PROJECT> --location <APIHUB_LOCATION>`

The four module paths are stable; if the repo ever renames them,
update `publish.sh` and bump the skill version.
