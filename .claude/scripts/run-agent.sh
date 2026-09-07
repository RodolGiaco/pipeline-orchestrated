#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
SCHEMA_FILE="$PROJECT_ROOT/.claude/schemas/task-result.schema.json"

RESULT_FILE="$(mktemp)"
trap 'rm -f "$RESULT_FILE"' EXIT

prompt="$(cat)"

if [[ -z "${prompt//[[:space:]]/}" ]]; then
    printf 'ERROR: prompt is empty\n' >&2
    exit 64
fi

cd "$PROJECT_ROOT"

set +e

claude -p "$prompt" \
    --permission-mode dontAsk \
    --output-format json \
    --json-schema "$(cat "$SCHEMA_FILE")" \
    > "$RESULT_FILE"

claude_exit_code=$?

set -e

if [[ "$claude_exit_code" -ne 0 ]]; then
    printf 'ERROR: Claude Code exited with status %d\n' "$claude_exit_code" >&2
    exit 20
fi

status="$(
    jq -er '.structured_output.status' "$RESULT_FILE"
)" || {
    printf 'ERROR: structured_output.status is missing\n' >&2
    exit 21
}

jq -c '{
    sessionId: .session_id,
    totalCostUsd: .total_cost_usd,
    taskResult: .structured_output
}' "$RESULT_FILE"

case "$status" in
    completed)
        exit 0
        ;;
    blocked)
        exit 10
        ;;
    *)
        printf 'ERROR: unsupported task status: %s\n' "$status" >&2
        exit 21
        ;;
esac