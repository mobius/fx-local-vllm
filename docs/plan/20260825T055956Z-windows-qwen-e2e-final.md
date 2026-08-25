# Windows + 真实 Qwen E2E 收尾计划

## 已完成

- [x] 在实施前核对本机 RTX 4080 SUPER、远端 4×V100、驱动和服务模型能力。
- [x] fetch 最新 `origin/main` 并确认远端项目工作树没有需要覆盖的源代码改动。
- [x] 修复 Windows drive/UNC root 的 workspace path resolution。
- [x] 修复 skill 扫描和普通文件读取的 Windows Zig 0.16 I/O 边界。
- [x] 通过 Debug 和 ReleaseFast product build。
- [x] 通过本地 fixture SSE E2E、session persistence、trace 追加和真实 Qwen 健康请求。
- [x] 通过真实 Qwen 生成 `star-war-3d.html`，复制结果和 trace 到 `.e2e/real-qwen-game6-20260825/`。
- [x] 在浏览器中加载页面并检查截图及控制台。
- [x] 完成 token-like value、绝对环境路径和远端内部路径扫描。

## 明确未完成项

- `zig build test` 仍有 98 个 Windows test-only 编译错误，集中在权限 enum、POSIX poll/signal/socketpair 与 Windows HANDLE/PID 分支；不影响本轮 product build 和 CLI E2E。
- Windows terminal/PTY 尚未实现 cmd/PowerShell/ConPTY 适配；本轮通过 `write_file` 路径完成真实工具调用，未把该限制伪装成通过。
- 生产版 fx 仍使用 AI Gateway SSE 协议；OpenAI/vLLM 兼容入口的转换器仅位于 `tests/fixtures/`，下一步若要直接连接 vLLM，应设计正式 provider/adapter，而不是把 fixture 移入默认运行路径。
- RenderDoc/GFXReconstruct replay 与 20 条以上 shader/pass 优化路径不属于本轮 Windows + Qwen E2E 收尾范围。

## 验收标准

本轮以“真实模型、真实工具调用、Windows 文件落盘、浏览器可见画面、可回读 trace、无凭据泄露”为通过；以上标准均已满足。
