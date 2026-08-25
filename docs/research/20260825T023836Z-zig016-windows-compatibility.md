# Zig 0.16 Windows compatibility research

## 结论

本轮以本机 `x86_64-windows`、Zig `0.16.0` 为目标，按编译器引用链核对剩余问题。Zig 0.16 将许多旧的 POSIX 直接调用标记为仅兼容旧代码的入口，并要求新代码优先使用 `std.Io`；Windows 的 `std.process.Child.Id` 是进程句柄，不是可直接格式化的整数 PID。

## 已验证的标准库边界

- `std.Io.Dir.realPath` / `realPathFile` 可以从 Windows 目录句柄解析目录本身或相对成员路径，适合替代 Unix `/proc/self/fd` 和 `realpath`。
- `std.process.Child.Id` 在 Windows 上是 `HANDLE`；持久化到 fx 的文本 PID 前必须调用 Win32 `GetProcessId`。
- `std.posix.pollfd`、`std.posix.POLL`、`std.posix.kill`、`std.posix.tcsetattr` 不能在 Windows 代码路径中实例化。交互式 Unix 逻辑需要在编译期排除，或改用 `std.Io.File`。
- 自动升级和 Unix domain terminal host 当前只支持 macOS/Linux；Windows 应编译出可运行 CLI，并把这些可选能力报告为不可用。

## 当时的编译证据

初始 Windows 编译有 37 个错误。本轮记录时已收敛到 1 个链接错误：`getuid`。该问题随后在 `20260825T034700Z` 迭代中解决；当前状态和 E2E 证据以最新迭代文档为准。
