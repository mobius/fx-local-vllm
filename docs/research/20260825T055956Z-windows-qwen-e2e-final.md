# Windows + 真实 Qwen E2E 最终研究记录

## 问题

确认 Windows 原生 `fx` 是否能通过本地转发访问 4×V100 上的 Qwen vLLM，并把模型生成的 HTML 写入工作目录、在浏览器中运行。

## 环境证据

- 远端 `4xv100`：Linux 主机，4 张 Tesla V100-SXM2-32GB，计算能力 7.0；项目工作树已 fetch，`HEAD` 与 `origin/main` 对齐到 `fc124be4f4c67ac4c1b7a0b586a3831e93b463d6`。
- 远端服务：`/v1/models` 返回 `Qwen3.8-27B-INT4`，权重根目录为对称压缩 INT4，最大上下文为 131072；直接健康请求返回 `OK`。
- Windows 本地产物：Zig 0.16 Debug 和 ReleaseFast 构建均通过。
- 真实链路：Windows `fx` → 测试专用 OpenAI-to-AI-Gateway SSE 协议桥 → SSH 本地端口转发 → 4×V100 vLLM → `write_file`。

## 失败根因与修复方向

1. Windows 驱动器根路径被旧的 POSIX `/` 解析器吞掉，导致 `write_file` 返回 `bad_path_name`；修复 workspace bounded path、drive/UNC root、分隔符和大小写不敏感的 containment 判断。
2. Zig 0.16 Windows no-follow 文件句柄与 positional reader 组合触发 `STATUS_CANCELLED`/`STATUS_INVALID_PARAMETER`；普通文件现在采用初始 no-follow stat、同步打开、inode identity check，再用 sequential streaming reader。
3. Qwen 的 chat template 要求 system message 位于 messages 首位；测试桥统一整理 system message，并把 OpenAI streaming chunk 映射为 fx 当前需要的 SSE 事件。
4. Windows native terminal/PTY 仍是负能力；本次 prompt 明确要求先调用 `write_file`，因此 E2E 不依赖 terminal。

## 浏览器证据

本地 HTTP 服务打开生成的 `star-war-3d.html` 后：

- 页面标题为“星球大战 3D — 超空间飞行”；
- 画布为 1280×720，截图可见星空、行星和开场字幕；
- 浏览器控制台没有 error/warning。

## 结论

Windows 原生产品构建和真实 Qwen 工具调用链已打通。当前验证的是文件工具驱动的生成路径；Windows terminal/PTY 和完整 Windows 单元测试兼容仍需独立工作流。
