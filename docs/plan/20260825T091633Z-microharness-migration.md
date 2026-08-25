# microharness 迁移计划记录

1. 在同级目录创建 `microharness` 的 scripts、tests/fixtures、external、docs 和 `.e2e` 边界。
2. 迁移 GFXR supervisor、deterministic agent、evaluators、spec、Vulkan fixture、Mali 工具及 GFXR 历史文档。
3. 保留 fx variation-agent、bridge 和 fx-win 构建产物，通过跨项目相对路径供 microharness 调用。
4. 将 fx-win 原 GFXR 入口改为迁移指针，不删除 Windows/origin-main/adapter 历史记录。
5. 验证 spec 路径、实验目录数量、Python import、敏感信息和两个项目的 Git 状态。

后续新的 GFXR 实验只写入 microharness；新的 fx Windows 兼容问题只写入 fx-win。
