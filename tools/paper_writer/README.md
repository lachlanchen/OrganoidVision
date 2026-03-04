# Paper Writer Toolchain

This toolchain builds a full Nature-style manuscript from local references, generates figures with GRS AI Nano Banana, and compiles a PDF.

## Prerequisites

- `codex` CLI in `PATH`
- `latexmk` + `pdflatex`
- `GRSAI` environment variable set

## Prompt Tools

1. `prompt_tool_1_write_paper.sh`
- Writes `paper/nature_submission/main.tex` from `references/*.md`.

2. `prompt_tool_2_optimize_and_generate_figures.sh`
- Optimizes figure prompts with `codex exec` and generates figures in a loop using `grsai_generate_figures.py`.

3. `prompt_tool_3_compile_paper.sh`
- Compiles LaTeX, and if compile fails, runs a codex auto-fix pass and retries.

## Orchestrator

Run all tools end-to-end:

```bash
bash tools/paper_writer/run_paper_toolchain.sh
```

This runs all three prompt tools and then commits/pushes if repository changes are present.
