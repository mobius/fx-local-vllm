# Windows runtime I/O 兼容架构

## 启动链路

```text
Windows PEB command line
        |
        v
fx CLI parser -> early std.Io.Threaded -> app lifecycle
        |
        v
workspace stat -> context provider -> synchronous file read
        |
        v
gateway request -> SSE event consumer -> JSON result
```

## 文件读取策略

工作区规则文件首先用 no-follow stat 判断类型。普通文件在 Windows 上使用同步打开，避免 Zig 0.16 将 no-follow handle 建为异步却返回同步 metadata 的不匹配；打开后比较文件 identity，再通过 streaming reader 一次读入受上限约束的内容，最后做 UTF-8 校验和安全截断。符号链接仍需经过 authority/canonical target 检查。

## 协议边界

fx 内部当前的 gateway transport 是 Vercel AI Gateway 风格协议，输入使用 `prompt`/`toolChoice`，输出使用事件流。vLLM 的 `/v1` 是 OpenAI-compatible API，输入通常是 `messages`，输出是 Chat Completions SSE。两者之间必须有显式 adapter 或 bridge，Windows runtime 修复本身不会自动完成协议转换。

## 失败隔离

编译期平台分支隔离 Unix-only 类型；运行期对未支持的 Windows 能力返回稳定错误。真实模型请求只在 transport adapter 验证完成后纳入远端 E2E，避免把本地 fixture 的成功误当成远端模型结果。
