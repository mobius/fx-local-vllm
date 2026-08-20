# Local OpenAI-compatible gateway

Opt-in protocol for self-hosted OpenAI `/v1` servers. Default fx behavior (Vercel AI Gateway) is unchanged unless `FX_GATEWAY_PROTOCOL` is set.

## Environment

| Variable | Purpose |
| --- | --- |
| `FX_GATEWAY_PROTOCOL` | `openai` or `openai-compatible` enables this path |
| `FX_GATEWAY_BASE_URL` | Server origin, usually ending in `/v1` |
| `FX_GATEWAY_CHAT_URL` | Optional full chat URL |
| `FX_GATEWAY_ALLOW_PRIVATE_HTTP` | `1` to allow RFC1918 HTTP (not public HTTP) |
| `AI_GATEWAY_API_KEY` | Bearer token the server expects |
| `FX_MODEL` | Model id as advertised by `/v1/models` |

Do not put real hosts, tokens, or team names in the repository.

## Trust rules

- Loopback HTTP is always allowed as a base override.
- RFC1918 HTTP (`10/8`, `172.16/12`, `192.168/16`) requires `FX_GATEWAY_ALLOW_PRIVATE_HTTP=1` and `FX_GATEWAY_PROTOCOL=openai`.
- Userinfo in the URL is rejected.
- HTTPS origins (no userinfo in the URL) are allowed when `FX_GATEWAY_PROTOCOL=openai`, so a second OpenAI-compatible HTTPS gateway can be used.
- Bases ending in `/v1` or `/v2` append `/chat/completions` and `/models`.

## Protocol mapping

fx still builds a Vercel-style request internally. Before send, `src/gateway/openai_compat.zig` rewrites:

- `prompt` → `messages` (system/developer merged; content parts flattened)
- Vercel tool objects → `{type:function,function:{parameters}}`
- `maxOutputTokens` → `max_tokens` (default cap 8192; Qwen3.8 family uses 16384)
- `stream: true`
- Qwen / Huihui models also send official Qwen3.8 sampling: `temperature` 1.0, `top_p` 0.95, `presence_penalty` 0.0, `top_k` 20, `chat_template_kwargs.enable_thinking`, `preserve_thinking`, `reasoning_effort` medium (or fx `reasoning` / `FX_REASONING_EFFORT`)

Responses are parsed as OpenAI SSE (`choices[0].delta.content`, `finish_reason`).
