# microharness 双项目边界架构

```text
fx-win
  ├─ src/ + build.zig                 fx 本体 / Windows compatibility
  ├─ zig-out/bin/fx.exe               构建产物
  └─ scripts/fx_fx_variation_agent.py 真实 Qwen variation adapter
                    │ cross-project command
                    ▼
microharness
  ├─ scripts/fx_frame_evolve.py       GFXR supervisor
  ├─ scripts/*evaluator*.py           replay/runtime/static guidance
  ├─ tests/fixtures/vulkan_single_frame
  ├─ external/mali_offline_compiler
  ├─ .e2e/                             GFXR capture/replay evidence
  └─ docs/                             GFXR research and experiment history
```

GFXR 项目不复制或修改 fx 生产源码；真实 Qwen case 只通过 adapter 命令和 fx binary 边界调用 fx-win。这样 Windows compatibility 与 graphics optimization 的变更可以独立审计和提交。
