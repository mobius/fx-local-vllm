# Windows 编译修复计划

## 已完成

1. 先确认本机 CPU/GPU/目标环境：本机为 Windows x86_64，Zig 0.16.0；图形 E2E 所需 Vulkan harness 已独立通过。
2. 为文件权限、PID、路径解析、终端输入、后台进程、HTTP poll/send 和可选 Unix 服务增加目标平台边界。
3. 每轮使用本地 `.e2e/zig-global-cache`，不写入全局依赖环境。

## 当时的后续步骤

1. 修复 terminal host 的 `std.c.getuid` 链接残留。
2. 重新编译 `fx.exe`，随后执行非交互 CLI smoke test。
3. 对 Windows 不支持的 Unix terminal host、auto-upgrade、后台进程信号行为做运行时负能力验证。
4. 审计 diff、文档和测试产物中的敏感信息，再整理远端 Qwen endpoint 的真实 agent E2E 条件。

以上步骤已经由后续迭代继续执行；结果见 `docs/impl/20260825T034700Z-windows-e2e-fix.md`。

## 验收口径

“Windows 可运行”首先要求原生 `fx.exe` 编译并能启动；不把 Unix-only terminal host 或 POSIX 进程树控制伪装成 Windows 已支持能力。
