#!/usr/bin/env bash

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