#!/usr/bin/env bash
set -euo pipefail

# Prompt Tool 1: write a full Nature-style manuscript from local reference materials.

ROOT_DIR="${1:-/Users/lachlanchen/Documents/iProjects/OrganoidSensor}"
MODEL="${MODEL:-gpt-5-codex}"
REASONING="${REASONING:-high}"

REF1="$ROOT_DIR/references/organoid-image-sensor-research.md"
REF2="$ROOT_DIR/references/organoid-sensor-stack-and-blueprints.md"
REF3="$ROOT_DIR/references/bio-hybrid-vision-systems.md"
OUT_DIR="$ROOT_DIR/paper/nature_submission"
OUT_TEX="$OUT_DIR/main.tex"
PROMPT_FILE="$ROOT_DIR/tools/paper_writer/prompts/tool1_write_paper.prompt.txt"
RESP_JSONL="$ROOT_DIR/tools/paper_writer/prompts/tool1_write_paper.response.jsonl"

mkdir -p "$OUT_DIR" "$(dirname "$PROMPT_FILE")"

if ! command -v codex >/dev/null 2>&1; then
  echo "codex CLI not found in PATH" >&2
  exit 1
fi

for f in "$REF1" "$REF2" "$REF3"; do
  if [[ ! -f "$f" ]]; then
    echo "Missing reference file: $f" >&2
    exit 1
  fi
done

cat > "$PROMPT_FILE" <<EOF2
Task: Write a complete, submission-ready Nature-style research manuscript in LaTeX.

Source materials:
- $REF1
- $REF2
- $REF3

Write the LaTeX file directly to:
$OUT_TEX

Hard requirements:
- Use a LaTeX format that compiles with pdflatex/latexmk without external classes.
- Title: Bio-Hybrid Vision Systems: Engineering Retinal Organoids as Advanced Imaging Sensors
- Authors: Rongzhou Chen, Shaohua Ma
- Include: Abstract, Introduction, Results, Discussion, Methods, Conclusion, Ethics Statement, Data Availability, Code Availability.
- Integrate core ideas from ALL three source files.
- Keep claims technical and plausible; avoid speculative overstatement.
- Include a concise equation set for event-based coding/decoding metrics.
- Use Nature-like professional tone and structure.
- Add 6 figure environments with these exact filenames:
  1) figures/fig01_system_overview.png
  2) figures/fig02_retinal_organoid_morphogenesis.png
  3) figures/fig03_biointerface_mea_microfluidic.png
  4) figures/fig04_event_coding_pipeline.png
  5) figures/fig05_quality_control_monitoring.png
  6) figures/fig06_ethics_and_deployment_framework.png
- Each figure must include an informative caption.
- Use numeric references and include a compact \\begin{thebibliography} block.
- Ensure no TODO placeholders remain.

Execution requirements:
- Write UTF-8 text directly to the target file.
- Final response must be exactly: WROTE $OUT_TEX
EOF2

codex exec --json --full-auto -m "$MODEL" -c "model_reasoning_effort=\"$REASONING\"" --skip-git-repo-check - < "$PROMPT_FILE" > "$RESP_JSONL"

echo "Wrote manuscript to $OUT_TEX"
