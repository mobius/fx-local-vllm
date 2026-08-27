#!/usr/bin/env python3
"""Run one bounded variation agent through the built fx binary.

The supervisor owns replay, visual gating, metrics, and persistence.  This
adapter only turns a candidate context into a constrained fx prompt and
requires the agent to write ``patch.json`` with the file tool.  It never uses
shell strings and never copies model output into the ledger.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from typing import Any


def load_context(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("context must be a JSON object")
    required = ("candidate_id", "candidate_dir", "patch_path", "patch_contract")
    missing = [key for key in required if key not in value]
    if missing:
        raise ValueError(f"context is missing: {', '.join(missing)}")
    return value


def guidance_for_prompt(context: dict[str, Any]) -> dict[str, Any] | None:
    guidance = context.get("baseline_guidance")
    if not isinstance(guidance, dict):
        return None
    shader_summaries = []
    for shader in guidance.get("shaders", []):
        if not isinstance(shader, dict):
            continue
        shader_summaries.append(
            {
                key: shader.get(key)
                for key in (
                    "file",
                    "stage",
                    "longest_path_cycle_sum",
                    "total_cycle_sum",
                    "bound_pipelines",
                    "work_registers_used",
                    "thread_occupancy",
                    "has_stack_spilling",
                )
                if key in shader
            }
        )
    return {
        "measurement_kind": guidance.get("measurement_kind"),
        "target_core": guidance.get("target_core"),
        "aggregate": guidance.get("aggregate", {}),
        "shaders": shader_summaries,
        "note": "heuristic only; validate with strict replay and runtime GPU metrics",
    }


def build_prompt(context: dict[str, Any]) -> str:
    candidate_id = str(context["candidate_id"])
    patch_path = str(context["patch_path"])
    case_spec = context.get("case_spec")
    catalog = context.get("optimization_catalog") or []
    catalog_text = "、".join(str(item) for item in catalog) if catalog else "由你提出一个可验证的 shader/pass 优化方向"
    if isinstance(case_spec, dict):
        direction_text = json.dumps(case_spec, ensure_ascii=False, sort_keys=True)
        direction_instruction = (
            f"当前唯一分配给你的 case direction 是：{direction_text}。"
            "optimization_path 必须逐字等于其中的 optimization_path，kind 必须匹配；不要选择 catalog 中的其他方向。"
        )
    else:
        direction_instruction = f"允许的优化方向：{catalog_text}。"
    guidance = guidance_for_prompt(context)
    guidance_instruction = ""
    if guidance is not None:
        guidance_instruction = (
            "\n\n下面是 baseline shader 的 Mali Offline Compiler guidance（只用于提出假设，不是本机或 V100 的实际 GPU counter）：\n"
            + json.dumps(guidance, ensure_ascii=False, sort_keys=True)
            + "\n请优先解释你的方向如何可能降低相关 pipeline/cycle/register 成本，但不要伪造收益数字。"
        )
    return (
        "你是一个受约束的 Vulkan 单帧 variation agent。\n"
        f"候选编号：{candidate_id}\n"
        f"目标 patch 文件：{patch_path}\n"
        f"{direction_instruction}\n\n"
        "所有必要信息已在本消息中，不需要读取上下文文件。必须先调用一次 write_file 工具，把严格 JSON 写入目标 patch 文件；不要调用 list、read、terminal、shell、网络或其他工具。\n"
        "JSON 至少包含：candidate_id（必须等于候选编号）、optimization_path、kind（shader 或 pass）、shader_files（相对文件名数组）。\n"
        "shader_files 只能是候选 shader 目录下的相对文件名；pass 方向必须使用空数组。\n"
        "本项目当前唯一允许替换的 captured shader stem 是 sh144；shader 方向必须声明 sh144（推荐）或 sh144 的常见扩展名（如 .spv、.spirv、.spvasm、.comp、.frag），不要写其他 stem。\n"
        "只选择一个方向，不要伪造性能数字；写完文件后再用一句话说明方向。"
        + guidance_instruction
    )


def parse_fx_result(stdout: str) -> dict[str, Any]:
    for line in reversed(stdout.splitlines()):
        line = line.strip()
        if not line:
            continue
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            return value
    raise ValueError("fx did not emit a JSON result")


def _retry_count() -> int:
    raw = os.environ.get("FX_VARIATION_RETRY_COUNT", "0")
    try:
        value = int(raw)
    except ValueError as error:
        raise ValueError("FX_VARIATION_RETRY_COUNT must be an integer") from error
    if value < 0 or value > 2:
        raise ValueError("FX_VARIATION_RETRY_COUNT must be between 0 and 2")
    return value


def _attempt_context(context: dict[str, Any], attempt_dir: Path) -> tuple[Path, Path]:
    attempt_dir.mkdir(parents=True, exist_ok=True)
    (attempt_dir / "shaders").mkdir(exist_ok=True)
    attempt_context = dict(context)
    attempt_context["candidate_dir"] = str(attempt_dir)
    attempt_context["patch_path"] = str(attempt_dir / "patch.json")
    attempt_context["shader_dir"] = str(attempt_dir / "shaders")
    context_path = attempt_dir / "context.json"
    attempt_context["context"] = str(context_path)
    context_path.write_text(json.dumps(attempt_context, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return context_path, Path(attempt_context["patch_path"])


def _run_attempt(
    *,
    fx_binary: Path,
    context: dict[str, Any],
    candidate_dir: Path,
    attempt_number: int,
    retry_gateway_url: str | None,
) -> tuple[dict[str, Any], dict[str, Any] | None]:
    attempt_dir = candidate_dir / "attempts" / f"attempt-{attempt_number:02d}"
    attempt_context_path, attempt_patch_path = _attempt_context(context, attempt_dir)
    env = os.environ.copy()
    env.setdefault("FX_MAX_AGENT_STEPS", "6")
    env.setdefault("FX_SKIP_ONBOARDING", "1")
    env.setdefault("FX_AUTO_UPGRADE", "0")
    if attempt_number > 1 and retry_gateway_url:
        for key in ("FX_GATEWAY_BASE_URL", "FX_GATEWAY_CHAT_URL", "FX_E2E_GATEWAY_CHAT_URL"):
            env[key] = retry_gateway_url
    started = time.monotonic()
    completed = subprocess.run(
        [str(fx_binary), "ask", "--json", "--no-save", "--yolo", "--", build_prompt(json.loads(attempt_context_path.read_text(encoding="utf-8")))],
        cwd=str(attempt_dir),
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    elapsed = time.monotonic() - started
    patch_written = attempt_patch_path.is_file()
    usable = completed.returncode == 0 and patch_written
    metadata = {
        "attempt": attempt_number,
        "gateway_mode": "forced_tool" if attempt_number > 1 and retry_gateway_url else "normal",
        "returncode": completed.returncode,
        "elapsed_seconds": elapsed,
        "patch_written": patch_written,
        "usable": usable,
    }
    if usable:
        target_patch = Path(str(context["patch_path"]))
        target_patch.write_bytes(attempt_patch_path.read_bytes())
        return metadata, parse_fx_result(completed.stdout or "")
    return metadata, None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Ask the built fx binary for one constrained frame variation")
    parser.add_argument("--fx", required=True, type=Path, help="built fx binary")
    parser.add_argument("--context", required=True, type=Path)
    args = parser.parse_args(argv)

    context = load_context(args.context)
    fx_binary = args.fx.resolve()
    if not fx_binary.exists():
        raise FileNotFoundError(f"fx binary does not exist: {fx_binary}")
    candidate_dir = Path(str(context["candidate_dir"])).resolve()
    patch_path = Path(str(context["patch_path"])).resolve()
    if patch_path.parent != candidate_dir:
        raise ValueError("patch_path must be directly inside candidate_dir")

    retry_count = _retry_count()
    retry_gateway_url = os.environ.get("FX_VARIATION_RETRY_GATEWAY_URL", "").strip() or None
    if retry_count and not retry_gateway_url:
        raise ValueError("FX_VARIATION_RETRY_GATEWAY_URL is required when retry is enabled")
    attempts: list[dict[str, Any]] = []
    result: dict[str, Any] | None = None
    for attempt_number in range(1, retry_count + 2):
        metadata, candidate_result = _run_attempt(
            fx_binary=fx_binary,
            context=context,
            candidate_dir=candidate_dir,
            attempt_number=attempt_number,
            retry_gateway_url=retry_gateway_url,
        )
        attempts.append(metadata)
        if metadata["usable"]:
            result = candidate_result
            break
    (candidate_dir / "agent.attempts.json").write_text(
        json.dumps({"candidate_id": context["candidate_id"], "attempts": attempts}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    if result is None or not patch_path.is_file():
        raise RuntimeError(f"fx agent completed without writing patch.json after {len(attempts)} attempt(s)")
    output = {
        "agent": "fx-variation-agent",
        "candidate_id": context["candidate_id"],
        "model": result.get("model"),
        "session_id": result.get("session_id"),
        "steps": result.get("steps"),
        "tool_calls": result.get("tool_calls", []),
        "patch_path": str(patch_path),
        "attempts": attempts,
    }
    print(json.dumps(output, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as error:
        print(f"fx variation agent failed: {error}", file=sys.stderr)
        raise SystemExit(1)
