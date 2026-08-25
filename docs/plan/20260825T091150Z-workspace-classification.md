# 工作区分类整理计划

## 已执行

1. 保留原有 timestamp 文档，不做批量移动，避免历史链接失效。
2. 增加 `docs/README.md` 总索引和 fx Windows/GFXR 两个主题索引。
3. 为 `scripts/`、`tests/fixtures/`、`external/mali_offline_compiler/` 增加边界说明。
4. 给 Python 运行缓存增加全局忽略规则；仅清理明确生成的 `tests/fixtures/__pycache__` 文件。

## 后续规则

- 新的 Windows 兼容发现继续写入四个时间线目录，并在 `fx-windows/README.md` 增加链接。
- 新的 replay/evaluator/agent 迭代继续写入 GFXR 时间线，并同步 `gfxr-optimizer/README.md`。
- `.e2e/` 只保留本机证据，不把它作为源码整理目录。
- 任何新术语先补 `docs/glossary.md`，再进入实现或报告。
