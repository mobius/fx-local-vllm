"""Translate fx's local Gateway SSE contract to an OpenAI-compatible endpoint.

This fixture is intentionally small and local-only. It exists so a Windows fx
binary can be tested against a vLLM OpenAI-compatible server over an SSH
tunnel without changing fx's production Gateway transport.
"""

from __future__ import annotations

import argparse
import json
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any


def _text_from_parts(content: Any) -> str:
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return ""
    pieces: list[str] = []
    for part in content:
        if not isinstance(part, dict):
            continue
        part_type = part.get("type")
        if part_type in {"text", "tool-result"}:
            if part_type == "text":
                value = part.get("text", "")
            else:
                output = part.get("output", {})
                value = output.get("value", "") if isinstance(output, dict) else output
            if isinstance(value, str):
                pieces.append(value)
    return "".join(pieces)


def _gateway_messages_to_openai(prompt: Any) -> list[dict[str, Any]]:
    if not isinstance(prompt, list):
        raise ValueError("Gateway request is missing prompt array")

    messages: list[dict[str, Any]] = []
    system_messages: list[str] = []
    for source in prompt:
        if not isinstance(source, dict):
            continue
        role = source.get("role")
        content = source.get("content")
        if role == "assistant":
            tool_calls: list[dict[str, Any]] = []
            if isinstance(content, list):
                for part in content:
                    if not isinstance(part, dict) or part.get("type") != "tool-call":
                        continue
                    arguments = part.get("input", {})
                    if not isinstance(arguments, str):
                        arguments = json.dumps(arguments, ensure_ascii=False, separators=(",", ":"))
                    tool_calls.append(
                        {
                            "id": part.get("toolCallId", "fx-tool-call"),
                            "type": "function",
                            "function": {
                                "name": part.get("toolName", "unknown"),
                                "arguments": arguments,
                            },
                        }
                    )
            message: dict[str, Any] = {"role": "assistant", "content": _text_from_parts(content) or None}
            if tool_calls:
                message["tool_calls"] = tool_calls
            messages.append(message)
            continue

        if role == "tool":
            tool_call_id = ""
            if isinstance(content, list):
                for part in content:
                    if isinstance(part, dict) and part.get("type") == "tool-result":
                        tool_call_id = str(part.get("toolCallId", ""))
                        break
            messages.append(
                {
                    "role": "tool",
                    "tool_call_id": tool_call_id,
                    "content": _text_from_parts(content),
                }
            )
            continue

        if role == "system":
            system_messages.append(_text_from_parts(content))
            continue

        if role == "user":
            messages.append({"role": role, "content": _text_from_parts(content)})

    if system_messages:
        messages.insert(0, {"role": "system", "content": "\n\n".join(system_messages)})
    if not messages:
        raise ValueError("Gateway prompt produced no OpenAI messages")
    return messages


def _gateway_tools_to_openai(tools: Any) -> list[dict[str, Any]]:
    if not isinstance(tools, list):
        return []
    result: list[dict[str, Any]] = []
    for source in tools:
        if not isinstance(source, dict) or source.get("type") != "function":
            continue
        name = source.get("name")
        if not isinstance(name, str) or not name:
            continue
        function: dict[str, Any] = {
            "name": name,
            "description": source.get("description", ""),
            "parameters": source.get("inputSchema", {"type": "object", "properties": {}}),
        }
        result.append({"type": "function", "function": function})
    return result


def _gateway_request_to_openai(
    source: dict[str, Any],
    force_tool: str | None = None,
    max_output_tokens: int | None = None,
) -> dict[str, Any]:
    request: dict[str, Any] = {
        "model": source.get("model", "Qwen3.8-27B-INT4"),
        "messages": _gateway_messages_to_openai(source.get("prompt")),
        "stream": True,
        "stream_options": {"include_usage": True},
    }
    tools = _gateway_tools_to_openai(source.get("tools"))
    if tools:
        request["tools"] = tools

    has_tool_history = any(
        isinstance(message, dict)
        and (
            message.get("role") == "tool"
            or any(
                isinstance(part, dict) and part.get("type") == "tool-call"
                for part in (message.get("content") if isinstance(message.get("content"), list) else [])
            )
        )
        for message in (source.get("prompt") if isinstance(source.get("prompt"), list) else [])
    )
    if force_tool and not has_tool_history:
        if not any(
            isinstance(tool, dict)
            and isinstance(tool.get("function"), dict)
            and tool["function"].get("name") == force_tool
            for tool in tools
        ):
            raise ValueError(f"forced tool is not present in request: {force_tool}")
        request["tool_choice"] = {
            "type": "function",
            "function": {"name": force_tool},
        }
    else:
        tool_choice = source.get("toolChoice")
        if isinstance(tool_choice, dict) and isinstance(tool_choice.get("type"), str):
            request["tool_choice"] = tool_choice["type"]

    source_max_output_tokens = source.get("maxOutputTokens")
    if isinstance(source_max_output_tokens, int) and source_max_output_tokens > 0:
        request["max_tokens"] = source_max_output_tokens
    if max_output_tokens is not None:
        request["max_tokens"] = max_output_tokens
    return request


def _finish_reason(reason: Any, has_tool_calls: bool = False) -> str:
    if reason == "tool_calls" or has_tool_calls:
        return "tool-calls"
    if reason == "length":
        return "length"
    if reason == "content_filter":
        return "content-filter"
    return "stop"


def _usage(source: Any) -> dict[str, int]:
    if not isinstance(source, dict):
        return {}
    result: dict[str, int] = {}
    prompt_tokens = source.get("prompt_tokens")
    completion_tokens = source.get("completion_tokens")
    if isinstance(prompt_tokens, int) and prompt_tokens >= 0:
        result["inputTokens"] = prompt_tokens
    if isinstance(completion_tokens, int) and completion_tokens >= 0:
        result["outputTokens"] = completion_tokens
    return result


class BridgeHandler(BaseHTTPRequestHandler):
    server_version = "fx-openai-gateway-bridge/1.0"

    def _send_json_error(self, status: int, message: str) -> None:
        body = json.dumps({"error": {"message": message}}, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_event(self, event: dict[str, Any]) -> None:
        payload = json.dumps(event, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        self.wfile.write(b"data: " + payload + b"\n\n")
        self.wfile.flush()

    def do_POST(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        length = int(self.headers.get("content-length", "0"))
        raw = self.rfile.read(length)
        try:
            gateway_request = json.loads(raw)
            openai_request = _gateway_request_to_openai(
                gateway_request,
                self.server.force_tool,  # type: ignore[attr-defined]
                self.server.max_output_tokens,  # type: ignore[attr-defined]
            )
        except (ValueError, json.JSONDecodeError, TypeError) as exc:
            self._send_json_error(400, f"invalid fx Gateway request: {exc}")
            return

        body = json.dumps(openai_request, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        request = urllib.request.Request(
            self.server.openai_url,  # type: ignore[attr-defined]
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            response = urllib.request.urlopen(request, timeout=self.server.timeout)  # type: ignore[attr-defined]
        except urllib.error.HTTPError as exc:
            detail = exc.read(4096).decode("utf-8", errors="replace")
            self._send_json_error(exc.code, f"OpenAI-compatible endpoint failed: {detail}")
            return
        except (OSError, urllib.error.URLError) as exc:
            self._send_json_error(502, f"OpenAI-compatible endpoint unavailable: {exc}")
            return

        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")
        self.end_headers()

        tool_calls: dict[int, dict[str, str]] = {}
        finish_reason: Any = "stop"
        usage: dict[str, int] = {}
        self._send_event({"type": "response-metadata", "modelId": openai_request["model"]})
        with response:
            for line in response:
                if not line.startswith(b"data:"):
                    continue
                payload = line[5:].strip()
                if payload == b"[DONE]":
                    break
                try:
                    chunk = json.loads(payload)
                except json.JSONDecodeError:
                    continue
                usage.update(_usage(chunk.get("usage")))
                choices = chunk.get("choices")
                if not isinstance(choices, list) or not choices or not isinstance(choices[0], dict):
                    continue
                choice = choices[0]
                delta = choice.get("delta")
                if isinstance(delta, dict):
                    text = delta.get("content")
                    if isinstance(text, str) and text:
                        self._send_event({"type": "text-delta", "id": "text", "delta": text})
                    reasoning = delta.get("reasoning_content")
                    if isinstance(reasoning, str) and reasoning:
                        self._send_event({"type": "reasoning-delta", "id": "reasoning", "delta": reasoning})
                    streamed_calls = delta.get("tool_calls")
                    if isinstance(streamed_calls, list):
                        for streamed in streamed_calls:
                            if not isinstance(streamed, dict):
                                continue
                            index = streamed.get("index", 0)
                            if not isinstance(index, int):
                                index = 0
                            current = tool_calls.setdefault(index, {"id": "", "name": "", "arguments": ""})
                            if isinstance(streamed.get("id"), str):
                                current["id"] = streamed["id"]
                            function = streamed.get("function")
                            if isinstance(function, dict):
                                if isinstance(function.get("name"), str):
                                    current["name"] += function["name"]
                                if isinstance(function.get("arguments"), str):
                                    current["arguments"] += function["arguments"]
                if choice.get("finish_reason") is not None:
                    finish_reason = choice["finish_reason"]

        for index in sorted(tool_calls):
            call = tool_calls[index]
            try:
                input_value: Any = json.loads(call["arguments"] or "{}")
            except json.JSONDecodeError:
                input_value = call["arguments"]
            self._send_event(
                {
                    "type": "tool-call",
                    "toolCallId": call["id"] or f"fx-tool-call-{index}",
                    "toolName": call["name"] or "unknown",
                    "input": input_value,
                }
            )
        self._send_event(
            {
                "type": "finish",
                "finishReason": {"unified": _finish_reason(finish_reason, bool(tool_calls))},
                "usage": usage,
            }
        )
        self.wfile.write(b"data: [DONE]\n\n")
        self.wfile.flush()

    def log_message(self, format: str, *args: object) -> None:
        return


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--listen-port", type=int, required=True)
    parser.add_argument("--openai-url", required=True)
    parser.add_argument("--timeout", type=float, default=300.0)
    parser.add_argument("--force-tool", help="Force the OpenAI-compatible request to call this function")
    parser.add_argument("--max-output-tokens", type=int, help="Cap upstream generation for bounded fixture runs")
    args = parser.parse_args()

    server = ThreadingHTTPServer(("127.0.0.1", args.listen_port), BridgeHandler)
    server.openai_url = args.openai_url  # type: ignore[attr-defined]
    server.timeout = args.timeout  # type: ignore[attr-defined]
    server.force_tool = args.force_tool  # type: ignore[attr-defined]
    server.max_output_tokens = args.max_output_tokens  # type: ignore[attr-defined]
    server.serve_forever()


if __name__ == "__main__":
    main()
