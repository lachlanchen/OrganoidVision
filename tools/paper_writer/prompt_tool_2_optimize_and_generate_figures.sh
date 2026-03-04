#!/usr/bin/env bash
set -euo pipefail

# Prompt Tool 2: optimize figure prompts and generate all figures via GRS AI in a loop.

ROOT_DIR="${1:-/Users/lachlanchen/Documents/iProjects/OrganoidSensor}"
MODEL="${MODEL:-gpt-5-codex}"
REASONING="${REASONING:-high}"

PAPER_DIR="$ROOT_DIR/paper/nature_submission"
FIG_DIR="$PAPER_DIR/figures"
SEED_JSON="$FIG_DIR/figure_plan.seed.json"
OUT_JSON="$FIG_DIR/figure_prompts.optimized.json"
PROMPT_FILE="$ROOT_DIR/tools/paper_writer/prompts/tool2_optimize_figures.prompt.txt"
RESP_JSONL="$ROOT_DIR/tools/paper_writer/prompts/tool2_optimize_figures.response.jsonl"

MANUSCRIPT_TEX="$PAPER_DIR/main.tex"

mkdir -p "$FIG_DIR/logs" "$(dirname "$PROMPT_FILE")"

if ! command -v codex >/dev/null 2>&1; then
  echo "codex CLI not found in PATH" >&2
  exit 1
fi

if [[ -z "${GRSAI:-}" ]]; then
  echo "Missing GRSAI env var. Export GRSAI=<token>" >&2
  exit 1
fi

if [[ ! -f "$SEED_JSON" ]]; then
  cat > "$SEED_JSON" <<'EOF2'
{
  "figures": [
    {
      "order": 1,
      "id": "fig01",
      "filename": "fig01_system_overview.png",
      "title": "Bio-Hybrid Vision System Overview",
      "caption": "System-level schematic from optical stimulus input to organoid transduction, bioelectronic readout, and machine decoder output.",
      "aspect_ratio": "16:9"
    },
    {
      "order": 2,
      "id": "fig02",
      "filename": "fig02_retinal_organoid_morphogenesis.png",
      "title": "Retinal Organoid Morphogenesis",
      "caption": "Developmental timeline and laminar organization of retinal organoids, highlighting photoreceptor and ganglion-cell output constraints.",
      "aspect_ratio": "4:3"
    },
    {
      "order": 3,
      "id": "fig03",
      "filename": "fig03_biointerface_mea_microfluidic.png",
      "title": "Biointerface Hardware",
      "caption": "Integrated interface showing 3D MEA, conformal electrodes, and microfluidic perfusion for stable long-term recording.",
      "aspect_ratio": "16:9"
    },
    {
      "order": 4,
      "id": "fig04",
      "filename": "fig04_event_coding_pipeline.png",
      "title": "Event-Based Coding Pipeline",
      "caption": "Pipeline converting organoid electrophysiology into asynchronous event streams and decoding outputs for recognition tasks.",
      "aspect_ratio": "16:9"
    },
    {
      "order": 5,
      "id": "fig05",
      "filename": "fig05_quality_control_monitoring.png",
      "title": "Longitudinal Quality Control",
      "caption": "Multimodal QC dashboard concept combining oxygen, pH, impedance, SNR, and drift indicators over time.",
      "aspect_ratio": "4:3"
    },
    {
      "order": 6,
      "id": "fig06",
      "filename": "fig06_ethics_and_deployment_framework.png",
      "title": "Ethics and Deployment",
      "caption": "Governance framework linking maturity state, stimulation limits, oversight checkpoints, and deployment boundaries.",
      "aspect_ratio": "4:3"
    }
  ]
}
EOF2
fi

if [[ ! -f "$MANUSCRIPT_TEX" ]]; then
  echo "Expected manuscript at $MANUSCRIPT_TEX. Run prompt_tool_1_write_paper.sh first." >&2
  exit 1
fi

cat > "$PROMPT_FILE" <<EOF2
Task: Optimize scientific figure prompts for publication-quality generation.

Inputs:
- Seed figure plan JSON: $SEED_JSON
- Manuscript context: $MANUSCRIPT_TEX

Write optimized JSON directly to:
$OUT_JSON

Rules:
- Preserve exactly 6 figures and preserve filename/order/id values.
- Keep caption text, but improve wording if needed for clarity.
- For each figure, output a detailed image-generation prompt for GRS AI Nano Banana.
- Prompts must be precise, visually rich, and scientific.
- No text rendered inside images (no axis labels, no titles, no numbers, no letters).
- Use clean Nature-style color palette, high contrast, white/light backgrounds.
- Avoid messy decorative elements.
- Each prompt should include composition cues, depth/layering cues, and quality constraints.
- Ensure aspect ratios remain valid: auto, 1:1, 16:9, 9:16, 4:3, 3:4, 3:2, 2:3, 5:4, 4:5, 21:9.

Output schema:
{
  "figures": [
    {
      "order": 1,
      "id": "fig01",
      "filename": "fig01_system_overview.png",
      "title": "...",
      "caption": "...",
      "aspect_ratio": "16:9",
      "prompt": "..."
    }
  ]
}

Execution requirements:
- Write UTF-8 JSON to the output path.
- Final response must be exactly: WROTE $OUT_JSON
EOF2

codex exec --json --full-auto -m "$MODEL" -c "model_reasoning_effort=\"$REASONING\"" --skip-git-repo-check - < "$PROMPT_FILE" > "$RESP_JSONL"

python3 "$ROOT_DIR/tools/paper_writer/grsai_generate_figures.py" \
  --prompts-json "$OUT_JSON" \
  --output-dir "$FIG_DIR" \
  --model "nano-banana-fast" \
  --image-size "2K" \
  --resume \
  --verbose

echo "Generated figures in $FIG_DIR"
