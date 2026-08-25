"""Small deterministic SSE gateway used by the Windows fx smoke test."""

from __future__ import annotations

import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class GatewayHandler(BaseHTTPRequestHandler):
    server_version = "fx-gateway-stub/1.0"

    def do_POST(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        length = int(self.headers.get("content-length", "0"))
        self.server.request_body = self.rfile.read(length)  # type: ignore[attr-defined]
        self.server.request_path = self.path  # type: ignore[attr-defined]

        events = [
            {"type": "response-metadata", "modelId": self.server.model},  # type: ignore[attr-defined]
            {"type": "text-delta", "delta": "Windows fx SSE E2E passed."},
            {
                "type": "finish",
                "finishReason": {"unified": "stop"},
                "usage": {"inputTokens": 7, "outputTokens": 5},
            },
        ]
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")
        self.end_headers()
        for event in events:
            self.wfile.write(b"data: " + json.dumps(event).encode("utf-8") + b"\n\n")
        self.wfile.write(b"data: [DONE]\n\n")

    def log_message(self, format: str, *args: object) -> None:
        return


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--model", required=True)
    args = parser.parse_args()

    server = ThreadingHTTPServer(("127.0.0.1", args.port), GatewayHandler)
    server.model = args.model  # type: ignore[attr-defined]
    server.request_body = b""  # type: ignore[attr-defined]
    server.request_path = ""  # type: ignore[attr-defined]
    server.serve_forever()


if __name__ == "__main__":
    main()
