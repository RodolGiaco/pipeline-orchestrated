#!/usr/bin/env bash
#
# Developer entry point for running the same agent pipeline that CI runs.
#
# Selects the model provider and then delegates to scripts/ci/run-task.sh, so a local run and a
# CI run exercise identical validation logic and return identical exit codes.
#
# Configuration:
#   .env.local                             optional; USE_OPENROUTER selects the provider
#   ~/.config/claude-code/openrouter.env   OpenRouter credentials, kept outside the repository
#
# Input, output and exit codes are those of scripts/ci/run-task.sh.
#

set -euo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCAL_ENV="$PROJECT_ROOT/.env.local"
OPENROUTER_ENV="${HOME}/.config/claude-code/openrouter.env"

if [[ -f "$LOCAL_ENV" ]]; then
    source "$LOCAL_ENV"
fi

if [[ "${USE_OPENROUTER:-false}" == "true" ]]; then
    if [[ ! -f "$OPENROUTER_ENV" ]]; then
        printf 'ERROR: OpenRouter environment file not found: %s\n' "$OPENROUTER_ENV" >&2
        exit 1
    fi

    source "$OPENROUTER_ENV"

    printf 'INFO: Using OpenRouter local model: %s\n' "${CLAUDE_MODEL:-openrouter/free}" >&2
else
    unset ANTHROPIC_BASE_URL
    unset ANTHROPIC_AUTH_TOKEN
    unset ANTHROPIC_API_KEY
    unset OPENROUTER_API_KEY
    unset CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY
    unset CLAUDE_CODE_SKIP_FAST_MODE_ORG_CHECK
    unset CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT
    unset CLAUDE_MODEL

    printf 'INFO: Using Claude default authentication and model\n' >&2
fi

exec "$PROJECT_ROOT/scripts/ci/run-task.sh"