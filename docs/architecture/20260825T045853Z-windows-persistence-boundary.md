# Windows 持久化边界架构

## 文件读取边界

```text
untrusted path
    │
    ├─ no-follow stat: regular file / nlink=1 / private shape
    │
    ├─ Windows synchronous open (follow allowed only after stat)
    │       │
    │       └─ opened inode == initial inode
    │
    └─ sequential streaming reader
```

Windows 的 `follow_symlinks=false` 打开路径在 Zig 0.16 中可能产生与 metadata 不一致的 threaded Io handle。直接对该句柄做 positional/seek 访问会把取消状态机推进到 `PENDING` 不可达分支。架构上把“路径安全检查”和“可读句柄获取”分开，并用 inode 比较连接两者。

## 持久化提交边界

```text
usage snapshot
  → recovery marker (durable replace)
  → event/checkpoint append
  → usage marker finalize
  → session listing / session detail replay
```

目录同步在 Windows 上是 best-effort，因为 Zig 0.16 的目录 metadata barrier 仍不提供与 POSIX `fsync(dir)` 等价的便携接口；文件内容同步、原子替换和身份校验仍保留。

## Trace 边界

`debug_trace` 在进程内用 Io mutex 串行化记录，文件追加通过同一个 Zig Io 文件接口完成。trace 是诊断证据，不是会话事实源；会话事实仍来自 events/checkpoint/sidecar/replay。
