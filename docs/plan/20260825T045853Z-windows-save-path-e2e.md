# Windows 保存路径 E2E 计划

## 目标

验证默认保存模式不再触发 Windows 文件读取崩溃，并能取回刚保存的会话与 trace。

## 验证矩阵

| 检查 | 预期 |
| --- | --- |
| Debug 原生构建 | 成功 |
| ReleaseFast 原生构建 | 成功 |
| `ask --no-save` + SSE fixture | 输出 fixture 文本，退出码 0 |
| `ask --json` 默认保存 + 中文 Star Wars HTML prompt | 输出 fixture 文本，退出码 0，产生 session |
| `sessions --json` | 能列出 1 条会话，标题与 prompt 一致 |
| `session <id> --json` | 能 replay 出 history 和 execution |
| `FX_TRACE_LOG` | 生成可读的 agent/gateway/history/session trace |
| `doctor` / `status --json` | CLI 能在 Windows 完成健康检查 |

## 实施顺序

1. 修复普通文件打开与 usage recovery marker 的顺序读取。
2. 删除定位期间的 stdout 标记，保留正式 debug trace。
3. 构建 Debug 与 ReleaseFast。
4. 运行 no-save、save、sessions、session detail 和 trace 验证。
5. 进行敏感信息扫描，并记录完整测试套件中仍未迁移的 Windows test-only 分支。

## 当前状态

步骤 1–4 已完成并通过本轮 fixture E2E；步骤 5 在最终审计阶段。真实 Qwen/vLLM 连接仍需要把 vLLM 的 OpenAI-compatible `/v1` 协议接到 fx 当前的 AI Gateway SSE provider，不能用 fixture 结果代替。
