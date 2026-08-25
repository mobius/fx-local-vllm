# fx adapter fixtures

这里保留 fx 本体相关的协议适配测试输入：

- `openai_gateway_bridge.py`：把 OpenAI-compatible `/v1/chat/completions` 转成 fx variation-agent 所需的 bounded bridge。
- `fx_gateway_stub.py`：本地 fx gateway 协议测试 stub。

Vulkan 单帧 producer 和 shader fixture 已迁移到 [`microharness/tests/fixtures/README.md`](../../../microharness/tests/fixtures/README.md)。真实 capture、截图、SPIR-V、ledger 和 trace 不放在本目录。
