# Windows 保存路径实现记录

## 代码改动

- `core/shared/io.zig` 的 `openExistingRegularFile` 在 Windows 使用“初始 no-follow stat + 同步打开 + inode 校验”。
- `session_authority`, `session_display_metadata`, `session_usage_sidecar`, `session_latest_pointer` 和 `session_log` 对普通文件读取采用同一安全边界。
- `session_store.validateUsageRecoveryMarker` 移除 `readPositionalAll`，改为同步句柄上的顺序 streaming reader。
- `core/shared/io.zig` 的 bounded whole-file reader 使用顺序 streaming reader。
- trace 文件追加不再使用 Windows 上不稳定的 libc `lseek` shim，而是通过 Zig Io stat/seek/writer 接口追加。
- Debug 构建保留异步 unwind tables，便于 Windows 原生栈定位；发布构建仍关闭 unwind tables。

## 验证结果

- Debug build：通过。
- `fx ask --auto --json --no-save`：通过，fixture 输出 `Windows fx SSE E2E passed.`。
- `fx ask --auto --json` 默认保存，prompt 为“创建一个3d starwar html游戏，用html。跟踪生成流程。”：通过，退出码 0。
- `fx sessions --json`：通过，保存的 history 长度为 1。
- `fx session <id> --json`：通过，能读回用户 prompt、assistant 输出和空 execution。
- `FX_TRACE_LOG`：生成 agent prompt finish trace；后续仍需在不同 scope/并发场景补充 trace 文件追加测试。

## 保留的限制

fixture 只验证 fx 的请求、SSE 解码、session 持久化和 replay，不生成真实 HTML。真实 vLLM `/v1` 接入和 GPU 端到端运行另记为下一轮工作。`zig build test` 当前仍因 98 个 Windows test-only 编译错误失败，主要是权限 enum、POSIX poll/signal/socketpair 和 Windows HANDLE/PID 类型分支；产品 Debug/ReleaseFast 构建与上述 CLI E2E 不受影响。
