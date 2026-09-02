# fx-win 上游合并研究记录

## 合并对象

本轮将已刷新到 `dd7179f3` 的 `vercel-labs/fx` `upstream/main` 合入本地
`fx-win`。合并前本地第一父基线为 `08065421`，`origin/main` 为
`004afb6`；上游相对基线新增 302 个提交。

## 环境判断

执行前确认：AMD Ryzen 9 9950X（16 核 32 线程）、NVIDIA GeForce RTX 4080 SUPER
（16,376 MiB，Compute Capability 8.9）、Zig 0.16.0、CMake 3.29.2、Ninja 1.12.0
和 Python 3.11.9。环境支持本地 Windows 编译、运行和 smoke 验证；没有安装
新软件。

## 上游变化重点

本轮上游包含 shell/subagent managed execution、process identity、terminal
outcome/recovery、rapid-exit handoff、MCP/ACP lifecycle、TUI 和 runtime/binary
overhead 等变化。它们比上一轮更接近我们遇到的 Windows 子进程和 terminal 生命周期
问题，但没有看到以 Windows 命名的专项修复。

## 冲突定位

merge-tree 预览和实际合并均定位到 5 个冲突：

* `src/builtins/context.zig`
* `src/core/skills/skill_runtime.zig`
* `src/core/terminal/host.zig`
* `src/main.zig`
* `src/tools/shell/background_process.zig`

`src/main.zig`、`context.zig` 和 `skill_runtime.zig` 保留本地 Windows 分支并
吸收上游导入；terminal host 采用上游 accept-thread/startup recovery 架构，保留
Windows poll 和 PID 兼容；旧 background process 实现接受上游删除。
