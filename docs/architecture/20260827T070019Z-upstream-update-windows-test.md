# 上游同步后的 Windows 测试架构

## 分层

```text
upstream/main
    |
    v
fx-win main  ── 保留 Windows compatibility shim
    |
    +── zig build ── 完整 src/main.zig 生产图
    |
    +── POSIX test ── upstream root registry
    |
    +── Windows test ── tests/windows_smoke.zig
                              |
                              v
                      zig-out/bin/fx.exe
```

## 设计理由

`src/main.zig` 的生产导入图必须在 Windows 上完整编译，以便发现真实的类型、链接和平台适配问题。另一方面，上游 root test registry 有意覆盖 Unix 进程树、PTY、poll 和 signal 语义，其中部分测试在 Windows 的 Zig 0.16 标准库中连测试数据类型都不存在。把两者拆开可以保留生产编译的严格性，同时让 Windows test step 只报告 Windows 可执行的验证结果。

Windows smoke 不直接复制内部实现，而是启动实际构建出的产品并检查公开 CLI 合约。这一层可以发现入口初始化、链接、Windows 参数处理和进程退出问题；更深的终端、网络和 agent E2E 仍由后续专门的 Windows harness 覆盖。

## 数据与权限边界

所有构建缓存留在仓库下，测试通过 build step 注入产品路径。测试不会写入用户全局安装位置，也不会使用 PATH 中的 fx。上游 remote 只用于本地 fetch 和合并，不在本轮自动 push。
