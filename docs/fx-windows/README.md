# fx Windows 修改分类

本页只整理 `fx` 本体的 Windows 兼容改动，不把 GFXR 优化 harness 混进生产源码。文件清单按当前工作树相对 `origin/main` 的 diff 归类；这些改动原本就是工作区中的用户改动，本次只建立索引，不改变源码归属。

## 代码分组

### 1. 构建、平台边界和路径

- `build.zig`
- `src/main.zig`
- `src/core/shared/io.zig`
- `src/core/workspace/pathing.zig`

职责包括 Winsock 链接、Windows command line、HANDLE/PID 转换、real path、文件权限兼容和路径 containment。

### 2. 进程、终端和 Console

- `src/core/execution/process_tree.zig`
- `src/tools/shell/background_process.zig`
- `src/core/terminal/host.zig`
- `src/core/terminal/store.zig`
- `src/core/terminal/tmux_session.zig`
- `src/ui/ask_presentation.zig`
- `src/ui/shell_runtime.zig`
- `src/ui/terminal/terminal.zig`
- `src/ui/transcript/runtime.zig`

职责包括 Windows HANDLE 生命周期、数字 PID、ConDrv/console mode、无 TTY 降级、resize signal 边界和 terminal host 不支持路径。

### 3. 持久化、session、skill 和 trace

- `src/builtins/context.zig`
- `src/core/session/*.zig`
- `src/core/skills/skill_contract.zig`
- `src/core/skills/skill_runtime.zig`
- `src/core/shared/debug_trace.zig`

职责包括 no-follow stat 后的安全打开、同步句柄、顺序读取、文件 identity 检查、原子持久化、trace 追加和 Windows ACL 兼容。重点根因是 Zig 0.16 Windows positional reader / no-follow handle 组合的状态机问题。

### 4. 网络、认证和协议边界

- `src/acp/jsonrpc.zig`
- `src/core/auth/login_flow.zig`
- `src/core/auth/oauth_session.zig`
- `src/core/mcp/mcp_auth.zig`
- `src/core/mcp/mcp_auth_store.zig`
- `src/tools/web/http_fetch.zig`

职责包括 Windows 不支持的交互登录/MCP 能力降级、Winsock poll 结构、`MSG.NOSIGNAL` 替代和协议层错误返回。

### 5. 应用、CLI、能力开关和升级降级

- `src/builtins/devbox.zig`
- `src/builtins/hooks/herdr.zig`
- `src/core/agent/runtime/orchestrator.zig`
- `src/core/app/*.zig`
- `src/core/cli/*.zig`
- `src/core/config/settings_store.zig`
- `src/core/images/image_attachments.zig`
- `src/core/input/editor_state.zig`
- `src/core/permissions/sandbox.zig`
- `src/core/subagent/ui_projection.zig`
- `src/core/tooling/tool_runtime.zig`
- `src/core/upgrade/*.zig`

职责包括 headless/Windows 能力判断、PID/信号调用替换、平台不可用功能的稳定返回、配置/权限/agent 状态的兼容处理。

## 文档时间线

- [Zig 0.16 Windows 兼容研究](../research/20260825T023836Z-zig016-windows-compatibility.md)
- [Windows ask E2E 根因](../research/20260825T034700Z-windows-ask-e2e-root-cause.md)
- [Windows 保存路径根因](../research/20260825T045853Z-windows-save-path-root-cause.md)
- [Windows I/O 架构](../architecture/20260825T034700Z-windows-runtime-i-o.md)
- [Windows 持久化架构](../architecture/20260825T045853Z-windows-persistence-boundary.md)
- [Windows E2E 实现记录](../impl/20260825T034700Z-windows-e2e-fix.md)
- [Windows save-path 实现记录](../impl/20260825T045853Z-windows-save-path-fix.md)
- [Windows + Qwen E2E](../architecture/20260825T055956Z-windows-qwen-e2e-final.md)

## 验证边界

- 已有记录显示 Windows Debug 和 ReleaseFast build 通过。
- 全量 `zig build test` 仍有已记录的 Zig 0.16 Windows test-only 编译问题；不能把 focused test 结果写成全量通过。
- Windows terminal/PTY 仍是明确限制；真实 Qwen adapter 使用 bounded file-tool contract，不依赖 terminal 工具。
