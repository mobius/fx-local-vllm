# Windows + 真实 Qwen E2E 实现记录

## 代码与测试改动

- `src/core/workspace/pathing.zig`：增加 Windows `/`/`\\` 分隔符、盘符根和 UNC 根处理；bounded resolver、symlink resolution、normalization、parent directory creation 和 `pathInside` 均按 Windows 语义分支。
- `src/core/skills/skill_contract.zig`：skill metadata 前缀读取改为 streaming reader，避免 Windows positional-read 状态机异常。
- `src/core/skills/skill_runtime.zig`：Windows 上对初始 no-follow stat 后的同步打开文件执行 regular-file 与 identity 校验。
- `tests/fixtures/openai_gateway_bridge.py`：测试专用协议适配器，把 OpenAI/vLLM Chat Completions streaming 转为 fx AI Gateway SSE；不改变生产默认 transport。
- `.e2e/real-qwen-game6-20260825/`：保存真实模型生成的 HTML 和 184 行 JSONL trace。

## 验证命令与结果

- `zig build --global-cache-dir .e2e/zig-global-cache -Doptimize=Debug -freference-trace=16`：通过。
- `zig build --global-cache-dir .e2e/zig-global-cache -Doptimize=ReleaseFast -freference-trace=16`：通过。
- `fx ask --json --no-save --yolo -- "Reply with the single word OK."`：ReleaseFast 真实 Qwen 返回 `OK`，模型名为 `Qwen3.8-27B-INT4`。
- 真实生成 prompt：要求先调用 `write_file` 写入最小 3D 星球大战风格 HTML；结果为 9649 字节，工具调用成功，agent step 为 1。
- HTML 静态检查：包含 `DOCTYPE html`、Three.js 标记、`WebGLRenderer`、`requestAnimationFrame`，未包含 token-like 值。
- 浏览器运行：画布 1280×720，页面标题正确，截图可见星空/行星/字幕，控制台无 error/warning。

## 产物

- HTML：`.e2e/real-qwen-game6-20260825/star-war-3d.html`
- trace：`.e2e/real-qwen-game6-20260825/trace.jsonl`
- HTML SHA256：`2009AEE573E5D63751E07EC0BE4254A2FC0605EF60803076EEC88E7F83DE3479`
- trace SHA256：`37BAB81229511660AA9FE53E245C780298C405D310725806456234B3DF7C7CA2`

## 清理

验证完成后应停止本轮使用的本地 HTTP 服务、协议桥、SSH tunnel 和旧 fixture；不删除用户已有源码或文档改动。
