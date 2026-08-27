# 上游更新与 Windows 验证计划

1. 获取 canonical `upstream/main`，记录共同基线、分叉数量和上游 HEAD。
2. 以非破坏方式合并上游，逐个解决冲突，保留已经验证过的 Windows 兼容层。
3. 使用项目本地 Zig cache 编译生产二进制，避免污染全局环境。
4. 为 Windows 建立独立的 focused smoke root：完整生产源码照常编译，测试入口通过安装后的 `zig-out/bin/fx.exe` 做公开 CLI 验证。
5. 执行 `zig build test`，再直接检查工作区构建二进制的退出码和输出。
6. 运行 `zig fmt`、`git diff --check`、冲突标记扫描和敏感信息扫描，最后提交本地合并结果；本轮不自动 push。

## 验收条件

* 上游 HEAD 已进入当前分支历史。
* 生产构建成功。
* Windows smoke 测试验证版本和帮助命令均成功退出。
* 未遗留未解决冲突、明文凭据或明显本机路径泄露。
* 文档能够说明 Windows focused test 与 POSIX full registry 的边界。
