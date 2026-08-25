import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tests" / "fixtures"))
from openai_gateway_bridge import _finish_reason, _gateway_request_to_openai  # noqa: E402


class OpenAIGatewayBridgeTests(unittest.TestCase):
    def _request(self) -> dict:
        return {
            "model": "Qwen3.8-27B-INT4",
            "prompt": [{"role": "user", "content": [{"type": "text", "text": "write"}]}],
            "tools": [
                {
                    "type": "function",
                    "name": "write_file",
                    "description": "write a file",
                    "inputSchema": {"type": "object"},
                },
                {
                    "type": "function",
                    "name": "read_file",
                    "description": "read a file",
                    "inputSchema": {"type": "object"},
                },
            ],
            "toolChoice": {"type": "auto"},
        }

    def test_force_tool_overrides_auto_choice(self) -> None:
        request = _gateway_request_to_openai(self._request(), "write_file")
        self.assertEqual(
            request["tool_choice"],
            {"type": "function", "function": {"name": "write_file"}},
        )

    def test_force_tool_requires_declared_function(self) -> None:
        with self.assertRaises(ValueError):
            _gateway_request_to_openai(self._request(), "missing")

    def test_force_tool_applies_only_before_tool_history(self) -> None:
        request = self._request()
        request["prompt"].extend(
            [
                {
                    "role": "assistant",
                    "content": [
                        {
                            "type": "tool-call",
                            "toolName": "write_file",
                            "toolCallId": "call-1",
                            "input": {},
                        }
                    ],
                },
                {
                    "role": "tool",
                    "content": [{"type": "tool-result", "toolCallId": "call-1", "output": {"value": "ok"}}],
                },
            ]
        )
        converted = _gateway_request_to_openai(request, "write_file")
        self.assertEqual(converted["tool_choice"], "auto")

    def test_tool_calls_override_upstream_stop_reason(self) -> None:
        self.assertEqual(_finish_reason("stop", True), "tool-calls")
        self.assertEqual(_finish_reason("stop", False), "stop")

    def test_output_cap_overrides_unbounded_source_value(self) -> None:
        request = _gateway_request_to_openai({**self._request(), "maxOutputTokens": 128000}, max_output_tokens=4096)
        self.assertEqual(request["max_tokens"], 4096)


if __name__ == "__main__":
    unittest.main()
