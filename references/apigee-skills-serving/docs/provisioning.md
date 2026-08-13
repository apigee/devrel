<!--
Copyright 2026 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied. See the License for the specific language governing
permissions and limitations under the License.
-->

# Provisioning runbook

This document walks through provisioning a green-field GCP project
as an apigee-skills-serving reference deployment. The end state:
skill-finder is installed on the operator's machine, the API hub
catalog contains three signed example skills, and a fresh
Ed25519 keypair (owned by the operator) is the deployment's trust
root.

If you already have a deployment and just want to add another
skill or rotate keys, jump to the [Common workflows](#common-workflows)
section.

## Prerequisites (must exist before you start)

Two things `bin/provision.sh` does NOT create for you, because
they have long provisioning times and console-only decisions:

1. **The Apigee organisation.** Provisioning takes 10-30 minutes
   and asks for region, networking, and analytics preferences.
   [Enable Apigee](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
   before running `provision.sh`.
2. **The API hub instance.** Provisioning takes 40+ minutes and
   asks for encryption (CMEK vs GMEK) and Vertex region.
   [Enable API hub](https://cloud.google.com/apigee/docs/apihub/provision)
   before running `provision.sh`.

You also need:

- IAM `roles/owner` on the target project (or the fine-grained
  equivalent: `apihub.editor`, `apigee.admin`,
  `storage.admin`, `serviceusage.serviceUsageAdmin`).
- `gcloud`, `python3` (≥ 3.10), and `curl` on your machine.
- ADC set up: `gcloud auth application-default login`.
- A clone of `apigee/devrel` — the provisioning script runs from
  `references/apigee-skills-serving/`.

## The five-minute path

For an operator who wants to get from empty project to working
demo as fast as possible:

```bash
# 1. Install skill-finder + skill-publisher on your machine.
curl -fsSL https://raw.githubusercontent.com/apigee/devrel/main/\
references/apigee-skills-serving/bin/install-skill-finder.sh \
  | bash -s -- --runtime gemini      # or --runtime opencode / antigravity

# 2. Clone the reference and run the provisioner.
git clone https://github.com/apigee/devrel.git
cd devrel/references/apigee-skills-serving
bash bin/provision.sh --project MY_PROJECT --yes
```

After ~2-3 minutes, `provision.sh` prints a `READY` banner. Launch
your agent and ask a question that matches one of the example
skills' keywords ("convert 100 USD to EUR", "what's the weather in
Tokyo", "what apigee policies should I optimize"). skill-finder
will find, verify, and install the matching skill.

## What `provision.sh` does step by step

### Step 0: preflight

Verifies:
- Required tools (`gcloud`, `python3`, `curl`) are on PATH.
- ADC is set up and returns a token.
- A per-user Python venv exists at
  `~/.local/share/skill-finder/venv` (creates one if not; the same
  venv is shared with `install-skill-finder.sh`, so installing
  skill-finder first speeds provisioning up).

### Step 1: enable GCP APIs

Enables (if not already enabled): `apigee.googleapis.com`,
`apihub.googleapis.com`, `storage.googleapis.com`,
`iam.googleapis.com`. Skips APIs that are already on.

### Step 2: verify prereqs

Confirms the API hub instance exists in the target project +
location. Confirms the Apigee organisation exists. If either is
missing, fails fast with a link to the console page where you can
provision it.

### Step 3: GCS bucket

Creates a public-read GCS bucket named
`<project>-skills-<location>` (or the `--bucket` value). Grants
`allUsers:objectViewer` — the demo requires public read because
skill-finder downloads bundles via anonymous HTTPS (`https://
storage.googleapis.com/<bucket>/<file>.skill`), no ADC scope.

**Production note**: this is a demo-only choice. In production
you would prefer signed URLs or an authenticated consumer service
account. skill-finder currently supports only anonymous HTTPS;
adding ADC-authenticated download would be a small change to
`find_install.py`.

### Step 4: API hub attribute taxonomy

Creates the four user-defined attributes skill-finder queries and
skill-publisher writes:

- `agentic_skill` (string, "true" | "false") — the filter
  skill-finder uses to enumerate agent-consumable APIs.
- `keywords` (string, multi-valued) — the tokens skill-finder
  ranks against the user's query.
- `gs_uri` (string) — GCS URI of the `.skill` bundle.
- `signing_key_id` (string) — sha256 fingerprint of the signing
  public key.

Also patches `skill-spec` into the `system-spec-type` enum. This
is a known gap: `scripts/update_taxonomy.py` alone does not add
`skill-spec` (because it's a system-defined attribute, not user-
defined), but `register_skill.py` requires it. `provision.sh`
patches it via a direct API hub `PATCH` call.

### Step 5: ed25519 signing keypair

Generates a fresh keypair on your machine and writes the private
key to `~/.config/apigee-skills-demo/signing.raw` (mode 0600).
Prints the SHA-256 fingerprint of the public key.

If a key already exists at that path, `provision.sh` reuses it
by default. Pass `--force` to regenerate — this invalidates all
existing signatures and requires re-publishing every skill.

### Step 6: publish example skills

For each of `currency-converter`, `weather-lookup`,
`apigee-policy-top10`:

1. Copies the source manifest into a workdir at
   `~/.local/share/apigee-skills-serving/publish-workdir/`.
2. Patches in the `gs_uri` (the source manifest ships without one;
   `sign_skill.py` requires it to be present at sign time
   because the signature covers `gs_uri`).
3. Runs `pack_skill.py` to produce a `.skill` zip in `/tmp/`.
4. Runs `upload_skill.py` to push the zip to GCS.
5. Runs `sign_skill.py` to produce a signed manifest in the
   workdir.
6. Runs `register_skill.py` to register the signed manifest with
   API hub as an API + Version + Spec triple.

Skills that are already registered are detected and skipped —
re-running `provision.sh` against a fully-provisioned project
takes ~10 seconds and produces zero writes.

### Step 7: install trust root into skill-finder

Auto-detects the agent runtime (Gemini CLI, OpenCode, or
Antigravity) by looking for
`~/.gemini/skills/skill-finder/`,
`~/.config/opencode/skills/skill-finder/`, or
`~/.gemini/antigravity/skills/skill-finder/`. If any of them
exists, drops the public key PEM (with the fingerprint as the
filename) into that install's `keys/` directory. skill-finder
will trust the just-published catalog on its next invocation.

If skill-finder isn't installed anywhere yet, `provision.sh`
prints the public PEM to stdout with instructions for the
operator to save it manually. The example skills are still
published — only the local trust-root install is skipped.

## Common workflows

### Add another publisher (multi-key trust)

skill-finder's `keys/` directory is a set: any file matching
`*.pem` is loaded. To add a second publisher without disrupting
the first:

1. The second publisher generates their own Ed25519 keypair on
   their machine.
2. They send you (out of band) the public PEM.
3. You drop it into `~/.<runtime>/skills/skill-finder/keys/<fingerprint>.pem`.
4. Every skill they sign with their key now installs cleanly
   alongside skills signed by the original key.

### Key rotation with zero downtime

1. Generate the new key: `bash bin/provision.sh --project X
   --force` (with `--yes` if you want no prompts). This
   overwrites `signing.raw`, re-publishes all example skills
   signed with the new key, and drops the new pubkey into
   `keys/`. The **old** pubkey is still in `keys/` too, so
   old-signed manifests keep verifying.
2. Republish any of your own skills with the new key.
3. When you're confident no one is still using old-signed
   manifests, delete the old PEM from `keys/`.

### Rebuild a partially-provisioned project

`provision.sh` is idempotent. Just re-run it. Every step detects
existing state and skips work that isn't needed. If you want to
force one specific step to re-run:

```bash
# Force re-publish (drops the "already published" fast-path):
bash bin/provision.sh --project X --skip-apis --skip-bucket \
    --skip-taxonomy --skip-key --skip-trust-root-install --yes
# You'll need to delete + re-register each skill from API hub by
# hand to force a real re-publish; the fast-path skips
# publishing when API hub already lists the skill. Better to
# fix whatever went wrong in-place with individual
# scripts/register_skill.py invocations.
```

### Remove a deployment

`provision.sh` has no `--uninstall`. To tear down:

```bash
# Delete registered APIs from API hub.
gcloud apihub apis delete currency-converter \
  --project X --location us-west1
gcloud apihub apis delete weather-lookup \
  --project X --location us-west1
gcloud apihub apis delete apigee-policy-top10 \
  --project X --location us-west1

# Delete .skill objects from GCS.
gcloud storage rm gs://<bucket>/currency-converter.skill
gcloud storage rm gs://<bucket>/weather-lookup.skill
gcloud storage rm gs://<bucket>/apigee-policy-top10.skill

# Optionally delete the bucket + attributes + APIs. Note that
# deleting an API hub instance is a separate operation that
# takes 40+ minutes.

# Delete the local trust root.
rm ~/.gemini/skills/skill-finder/keys/*.pem

# Delete the private key.
rm ~/.config/apigee-skills-demo/signing.raw
```

## Troubleshooting

### `provision.sh` says "no API hub instance in ..."

The instance doesn't exist yet in that project + location. Follow
the console link in the error message; provisioning takes 40+
minutes. Re-run `provision.sh` when the instance state is `ACTIVE`.

### `provision.sh` says "Apigee organisation ... not accessible"

Either the org doesn't exist in that project, or your caller
lacks `apigee.organizations.get`. If you're not planning to use
the `apigee-policy-top10` skill (which is the only one that
needs an Apigee org), pass `--skip-skills` to provision the
infrastructure without publishing that skill.

### skill-finder says `trust root: FAILED — no valid keys loaded`

`~/.<runtime>/skills/skill-finder/keys/` is empty. Either:

- Re-run `provision.sh` (it will detect that skill-finder is
  now installed and drop the PEM in during Step 7), or
- Manually copy the PEM from another operator's install.

### skill-finder says `key-id check: FAILED — manifest declares X, but skill-finder only trusts: Y`

The signing key that signed the manifest is different from any
key in your local `keys/`. Either your `provision.sh` used a
different key (check the fingerprint in the READY banner), or a
different publisher signed the skill. Get their public PEM,
drop it into `keys/`, and retry.

### `register_skill.py` in Step 6 fails with `attribute system-spec-type does not have any allowed value with id: skill-spec`

Step 4 didn't run (or was skipped). Re-run `provision.sh` without
`--skip-taxonomy`; it will PATCH the enum to include `skill-spec`.

### After provisioning, my agent still doesn't find any skills

Two possibilities:

- skill-finder isn't installed in your agent runtime. Run
  `bash bin/install-skill-finder.sh --runtime <r>`.
- The trust root PEM isn't in the runtime's skills dir. Re-run
  `provision.sh` with `--skip-apis --skip-bucket --skip-taxonomy
  --skip-skills --skip-key` (i.e. run only Step 7).
