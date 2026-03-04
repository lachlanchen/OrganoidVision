#!/usr/bin/env python3
"""Generate publication figures from prompt JSON via GRS AI Nano Banana."""

from __future__ import annotations

import argparse
import json
import os
import time
import urllib.request
from pathlib import Path
from typing import Any, Dict, Optional


ALLOWED_ASPECTS = {
    "auto",
    "1:1",
    "16:9",
    "9:16",
    "4:3",
    "3:4",
    "3:2",
    "2:3",
    "5:4",
    "4:5",
    "21:9",
}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Generate figure images from prompts JSON")
    p.add_argument("--prompts-json", required=True, help="Path to figure prompts JSON")
    p.add_argument("--output-dir", required=True, help="Directory to write images")
    p.add_argument("--model", default="nano-banana-fast", help="GRS model name")
    p.add_argument("--host", default="https://grsai.dakka.com.cn", help="GRS host")
    p.add_argument("--image-size", default="2K", help="Image size, e.g. 1K/2K")
    p.add_argument("--retries", type=int, default=2, help="Retries per figure")
    p.add_argument("--poll-interval", type=float, default=3.0, help="Poll interval seconds")
    p.add_argument("--poll-timeout", type=float, default=600.0, help="Poll timeout seconds")
    p.add_argument("--stalled-timeout", type=float, default=120.0, help="Stalled timeout seconds")
    p.add_argument("--resume", action="store_true", help="Skip existing outputs")
    p.add_argument("--verbose", action="store_true", help="Verbose logs")
    return p.parse_args()


def request_raw(url: str, payload: Dict[str, Any], api_key: str) -> str:
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {api_key}")
    with urllib.request.urlopen(req, timeout=120) as resp:
        return resp.read().decode("utf-8", errors="ignore")


def parse_json(raw: str) -> Dict[str, Any]:
    try:
        return json.loads(raw)
    except Exception:
        pass
    last_obj: Optional[Dict[str, Any]] = None
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("data:"):
            line = line[5:].strip()
        try:
            obj = json.loads(line)
            if isinstance(obj, dict):
                last_obj = obj
        except Exception:
            continue
    if last_obj is None:
        raise RuntimeError("Failed to parse API response")
    return last_obj


def download_file(url: str, dest: Path) -> None:
    with urllib.request.urlopen(url, timeout=120) as resp:
        dest.write_bytes(resp.read())


def poll_result(
    host: str,
    task_id: str,
    api_key: str,
    interval: float,
    timeout_s: float,
    stalled_timeout_s: float,
    verbose: bool,
) -> Dict[str, Any]:
    url = host.rstrip("/") + "/v1/draw/result"
    payload = {"id": task_id}
    start = time.time()
    last_signature: Optional[tuple] = None
    last_change = start

    while True:
        raw = request_raw(url, payload, api_key)
        result = parse_json(raw)
        data = result.get("data") or {}
        status = result.get("status") or data.get("status")
        progress = result.get("progress")
        if progress is None:
            progress = data.get("progress")

        signature = (status, progress, data.get("start_time"), data.get("end_time"))
        if signature != last_signature:
            last_signature = signature
            last_change = time.time()

        if verbose:
            print(f"poll id={task_id} status={status} progress={progress}", flush=True)

        if status in {"succeeded", "failed"}:
            return result
        if time.time() - start > timeout_s:
            raise RuntimeError(f"Polling timeout for {task_id}")
        if time.time() - last_change > stalled_timeout_s:
            raise RuntimeError(f"Polling stalled for {task_id}")
        time.sleep(interval)


def normalize_figures(payload: Dict[str, Any]) -> list[Dict[str, Any]]:
    if isinstance(payload.get("figures"), list):
        figs = payload["figures"]
    elif isinstance(payload.get("prompts"), list):
        figs = payload["prompts"]
    else:
        raise RuntimeError("Prompts JSON must contain 'figures' or 'prompts' list")

    cleaned = []
    for i, fig in enumerate(figs, start=1):
        filename = fig.get("filename") or fig.get("file") or f"fig_{i:03d}.png"
        prompt = str(fig.get("prompt", "")).strip()
        if not prompt:
            raise RuntimeError(f"Missing prompt for figure index {i}")
        aspect = str(fig.get("aspect_ratio", "4:3")).strip()
        if aspect not in ALLOWED_ASPECTS:
            aspect = "4:3"
        cleaned.append(
            {
                "order": int(fig.get("order", i)),
                "id": str(fig.get("id", f"fig{i}")),
                "title": str(fig.get("title", "")),
                "caption": str(fig.get("caption", "")),
                "filename": filename,
                "prompt": prompt,
                "aspect_ratio": aspect,
            }
        )

    cleaned.sort(key=lambda x: (x["order"], x["id"]))
    return cleaned


def main() -> None:
    args = parse_args()
    api_key = os.environ.get("GRSAI")
    if not api_key:
        raise RuntimeError("Missing GRSAI env var. Export GRSAI=<token>")

    prompts_path = Path(args.prompts_json)
    if not prompts_path.exists():
        raise FileNotFoundError(prompts_path)

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    log_dir = output_dir / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)

    payload = json.loads(prompts_path.read_text(encoding="utf-8"))
    figures = normalize_figures(payload)

    submit_url = args.host.rstrip("/") + "/v1/draw/nano-banana"

    for idx, fig in enumerate(figures, start=1):
        out_image = output_dir / fig["filename"]
        out_prompt = output_dir / f"{Path(fig['filename']).stem}.prompt.txt"
        out_caption = output_dir / f"{Path(fig['filename']).stem}.caption.txt"

        if args.resume and out_image.exists():
            if args.verbose:
                print(f"[{idx}/{len(figures)}] skip existing {out_image.name}", flush=True)
            continue

        # Guard text for publication-style clean scientific rendering.
        prompt = (
            "Create a publication-quality, scientific, visually clear figure panel. "
            "White or very light background. High contrast. Clean composition. "
            "No watermark. No logo. "
            + fig["prompt"].strip()
        )

        request_payload: Dict[str, Any] = {
            "model": args.model,
            "prompt": prompt,
            "aspectRatio": fig["aspect_ratio"],
            "webHook": "-1",
            "shutProgress": True,
        }
        if args.image_size:
            request_payload["imageSize"] = args.image_size

        last_err = None
        for attempt in range(args.retries + 1):
            try:
                raw = request_raw(submit_url, request_payload, api_key)
                result = parse_json(raw)
                (log_dir / f"submit_{idx:03d}.json").write_text(
                    json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8"
                )

                task_id = result.get("id") or (result.get("data") or {}).get("id")
                if not task_id:
                    raise RuntimeError(f"missing task id: {result}")

                final = poll_result(
                    args.host,
                    str(task_id),
                    api_key,
                    args.poll_interval,
                    args.poll_timeout,
                    args.stalled_timeout,
                    args.verbose,
                )
                (log_dir / f"poll_{idx:03d}.json").write_text(
                    json.dumps(final, ensure_ascii=False, indent=2), encoding="utf-8"
                )
                results = final.get("results") or (final.get("data") or {}).get("results") or []
                if not results or not results[0].get("url"):
                    raise RuntimeError(f"No output URL in final response: {final}")

                download_file(results[0]["url"], out_image)
                out_prompt.write_text(prompt + "\n", encoding="utf-8")
                out_caption.write_text(fig["caption"] + "\n", encoding="utf-8")
                print(f"Saved {out_image}", flush=True)
                break
            except Exception as exc:  # noqa: BLE001
                last_err = str(exc)
                if args.verbose:
                    print(
                        f"[{idx}/{len(figures)}] attempt {attempt + 1} failed: {last_err}",
                        flush=True,
                    )
                time.sleep(1.5 + attempt * 1.5)
        else:
            raise RuntimeError(f"Failed to generate {fig['filename']}: {last_err}")

        time.sleep(0.3)

    print(f"Done. Generated {len(figures)} figures in {output_dir}", flush=True)


if __name__ == "__main__":
    main()
