# 工作区分类审计

本轮对当前工作树做分类，不重命名时间戳历史文件，也不覆盖用户已有源码改动。

## 分类结论

- `src/` 48 个改动文件 + `build.zig`：fx Windows/Zig 0.16 兼容层，按构建/I-O、进程终端、session 持久化、网络协议、能力降级分组。
- `scripts/`：新增的 frame-evolve supervisor、agent adapter、GFXR evaluator、Mali guidance、reporter 和 spec。
- `tests/fixtures/`：bridge 与 Vulkan 单帧最小输入。
- `external/mali_offline_compiler/`：用户提供的离线工具和随附样例。
- `.e2e/`：被忽略的实验运行产物；不与源码混合。
- `docs/`：保持 research/plan/impl/architecture 四个时间线目录，新增主题入口索引。

详细入口：[`docs/README.md`](../README.md)、[`fx-windows/README.md`](../fx-windows/README.md)、[`gfxr-optimizer/README.md`](../gfxr-optimizer/README.md)。
