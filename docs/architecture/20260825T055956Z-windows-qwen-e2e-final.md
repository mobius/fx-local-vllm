# Windows + 真实 Qwen E2E 架构记录

## 运行边界

```text
Windows fx.exe
    │  AI Gateway SSE（生产既有协议）
    ▼
tests/fixtures/openai_gateway_bridge.py
    │  OpenAI Chat Completions
    ▼
SSH local port forwarding
    ▼
4×V100 vLLM /v1/chat/completions
    │  Qwen3.8-27B-INT4
    ▼
fx tool runtime → workspace pathing → star-war-3d.html
    ▼
local browser → 1280×720 canvas
```

## 设计决策

1. 生产 fx 的 transport 没有被测试桥替换。桥只作为可复现的测试边界，避免把 OpenAI-specific 请求形状和 vLLM 地址硬编码进默认产品路径。
2. Windows 文件安全边界分成“路径 containment”和“文件身份”两层：前者防止跨 workspace 写入，后者防止打开前后文件对象变化；两层都在 workspace 工具落盘前生效。
3. 真实 Qwen 会话的 agent trace 与生成物并列保存，便于后续把 prompt、工具调用、模型输出和画面回归关联起来。
4. 浏览器验证是独立的运行时检查，不把静态 HTML 存在误判为画面成功；当前证据是可见画布、标题、截图和无控制台错误。

## 后续演进

- 正式接入 vLLM 时新增明确的 provider/协议适配层，保留 AI Gateway 的 auth、SSE、tool-call 和 trace 语义。
- 若需要 terminal 工具，增加 Windows ConPTY backend，并单独覆盖 cmd/PowerShell 的生命周期、取消和输出编码。
- 将 replay capture、shader/pass candidate 和浏览器/图形帧 evaluator 接到同一 session lineage；这属于后续优化搜索阶段。
