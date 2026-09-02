# fx-win 上游持续跟踪计划

1. 定期刷新 `upstream/main`，同时保留 `origin/main` 和本地 HEAD 的可比基线。
2. 按 process、shell、terminal、session、MCP 和 release/runtime overhead 分类上游提交。
3. 对涉及 Windows compatibility shim、composition root 和进程生命周期的文件先做
   merge-tree 预览。
4. 在独立分支或可恢复工作树中解决冲突，先跑 Windows Debug/ReleaseSafe build 和
   focused smoke，再决定是否更新 `origin/main`。
5. 对新合入的 terminal/shell changes 增加针对 replay/子进程自动退出的回归测试。

本轮停止在跟踪和风险标注阶段，没有修改产品代码、合并或推送。
