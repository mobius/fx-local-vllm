# microharness 迁移实现记录

## 已迁移

- 18 个 GFXR 实验目录：固定 Vulkan capture、probe 和所有 `frame-evolve-*` run。
- frame-evolve supervisor、deterministic materializer、Mali evaluator、GFXR evaluators、reporter、spec 和 focused tests。
- `tests/fixtures/vulkan_single_frame/`。
- `external/mali_offline_compiler/` 的 binary、DLL、样例、schema 和用户指南。
- research/plan/impl/architecture 下 GFXR 时间戳记录，保留原文件名和时间线。

## 跨项目路径

- `microharness/scripts/fx_frame_evolve.qwen_cases.json` 等 Qwen spec 的 fx binary 改为 `../../fx-win/zig-out/bin/fx.exe`。
- Qwen agent command 改为 `../../fx-win/scripts/fx_fx_variation_agent.py`。
- adapter bridge 仍位于 `fx-win/tests/fixtures/`。

## fx-win 清理

fx-win 只保留 Windows 源码、fx adapter、adapter tests、原有 build/PGSO 脚本和非 GFXR 实验。原 GFXR 目录入口改为指向 microharness。
