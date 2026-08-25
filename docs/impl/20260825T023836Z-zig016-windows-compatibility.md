# Windows 兼容实现迭代记录

## 本轮改动

- 在 `src/core/shared/io.zig` 增加统一的数值 PID 和 Windows child handle 转 PID 适配，并使用 `std.Io.Dir` 实现 Windows real path。
- 将登录交互、终端 raw mode/resize、MCP callback poll、terminal host poll 和 Unix socket timeout 在 Windows 编译时排除或返回不支持。
- 将 HTTP fetch 的 `POLL`/`pollfd`/`MSG.NOSIGNAL` 与 Windows 的 Winsock 结构和标志隔离。
- 将 auto-upgrade 在 Windows 目标上降级为不可用，避免生成不存在的 Unix 发布平台 URL。
- 将 terminal record 的 takeover PID 校验映射到 Windows 的 `u32`。

## 当时的编译迭代

| 迭代 | 结果 |
| --- | --- |
| 基线 | 37 个 Windows 编译错误 |
| 权限/进程/终端第一轮 | 22 个错误 |
| 路径、登录、HTTP、升级第二轮 | 7 个错误 |
| 当时记录 | 1 个链接错误：terminal host 的 `getuid` |

本轮没有写入真实 API token、私有主机名或用户目录到项目文档。后续 ReleaseFast、CLI 和 SSE E2E 结果见 `docs/impl/20260825T034700Z-windows-e2e-fix.md`。
