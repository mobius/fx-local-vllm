# fx-win 上游合并实施记录

## 冲突处理

* `src/main.zig`：保留 Windows `std_options_FilePermissions`，版本更新为上游
  `0.0.7`。
* `src/builtins/context.zig`：保留 Windows 顺序读取和 inode identity check，
  删除不再使用的旧 background runtime import。
* `src/core/skills/skill_runtime.zig`：合并 Windows 平台分支与上游 capability
  retrieval/lexical relevance 导入。
* `src/core/terminal/host.zig`：采用上游 managed startup/accept thread，保留
  Windows unsupported poll 分支、socket timeout 分支和数字 PID。
* `src/tools/shell/background_process.zig`：按上游 shell-managed execution 重构
  接受删除。

## Windows 兼容修复

合并后针对生产编译错误补充：Windows 禁用 POSIX SIGINT guard；shell process
provider 在 Windows/WASI 明确返回 identity unsupported；process snapshot 显式
承载平台 error；默认 Windows 测试隔离无法被 Zig 0.16 Windows toolchain 加载的
`activity_progress` benchmark。

## 验证结果

```text
zig build --cache-dir .zig-cache --global-cache-dir .zig-cache\global
    Debug production build: passed

zig build --cache-dir .zig-cache --global-cache-dir .zig-cache\global test
    Windows smoke: 3 passed, 0 failed, 0 skipped, 0 leaked

zig build -j1 --cache-dir .zig-cache-upstream-merge-release --global-cache-dir .zig-cache-upstream-merge-release\global -Doptimize=ReleaseSafe test
    Build Summary: 7/7 steps succeeded
    ReleaseSafe smoke: 3 passed, 0 failed, 0 skipped, 0 leaked

zig test -OReleaseSafe tests/windows_smoke.zig --test-runner tests/windows_test_runner.zig
    Windows smoke: 3 passed, 0 failed, 0 skipped, 0 leaked

zig-out/bin/fx.exe --version
    0.0.7
```

ReleaseSafe 第一次使用旧 cache 时出现 Zig 标准库 `math/iszero.zig` 加载错误；
使用新的项目内 cache 重跑通过，判断为旧 cache/toolchain 状态问题，而不是源码
编译错误。临时 cache 已删除。
