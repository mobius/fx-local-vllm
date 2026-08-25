# fx-win 脚本边界

GFXR frame-evolve、replay evaluator、Mali guidance 和相关测试已迁移到同级 [`microharness/scripts/README.md`](../../microharness/scripts/README.md)。

## 本项目保留

- `fx_fx_variation_agent.py`：真实 fx/Qwen variation-agent adapter。
- `test_fx_fx_variation_agent.py`：adapter focused tests。
- `test_openai_gateway_bridge.py`：OpenAI-compatible bridge focused tests。
- `binary_size.py`、`check-public-surface.sh`、`scripts/pgso/`：原有 fx 构建和 PGSO 工具链。

adapter 使用本项目的 `../zig-out/bin/fx.exe`；microharness 的 Qwen spec 通过 `../../fx-win/scripts/fx_fx_variation_agent.py` 调用它。
