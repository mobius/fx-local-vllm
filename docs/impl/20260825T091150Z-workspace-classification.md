# 工作区分类整理实现记录

已新增以下索引和边界文件：

- `docs/README.md`
- `docs/fx-windows/README.md`
- `docs/gfxr-optimizer/README.md`
- `scripts/README.md`
- `tests/fixtures/README.md`
- `external/mali_offline_compiler/README.md`

同时在 `.gitignore` 增加 Python cache 规则，避免测试运行生成的 `__pycache__`、`.pyc`、pytest/mypy cache 进入工作树变更。

本轮没有移动 `src` 文件、重命名已有时间戳文档、删除 `.e2e` 运行证据或修改 GFXR evaluator 逻辑。
