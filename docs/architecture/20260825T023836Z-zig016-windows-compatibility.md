# Windows 平台边界架构

```text
统一 fx 逻辑
    |
    +-- shared/io.zig
    |      +-- std.Io 文件/目录/流
    |      +-- Windows HANDLE -> numeric PID
    |      +-- Windows realPath
    |
    +-- 可选 Unix 能力
           +-- terminal host      -> 编译期不可用
           +-- POSIX signal/kill  -> 运行时 Unsupported
           +-- Unix socket timeout -> Windows no-op
           +-- auto-upgrade       -> Windows no-op/fetch_failed
```

关键原则是：平台差异集中在小型 compatibility shim 和编译期分支；上层 agent、会话、trace 和普通 HTTP 请求仍使用统一接口。对于 Windows 不存在的安全语义，不把整数 fd 或 Unix 权限位强行映射成“等价支持”。
