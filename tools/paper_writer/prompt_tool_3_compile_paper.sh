#!/usr/bin/env bash
set -euo pipefail

# Prompt Tool 3: compile LaTeX and auto-fix compile issues with codex prompt if needed.

ROOT_DIR="${1:-/Users/lachlanchen/Documents/iProjects/OrganoidSensor}"
MODEL="${MODEL:-gpt-5-codex}"
REASONING="${REASONING:-high}"

PAPER_DIR="$ROOT_DIR/paper/nature_submission"
TEX_FILE="$PAPER_DIR/main.tex"
LOG_FILE="$PAPER_DIR/main.compile.log"
PROMPT_FILE="$ROOT_DIR/tools/paper_writer/prompts/tool3_compile_fix.prompt.txt"
RESP_JSONL="$ROOT_DIR/tools/paper_writer/prompts/tool3_compile_fix.response.jsonl"

if [[ ! -f "$TEX_FILE" ]]; then
  echo "Missing TeX file: $TEX_FILE" >&2
  exit 1
fi

if ! command -v latexmk >/dev/null 2>&1; then
  echo "latexmk not found" >&2
  exit 1
fi

compile_once() {
  (cd "$PAPER_DIR" && latexmk -pdf -interaction=nonstopmode -halt-on-error -file-line-error main.tex) >"$LOG_FILE" 2>&1
}

if compile_once; then
  echo "Compiled successfully: $PAPER_DIR/main.pdf"
  exit 0
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "Compile failed and codex CLI is unavailable for auto-fix." >&2
  tail -n 80 "$LOG_FILE" >&2 || true
  exit 1
fi

cat > "$PROMPT_FILE" <<EOF2
Task: Fix LaTeX compile errors in place.

Inputs:
- Manuscript: $TEX_FILE
- Compile log: $LOG_FILE

Requirements:
- Edit only $TEX_FILE.
- Resolve compile errors while preserving scientific content and structure.
- Keep figure includes and section headings intact.
- Prefer minimal, safe fixes (package issues, escaping, equation syntax, bibliography syntax, bad references).
- Maintain pdflatex compatibility.

Execution requirements:
- Save the fixed LaTeX directly to $TEX_FILE.
- Final response must be exactly: WROTE $TEX_FILE
EOF2

codex exec --json --full-auto -m "$MODEL" -c "model_reasoning_effort=\"$REASONING\"" --skip-git-repo-check - < "$PROMPT_FILE" > "$RESP_JSONL"

if compile_once; then
  echo "Compiled successfully after auto-fix: $PAPER_DIR/main.pdf"
  exit 0
fi

echo "Compile failed after auto-fix. See $LOG_FILE" >&2
tail -n 120 "$LOG_FILE" >&2 || true
exit 1
