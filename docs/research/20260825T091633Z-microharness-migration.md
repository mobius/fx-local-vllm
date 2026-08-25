# microharness 迁移研究记录

## 目标

将 GFXR replay、frame-evolve supervisor、deterministic Vulkan fixture、Mali Offline Compiler、实验目录和 GFXR 时间线从 fx-win 分离；fx 本体和 Windows/Qwen variation-agent adapter 继续留在 fx-win。

## 边界判断

- 保留在 fx-win：`src/`、`build.zig`、`scripts/fx_fx_variation_agent.py`、fx adapter 测试和 OpenAI/vLLM bridge fixture。
- 迁移到 microharness：GFXR supervisor/evaluator、deterministic materializer、GFXR spec、Vulkan fixture、Mali 工具、GFXR docs 和 18 个已确认的 GFXR `.e2e` 目录。
- fx 生成 HTML、fx session 和非 GFXR 实验不迁移。

原因是 GFXR harness 是外部 replay/evaluation 工作流，fx 只作为可替换的 agent/adapter；拆开后可以独立演化、测试和保存实验数据。

入口：[`microharness/docs/README.md`](../../microharness/docs/README.md)。
