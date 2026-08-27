# 上游更新与 Windows 测试研究记录

## 范围

本轮目标是将 `fx-win` 从 `vercel-labs/fx` 的 canonical `main` 更新到最新提交，检查本地 Windows 适配是否需要与上游重合并，并在当前 Windows 主机完成构建和测试验证。

## 环境判断

动作前确认：

| 项目 | 结果 | 判断 |
| --- | --- | --- |
| CPU | AMD Ryzen 9 9950X 16-Core Processor，16 核 32 线程，最高 4300 MHz | 足以进行 Zig 编译和本地测试 |
| GPU | NVIDIA GeForce RTX 4080 SUPER，16 GiB，Compute Capability 8.9 | 对 fx 的 CLI 编译测试不是硬性依赖；主机环境正常 |
| OS | Windows | 目标平台与本轮验证一致 |
| Zig | 0.16.0 | 与项目要求一致 |
| CMake / Ninja | 3.29.2 / 1.12.0 | 可用于相关构建辅助流程 |
| Vulkan SDK | 1.4.341.1 | 保持已有图形实验环境可用 |

本轮没有安装软件，也没有写入全局依赖目录；Zig 缓存使用项目内 `.zig-cache` 和 `.zig-cache/global`。

## 远程与分叉

现有 `origin` 是 `https://github.com/mobius/fx-local-vllm.git`，canonical 上游是 `https://github.com/vercel-labs/fx.git`。本地新增 `upstream` 远程并执行 fetch，未修改任何远程仓库。

共同基线为 `fc124be4f4c67ac4c1b7a0b586a3831e93b463d6`。更新前本地分支相对 `upstream/main` 为 `ahead 2 / behind 512`；上游最新为 `139a77a`，包含终端超时取消、子进程清理、MCP 和 provider 等近期修复。

## 需保留的本地适配

合并预览发现 7 个冲突点，主要集中在上游重构后的执行、重放、I/O、技能和工具运行时：

* 保留上游新的前台终止状态机，同时把 Windows 进程 ID 通过 fx 的 `currentProcessId()` 兼容层取得。
* 采用上游新的 replay spool 随机命名和清理逻辑。
* 保留 Windows 文件打开后的 inode identity check，避免 Zig 0.16 no-follow handle 读取问题。
* 保留 Windows `std_options_FilePermissions` 兼容 shim，并采用上游版本号 `0.0.6`。
* 接受上游删除已经不再被引用的旧 `devbox` 实现。

## 初始测试发现

直接让上游的完整 root test registry 在 Windows 编译，会实例化 `fork`、`pollfd`、Unix signal、PTY 以及整数型 POSIX fd/pid 测试夹具。它们不是生产代码失败，而是平台不支持的测试假设。Windows 生产构建已经先通过。
