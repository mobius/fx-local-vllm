# fx-win 上游持续跟踪研究记录

## 当前分叉

刷新 `upstream` 后：

| 引用 | 提交 |
| --- | --- |
| `fx-win` `HEAD` | `004afb6` |
| `origin/main` | `004afb6` |
| `upstream/main` | `dd7179f3` |
| 上游新增 | 302 commits |

上游最新合并为 `subagent-managed-execution`，时间为 2026-09-01（上游时区）。
同时存在 `v0.0.7` release tag 和多个进行中的 runtime/terminal 分支。

## 与 fx-win 相关的更新

近期上游出现以下方向：

* managed shell execution：统一 shell 子进程的生命周期、权限和恢复边界；
* subagent managed execution：调整子 agent 执行、模型安全 handle 和 contract digest；
* terminal outcome integrity：保留终端结果并简化终止状态；
* rapid-exit handoff、shell cancellation/recovery 和 terminal transcript lineage；
* MCP/ACP 生命周期、trust、auth、catalog pagination 和工具结果契约；
* runtime/binary overhead、session error constants 和冗余工具削减。

这些改动没有明显以 Windows 命名的专项提交，但会触及 Windows 适配依赖的
process、terminal、session、shell 和 main composition root。

## 合并风险

不改工作树的 merge-tree 预览发现 5 个冲突路径：

* `src/builtins/context.zig`
* `src/core/skills/skill_runtime.zig`
* `src/core/terminal/host.zig`
* `src/main.zig`
* `src/tools/shell/background_process.zig`

因此当前只完成上游跟踪，没有自动合入。
