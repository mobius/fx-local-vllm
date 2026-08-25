# Windows E2E 验证计划

## 已执行

1. 在已确认的 Windows CPU/GPU 与 Zig 0.16 环境中构建 Debug 和 ReleaseFast。
2. 运行构建产物的 `status --json`、`doctor` 和 `ask --json --no-save`。
3. 使用本地、无外部网络依赖的 SSE gateway fixture，验证中文 3D Star Wars HTML 游戏 prompt 的完整请求链路。
4. 运行全量 `zig build test`，记录剩余的上游测试源码平台兼容边界。

## 通过标准

- 构建退出码为 0。
- CLI 不因 Windows 参数、终端或文件 I/O 崩溃。
- `fx ask` 返回结构化 JSON，包含 assistant output 且退出码为 0。
- 进程 stderr 不包含 context unreadable、NTSTATUS 或 panic 诊断。
- 文档不写入 API token、私有主机名或真实用户目录。

## 后续真实模型验证

用户的本地 vLLM 入口是 OpenAI-compatible API，而当前 fx gateway client 构造的是 AI Gateway 的 `prompt`、`toolChoice` 和对应 SSE 事件。真实 Qwen 验证应在增加适配层，或部署一个协议桥接服务后进行；在此之前不能把本地 fixture 结果表述为远端 Qwen 已验证。
