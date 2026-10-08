#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Usage: bash compare-agents.sh REPO_PATH_OR_GITHUB_URL MODEL "QUESTION"
set -euo pipefail

if [[ $# != 3 ]]; then
  echo "Usage: bash $0 REPO_PATH_OR_GITHUB_URL MODEL \"QUESTION\"" >&2
  exit 2
fi
command -v claude >/dev/null || { echo "Install and sign in to Claude Code first." >&2; exit 1; }
starter=$(cd "$(dirname "$0")" && pwd -P)
target=$1
model=$2
question=$3
[[ -n $question ]] || { echo "The question is empty." >&2; exit 1; }

# GitHub URLs get a clone under repos/. Local paths use the existing clone.
if [[ $target == https://github.com/* ]]; then
  slug=${target#https://github.com/}
  slug=${slug%/}
  slug=${slug%.git}
  if [[ ! $slug =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    echo "Use the repository's GitHub URL, without a branch or file path." >&2
    exit 2
  fi
  case "/$slug/" in
    */../*|*/./*) echo "Use a GitHub owner and repository name." >&2; exit 2 ;;
  esac
  target="$starter/repos/$slug"
  if [[ ! -e $target ]]; then
    mkdir -p "$(dirname "$target")"
    git clone "https://github.com/$slug.git" "$target"
  fi
fi
repo=$(cd "$target" && git rev-parse --show-toplevel)
repo=$(cd "$repo" && pwd -P)
case "$starter/" in
  "$repo/"*) echo "Choose a repository outside the starter's Git root." >&2; exit 1 ;;
esac
cd "$repo"
if [[ -n $(git status --porcelain) ]]; then
  echo "Commit or set aside repository changes before comparing agents." >&2
  exit 1
fi

# Both agents read the same clone. Answers stay in the starter's results/.
mkdir -p "$starter/results"
results=$(mktemp -d "$starter/results/$(basename "$repo").XXXXXX")
printf '%s\n' "$question" > "$results/question.txt"
printf '%s\n' "$model" > "$results/model.txt"
printf '%s\n' "$repo" > "$results/repository.txt"
git rev-parse HEAD > "$results/revision.txt"
claude --version > "$results/claude-version.txt"
echo "Saving results to $results"

run_agent() {
  local number=$1 started finished status=0
  started=$(date +%s)
  # Each invocation starts a fresh conversation with only reading tools, at medium effort.
  claude -p "$question" \
    --model "$model" \
    --effort medium \
    --tools 'Read,Glob,Grep' \
    --allowedTools 'Read,Glob,Grep' \
    --permission-mode dontAsk \
    --setting-sources user \
    --settings '{"disableAllHooks":true}' \
    --strict-mcp-config \
    --mcp-config '{"mcpServers":{}}' \
    --no-session-persistence \
    --output-format json \
    </dev/null > "$results/agent-$number.json" 2> "$results/agent-$number.stderr" || status=$?
  finished=$(date +%s)
  printf '%s\n' "$((finished - started))" > "$results/agent-$number.seconds"
  printf '%s\n' "$status" > "$results/agent-$number.exit-code"
  return "$status"
}

# & starts each run in the background; wait collects both exit statuses.
run_agent 1 &
first=$!
run_agent 2 &
second=$!
failed=0
wait "$first" || failed=1
wait "$second" || failed=1

echo "Both runs finished. Results: $results"
echo 'Inspect result, usage, modelUsage, and total_cost_usd in each JSON file.'
echo 'The dollar amounts are estimates, not subscription charges.'
if [[ $failed != 0 ]]; then
  echo 'A run failed. Inspect its JSON, stderr, and exit-code files.' >&2
fi
exit "$failed"
