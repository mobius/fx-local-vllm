# fx-win 上游持续跟踪架构记录

```text
vercel-labs/fx upstream/main
          |
          | fetch only
          v
local comparison boundary
          |
          +── process / shell / terminal / session review
          +── merge-tree conflict preview
          +── Windows build and smoke gate
          v
mobius/fx-local-vllm origin/main
```

`upstream` 负责提供候选源历史，`origin` 是用户 fork 的发布分支。上游的通用
runtime 修复不能直接替代 fx-win 的 Windows compatibility shim；只有完成冲突
解决和 Windows 验证后，才允许推进 origin/main。
