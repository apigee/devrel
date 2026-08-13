# skill-finder trust roots

This directory is **empty in the source tree** on purpose. It is
populated at install time by one of two mechanisms:

1. **Bootstrap provisioning** -- `bin/provision.sh` in the
   reference repo generates a fresh ed25519 keypair on the
   operator's machine, signs the initial catalog with it, and
   drops the corresponding public key as
   `<fingerprint>.pem` in this directory of the local
   skill-finder install.

2. **Manual trust-root pinning** -- an operator who already
   has a public key (e.g. their org has a pre-existing
   signing key) drops the PEM into this directory as
   `<fingerprint>.pem`.

## What lives here (post-install)

Every file matching the glob `keys/*.pem` is loaded by
`scripts/find_install.py` at verify time. A downloaded skill
manifest is accepted if its `signing_key_id` fingerprint
matches **any** of the trust roots present.

This is the multi-key model: multiple publishers, key rotation
with a grace period, and the ability to fall back to an old
key while a new one is being rolled out are all supported by
adding or removing PEM files.

If this directory is empty at verify time, `find_install.py`
refuses to install anything and prints a clear message
directing the operator to run `bin/provision.sh` or drop a
PEM in themselves.

## Why is this not in the source tree?

The trust root is a **per-deployment secret** in the sense
that each customer owns their own private signing key. Shipping
a shared public key in this repo would either:

- pin every customer to a key they don't own (no rotation, no
  self-signed skills), or
- pin them to a key someone in this repo can rotate under
  them (governance nightmare).

Instead: this repo ships the source code and the installer,
and the trust root is materialised on the customer's machine
during provisioning. Nothing signed by anybody's key ever
enters this repo.

See `docs/architecture.md#trust-model` for the full trust model discussion.
