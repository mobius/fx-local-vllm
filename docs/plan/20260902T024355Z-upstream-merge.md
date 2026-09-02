# fx-win 上游合并验证计划

1. 在不丢失跟踪文档的前提下建立干净合并基线。
2. 合并 `upstream/main`，逐个处理 5 个冲突并保留 Windows compatibility shim。
3. 编译完整 Windows production graph，先修复真实的平台类型/链接错误。
4. 运行默认 Windows Debug test gate，再用独立 cache 运行 ReleaseSafe gate。
5. 直接运行 `zig-out/bin/fx.exe` 检查版本、帮助输出和进程退出。
6. 审计冲突标记、旧模块引用、敏感信息、临时 cache 和 Git 合并状态。

## 判定

只有 production build、Windows smoke 和直接二进制 happy path 全部通过，才创建
本地 merge commit；上游 POSIX-only benchmark 不在 Windows 默认 gate 中伪装通过。
