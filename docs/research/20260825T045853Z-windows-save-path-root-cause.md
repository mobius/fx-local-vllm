# Windows 保存路径根因研究

## 范围

本轮针对 Zig 0.16.0、Windows 原生构建的 `fx ask` 默认保存路径进行定位。此前 `--no-save` 已能完成 SSE 请求，但启用会话持久化后仍会在第一次模型调用期间崩溃。

## 证据

带 Debug 栈信息的复现栈落在 Zig 标准库 `std/Io/Threaded.zig` 的 `readFilePositionalWindows`：Windows 文件读取状态为 `PENDING`，而文件句柄被标记为不可继续等待的同步句柄，标准库因此进入 `unreachable`。调用链是：

`gateway_step.streamGatewayCompletion` → `session_usage` → `cli_ask.persistUsageCheckpoint` → `session_store.prepareUsageRecoveryCheckpoint` → `validateUsageRecoveryMarker` → `readPositionalAll`。

根因不是 SSE 响应内容，而是 usage recovery 标记的 Windows no-follow 文件打开方式与 Zig 0.16 positional reader 的组合。会话初始化、事件日志、原子替换和后台恢复已经先后通过；这一处标记读取是保存路径的最后一个已观测崩溃点。

## 结论

Windows 读取普通文件采用两阶段策略：

1. 先用 `follow_symlinks=false` 做最终路径的 regular-file、单链接和权限检查。
2. Windows 再以普通同步句柄打开，并比较打开后 inode 与初始 stat 的 inode；不一致则拒绝。
3. 读取使用顺序 streaming reader，避开 Zig 0.16 Windows positional reader 的取消状态机。

这保留了最终路径检查和替换竞态防护，同时绕开当前 Zig 标准库的句柄实现缺陷。该方案是兼容性边界，不应被解释为放宽 symlink 安全策略。

## 未覆盖

本地验证使用确定性的 SSE fixture；远端 4xV100 地址未在当前环境提供，因此没有宣称已完成远端编译。完整 Zig 测试目标仍包含若干 Windows 专属的 test-only POSIX 分支，需单独清理。
