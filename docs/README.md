# fx-win 文档索引

本项目只保留 `fx` 本体、Windows/Zig 兼容改动和真实 variation-agent adapter。GFXR replay、单帧优化 harness、Mali 工具、实验和对应时间线已迁移到同级项目 [`microharness`](../../microharness/README.md)。

## 主题入口

| 分类 | 入口 | 内容 |
|---|---|---|
| fx Windows | [`fx-windows/README.md`](fx-windows/README.md) | Windows 兼容边界、源码改动分组、已知限制 |
| fx 适配脚本 | [`../scripts/README.md`](../scripts/README.md) | 保留的 fx variation-agent、bridge 测试和原有构建工具 |
| fx adapter fixture | [`../tests/fixtures/README.md`](../tests/fixtures/README.md) | OpenAI/vLLM bridge 和 fx gateway stub |
| 术语 | [`glossary.md`](glossary.md) | fx/Windows 共用术语；GFXR 术语见 microharness glossary |
| fx 时间线 | [`research/`](research/)、[`plan/`](plan/)、[`impl/`](impl/)、[`architecture/`](architecture/) | Windows、origin-main 和 adapter 记录 |

## 边界

- `src/`、`build.zig`：fx 生产源码和 Windows/Zig 兼容修改。
- `scripts/fx_fx_variation_agent.py`：真实 fx/Qwen variation-agent adapter，保留在本项目。
- `tests/fixtures/openai_gateway_bridge.py`、`fx_gateway_stub.py`：fx adapter 协议测试，保留在本项目。
- `scripts/binary_size.py`、`check-public-surface.sh`、`scripts/pgso/`：原有 fx 构建/PGSO 工具。
- `.e2e/`：仍可保存 fx 本体和游戏生成实验；GFXR 的 capture/replay 目录已迁移到 microharness/.e2e。
- `.planning/`：fx-win 的里程碑和状态记录。

## GFXR 迁移入口

- [microharness 文档](../../microharness/docs/README.md)
- [GFXR 优化主题](../../microharness/docs/gfxr-optimizer/README.md)
- [microharness 脚本](../../microharness/scripts/README.md)
- [microharness 实验](../../microharness/.e2e/)

迁移原因、清单和路径契约见：

- [`research/20260825T091633Z-microharness-migration.md`](research/20260825T091633Z-microharness-migration.md)
- [`impl/20260825T091633Z-microharness-migration.md`](impl/20260825T091633Z-microharness-migration.md)
