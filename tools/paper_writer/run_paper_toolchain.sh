#!/usr/bin/env bash
set -euo pipefail

# Orchestrator: run all paper-writing prompt tools and then commit/push if there are changes.

ROOT_DIR="${1:-/Users/lachlanchen/Documents/iProjects/OrganoidSensor}"

"$ROOT_DIR/tools/paper_writer/prompt_tool_1_write_paper.sh" "$ROOT_DIR"
"$ROOT_DIR/tools/paper_writer/prompt_tool_2_optimize_and_generate_figures.sh" "$ROOT_DIR"
"$ROOT_DIR/tools/paper_writer/prompt_tool_3_compile_paper.sh" "$ROOT_DIR"

if [[ -n "$(git -C "$ROOT_DIR" status --porcelain)" ]]; then
  git -C "$ROOT_DIR" add paper tools references
  git -C "$ROOT_DIR" commit -m "feat: add automated Nature-style paper pipeline with GRSAI figures"

  if git -C "$ROOT_DIR" remote get-url origin >/dev/null 2>&1; then
    current_branch="$(git -C "$ROOT_DIR" branch --show-current)"
    git -C "$ROOT_DIR" push -u origin "$current_branch"
  else
    echo "No git remote named 'origin'; commit created locally but push skipped."
  fi
else
  echo "No changes detected; skipping commit/push."
fi
