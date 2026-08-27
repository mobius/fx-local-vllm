# 上游更新与 Windows 验证实施记录

## 上游合并

新增本地 remote：

```text
upstream https://github.com/vercel-labs/fx.git
```

执行 fetch 后，将 `upstream/main` 合入当前 `main`。上游提交 `139a77a` 成为合并目标，保留本地两个 fx-win 适配提交。冲突解决后，`src/builtins/devbox.zig` 和对应旧 executor 接受上游删除，其余冲突按上游新架构与 Windows 兼容层组合处理。

## Windows 测试入口

修改 `build.zig`：

* POSIX 继续使用上游 `src/main.zig` 全量测试注册。
* Windows 使用 `tests/windows_smoke.zig` 作为 test root。
* Windows 继续使用 `tests/windows_test_runner.zig`，以兼容 Zig 0.16 的文件权限类型并输出明确的 OK、SKIP、FAIL 和 leak 统计。
* smoke test 通过 `FX_TEST_PRODUCT_EXE` 调用本次安装的 `zig-out/bin/fx.exe`，不依赖 PATH 中可能存在的旧版本。

`src/main.zig` 的 Windows 文件权限 enum 也将 `fromMode` 的属性值先落到本地 `u32`，避免 Zig 0.16 在某些实例化场景下把 `@enumFromInt` 误判为 comptime-only。

## 实际结果

执行：

```text
zig build --cache-dir .zig-cache --global-cache-dir .zig-cache\global test --summary all
```

结果：

```text
OK windows_smoke.test.Windows smoke runner targets Windows
OK windows_smoke.test.fx Windows product prints its version and exits
OK windows_smoke.test.fx Windows product renders top-level help and exits
Windows test summary: 0 failed, 0 skipped, 0 leaked
Build Summary: 9/9 steps succeeded; 1/1 tests passed
```

## 已知边界

上游 POSIX full registry 没有被伪装成 Windows 通过；Windows 测试明确选择可运行的产品 smoke 覆盖。生产源码图仍通过 Windows 编译，因此平台不支持的上游测试夹具不会阻止产品二进制验证，也不会被错误报告为 Windows 运行时能力。
