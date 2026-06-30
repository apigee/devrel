#!/usr/bin/env bash

# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Helper: print instructions for installing the apigee-proxy-skill MCP
# server locally so the agent can drive it via stdio (Gemini CLI,
# Claude Code, Cursor, etc.) or via HTTP (Cloud Run production deploy).
#
# This script intentionally does NOT install anything itself -- the
# MCP server source lives in a separate repo (github.com/.../apigee-
# proxy-skill) and the operator owns the install path (pip, container,
# Cloud Run). Calling this with no arguments prints the canonical
# install recipe; calling with --json emits a machine-readable form.

set -euo pipefail

print_human() {
    cat <<'EOF'
apigee-proxy-skill — install instructions
==========================================

The published skill (this catalog entry) is the SKILL.md the agent
reads. The actual 18 MCP tools live in a separate Python package /
container that you install once on the machine running the agent.

LOCAL DEMO (stdio, no JWT, single machine)
------------------------------------------
  git clone https://github.com/<your-org>/apigee-proxy-skill
  cd apigee-proxy-skill
  pip install --user -e mcp-server/

  # Confirm console scripts are on PATH
  which apigee-skill-server-demo  # local stdio (Gemini CLI / Claude Code)
  which apigee-skill-server       # production HTTP (Cloud Run)

  # For Gemini CLI specifically:
  gemini extensions link "$(pwd)/.gemini/extensions/apigee-proxy-skill"
  gemini extensions list   # should show apigee-proxy-skill (0.1.0)
  gemini mcp list          # should show "Connected (stdio)"

  # Launch:
  cd /tmp/demo && gemini
  # then ask: "scaffold an Apigee proxy called billing with target
  #            https://api.example.com and add a VerifyAPIKey policy"

PRODUCTION (Cloud Run, JWT auth, Workload Identity Federation)
--------------------------------------------------------------
  # In the apigee-proxy-skill repo:
  bash scripts/provision-wif.sh \
       --project=$PROJECT --pool=$POOL --provider=$PROVIDER \
       --issuer-uri=$ISSUER --allowed-audiences=$AUDIENCE
  bash scripts/deploy-cloud-run.sh \
       --project=$PROJECT --region=$REGION --image=$IMAGE

  # Then configure the MCP host (Gemini CLI, Claude Code, ...) to
  # use the HTTP transport pointing at the Cloud Run URL with
  # OAuth/ADC. See https://docs.cloud.google.com/mcp/configure-mcp-ai-application

For the full design + ADRs + verification report, see this skill's
documentation directory in the upstream repo.
EOF
}

print_json() {
    cat <<'EOF'
{
  "name": "apigee-proxy-skill",
  "type": "mcp-server-wrapper",
  "upstream_repo": "github.com/<your-org>/apigee-proxy-skill",
  "install_modes": {
    "local_demo": {
      "transport": "stdio",
      "auth": "none",
      "command": "apigee-skill-server-demo",
      "install": "pip install --user -e mcp-server/"
    },
    "production": {
      "transport": "http",
      "auth": "jwt-via-workload-identity-federation",
      "command": "apigee-skill-server",
      "install": "scripts/deploy-cloud-run.sh + scripts/provision-wif.sh"
    }
  },
  "tools_exposed": 18,
  "policy_templates": 25,
  "resource_types": 9
}
EOF
}

case "${1:-}" in
    --json) print_json ;;
    --help|-h) print_human ;;
    "") print_human ;;
    *) echo "usage: $0 [--json|--help]" >&2; exit 64 ;;
esac
