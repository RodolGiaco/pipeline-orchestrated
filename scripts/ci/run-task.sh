#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

AGENT_RUNNER="$PROJECT_ROOT/.claude/scripts/run-agent.sh"
QUALITY_GATE="./mvnw -B -ntp verify"

AGENT_RESULT="$(mktemp)"
QUALITY_LOG="$(mktemp)"

trap 'rm -f "$AGENT_RESULT" "$QUALITY_LOG"' EXIT

prompt="$(cat)"

cd "$PROJECT_ROOT"

set +e
printf '%s\n' "$prompt" | "$AGENT_RUNNER" > "$AGENT_RESULT"
agent_exit_code=$?
set -e

case "$agent_exit_code" in
    0)
        ;;
    10)
        jq -c \
            --arg command "$QUALITY_GATE" \
            '{
                pipelineStatus: "blocked",
                agent: .,
                qualityGate: {
                    command: $command,
                    status: "not_run"
                }
            }' "$AGENT_RESULT"

        exit 10
        ;;
    *)
        printf 'ERROR: agent execution failed with status %d\n' "$agent_exit_code" >&2
        exit 20
        ;;
esac

set +e
$QUALITY_GATE > "$QUALITY_LOG" 2>&1
quality_gate_exit_code=$?
set -e

if [[ "$quality_gate_exit_code" -ne 0 ]]; then
    cat "$QUALITY_LOG" >&2

    jq -c \
        --arg command "$QUALITY_GATE" \
        '{
            pipelineStatus: "failed",
            agent: .,
            qualityGate: {
                command: $command,
                status: "failed"
            }
        }' "$AGENT_RESULT"

    exit 30
fi

jq -c \
    --arg command "$QUALITY_GATE" \
    '{
        pipelineStatus: "completed",
        agent: .,
        qualityGate: {
            command: $command,
            status: "passed"
        }
    }' "$AGENT_RESULT"

exit 0