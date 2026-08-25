# 工作区分类架构

```text
fx production source
  └─ src/ + build.zig
       └─ Windows compatibility boundary

optimization implementation
  ├─ scripts/                 supervisor / agent / evaluator / reporter
  ├─ tests/fixtures/          reproducible input
  └─ external/mali.../        offline guidance tool

experiment evidence
  └─ .e2e/                    ignored capture / replay / ledger / trace

knowledge record
  ├─ docs/research/           why and root cause
  ├─ docs/plan/               intended next actions
  ├─ docs/impl/               what was changed and verified
  └─ docs/architecture/       stable boundaries and data flow
```

源码、实验 harness、第三方工具和运行证据保持四个边界；主题 README 负责导航，时间戳文档负责不可变的迭代记录。
