#!/usr/bin/env bash
#
# Runs Claude Code headless against a prompt read from stdin and normalises the result.
#
# The agent is constrained by .claude/schemas/task-result.schema.json, so the caller receives
# a predictable object instead of free-form model output.
#
# Input  : task prompt on stdin
# Output : {sessionId, totalCostUsd, taskResult} on stdout
#
# Exit codes:
#   0   the agent reported the task as completed
#   10  the agent reported itself blocked under the project policies
#   20  Claude Code failed to run
#   21  the result was unusable: the status was missing or unsupported
#   64  the prompt was empty
#
# The reported status is the agent's own claim about its work. It is deliberately not the
# acceptance signal: scripts/ci/run-task.sh applies the external quality gate on top of it.
#

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
SCHEMA_FILE="$PROJECT_ROOT/.claude/schemas/task-result.schema.json"

RESULT_FILE="$(mktemp)"
ERROR_FILE="$(mktemp)"

trap 'rm -f "$RESULT_FILE" "$ERROR_FILE"' EXIT

prompt="$(cat)"

if [[ -z "${prompt//[[:space:]]/}" ]]; then
    printf 'ERROR: prompt is empty\n' >&2
    exit 64
fi

cd "$PROJECT_ROOT"

claude_args=(
    -p "$prompt"
    --permission-mode dontAsk
    --output-format json
    --json-schema "$(cat "$SCHEMA_FILE")"
)

if [[ -n "${CLAUDE_MODEL:-}" ]]; then
    claude_args+=(--model "$CLAUDE_MODEL")
fi

set +e

claude "${claude_args[@]}" \
    > "$RESULT_FILE" \
    2> "$ERROR_FILE"

claude_exit_code=$?

set -e

if [[ "$claude_exit_code" -ne 0 ]]; then
    if [[ -s "$ERROR_FILE" ]]; then
        cat "$ERROR_FILE" >&2
    fi

    printf 'ERROR: Claude Code exited with status %d\n' "$claude_exit_code" >&2
    exit 20
fi

if [[ -s "$ERROR_FILE" ]]; then
    cat "$ERROR_FILE" >&2
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