# fx-win 上游合并架构记录

```text
upstream/main dd7179f3
        |
        v
fx-win composition root  ── Windows compatibility shim
        |
        +── shell-managed execution / process identity
        +── managed terminal host startup/recovery
        +── MCP/ACP/runtime updates
        +── Windows focused test root
        v
zig-out/bin/fx.exe 0.0.7
```

上游的新 shell/process/terminal 生命周期是产品主线，Windows 适配只在平台能力
不存在时采用明确的 unsupported 分支。测试层继续把 POSIX-only benchmark 和
Windows product smoke 分开：生产图完整编译，默认 gate 验证真实 Windows 二进制，
不能运行的 Unix benchmark 保留为显式步骤并记录原因。
