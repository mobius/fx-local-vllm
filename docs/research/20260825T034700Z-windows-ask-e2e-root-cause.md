# Windows `fx ask` E2E 根因研究

## 现象

Windows ReleaseFast 二进制可以构建，`help`、`status` 和 `doctor` 可运行，但带工作区上下文的 `fx ask` 在真正发出模型请求前退出。初始表现为 `reached unreachable code`，随后通过临时 panic 地址定位到 Zig 0.16 `std.Io.Threaded` 的 Windows `NtReadFile` 路径。

## 定位结论

1. 启动参数、环境读取和工作区 realpath 已经完成。
2. 崩溃发生在默认 context provider 读取工作区 `AGENTS.md` 时，而不是模型、API key 或 SSE 响应阶段。
3. Zig 0.16 在 Windows 上对 `follow_symlinks = false` 的文件打开路径创建异步句柄，但返回的 `std.Io.File.Flags` 仍标记为同步；随后 positional read 进入不匹配的 `NtReadFile` 状态机，触发 `STATUS_CANCELLED` 或 `STATUS_INVALID_PARAMETER`。
4. Context 文件是顺序、有限大小的输入，因此修复采用同步打开、streaming reader、单次读入后 UTF-8 校验，并保留初次 no-follow stat 与 Windows 文件 identity 比对。

## 其他启动兼容性问题

- Windows 进程参数来自 PEB 的 WTF-16 command line，不能按 Unix `argv` 的裸指针假设处理。
- Zig 0.16 的 `std.mem.copyForwards` 要求源和目标切片等长；输入编辑器删除范围的旧调用会在 Windows 触发 `unreachable`。
- Windows 权限字段是文件属性，不是 POSIX mode；项目 root option 提供了兼容的 mode helper，且只把只读属性映射为只读语义。

## 验证边界

本轮本地 fixture 使用当前 fx 所需的 Vercel AI Gateway SSE 事件协议，验证了 Windows 启动、上下文读取、HTTP 请求和响应消费。它不等同于已连接用户提供的远端 vLLM OpenAI-compatible endpoint；后者需要协议适配层和可达的真实主机。
