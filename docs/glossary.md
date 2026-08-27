# Glossary

| 术语 | 说明 |
| --- | --- |
| origin/main | Git 中名为 `origin` 的远程仓库的 `main` 分支本地跟踪引用。 |
| fetch | 从远程仓库获取提交和引用到本地，不自动修改当前工作分支文件。 |
| fast-forward-only | 仅允许当前分支直接向前移动到目标提交；若存在分叉则拒绝，避免自动创建合并提交。 |
| ahead/behind | 用于表示当前分支相对目标分支分别多出的提交数和落后的提交数。 |
| merge commit | 为合并两个分叉历史而产生的 Git 提交；本次因分支已一致而未创建。 |
| RDC / `.rdc` | RenderDoc 的截帧文件格式；保存可用于构造 API 对象并回放一帧的数据。 |
| replay API | RenderDoc 提供的回放接口；用于打开 capture、移动到 event、读取资源和 pipeline 状态，而不是启动原游戏。 |
| ReplayController | RenderDoc replay API 的主要控制对象；可以访问 actions、resources、structured data 和当前 event 的 GPU 状态。 |
| structured data | RenderDoc 对捕获 API 调用的结构化表示；包含函数名、参数、资源引用等信息，可作为代码生成输入。 |
| event / eventId | 捕获帧中的 API 调用或动作及其递增编号；回放控制器可移动到某个 event 后检查状态。 |
| replay IR | replay intermediate representation，回放中间表示；把 RenderDoc 的 API-specific 数据统一成资源、管线和命令节点，供不同后端生成代码。 |
| backend emitter | 后端代码生成器；把 replay IR 输出成 Vulkan、D3D12、D3D11 或 OpenGL 的 C++ 调用。 |
| golden image | 用于回归比较的基准画面；本方案用 RenderDoc replay 的最终 texture 与生成程序输出做像素差比较。 |
| readback | 将 GPU 资源复制回 CPU 可读内存的过程；本方案用它取得生成程序的最终颜色缓冲并写入 PNG。 |
| bindless | 不把资源限制在固定 descriptor 槽位的资源访问方式；通常需要额外处理索引表、GPU 地址和资源生命周期。 |
| pass pruning | 根据最终输出的依赖关系裁剪无影响的 render pass 或命令，缩小生成工程。 |
| shader blob | shader 的二进制/字节码数据；可直接嵌入生成工程，但不等于可读的原始 shader 源码。 |
| GFXR / `.gfxr` | GFXReconstruct 的 Vulkan/D3D12 capture 文件格式；记录 API 调用和回放所需数据。 |
| GFXReconstruct | LunarG 的图形 API capture/replay 工具集；Vulkan 侧提供 layer、回放、shader 提取、JSONL 转换和截图工具。 |
| gfxrecon-replay | GFXReconstruct 的回放程序；本方案用它从 `.gfxr` 生成 baseline/candidate 画面，并注入 shader 替换。 |
| gfxrecon-convert | 将 `.gfxr` 转换为 JSON Lines API 调用列表的工具；主要用于 agent 观察和分析，不默认保证可无损回写。 |
| gfxrecon-extract | 从 `.gfxr` 提取 SPIR-V shader 的工具；输出文件名包含 `CreateShaderModule` 的 handle。 |
| shader override | 回放时用候选 shader 替换 capture 中原 shader module，而不修改原始 capture。 |
| visual gate | 视觉门禁；候选只有在最终画面像素差满足阈值时才允许进入性能比较。 |
| GPU Duration | GPU 计时指标；RenderDoc 可通过 `EnumerateCounters`/`FetchCounters` 获取，用于按 event 或 pass 比较 GPU 时间。 |
| capture backend | 对一种 capture 格式负责加载、分析、回放和 patch 注入的适配层；本方案有 RenderDoc 和 GFXReconstruct 两个 backend。 |
| AVO | Agentic Variation Operators；让 agent 自主检查、规划、修改、执行和评估候选，并在长时间搜索中充当 variation operator 的架构。 |
| variation agent | 负责提出并实现一个候选优化方向的独立 fx 进程；它的输出必须经过统一 evaluator 验证。 |
| supervisor | 观察全局候选谱系、预算、失败和停滞，并决定何时派发下一批 variation agent 的控制器。 |
| lineage | 候选的父子关系和演化历史；用于恢复最佳版本、比较方向和向 agent 提供持久上下文。 |
| candidate ledger | 持久候选账本；记录候选 patch、状态、评估指标、日志和 parent id，支持长时间运行恢复。 |
| performance oracle | 性能评估器；对一个候选给出 GPU/CPU 时间、计数器或吞吐指标，作为搜索的可比较反馈。 |
| environment fingerprint | 运行环境指纹；记录 GPU、驱动、Vulkan runtime、replay tool 版本和关键参数，防止跨环境误比较。 |
| long-horizon loop | 长时域循环；允许 agent 跨越多个上下文和多轮候选持续工作，并通过持久状态恢复进度。 |
| SPIR-V | Vulkan 使用的中间 shader 字节码；本次通过 `glslc` 编译并由 `spirv-val` 校验，再交给 GFXR 做 shader replacement。 |
| replay-wall proxy | 回放墙钟代理指标；从启动 `gfxrecon-replay` 到进程退出的耗时，包含启动和管线创建开销，不能等同于 GPU duration。 |
| strict pixel equality | 严格逐像素相等；要求宽高、每个通道和每个像素完全一致，适合把画面作为不可改变的优化约束。 |
| target environment | shader 编译目标环境；例如 Vulkan 1.1/1.2，影响 SPIR-V 目标语义和驱动管线编译。 |
| pass manifest | pass 清单；描述候选希望改变的 render pass 状态或调度策略，本次 fixture 只验证接口和账本，不伪造真实 pass 改写。 |
| median / 中位数 | 将多次测量排序后取中间值的稳健统计量；本次用它降低单次进程启动抖动对候选排序的影响。 |
| POSIX API | Unix/Linux 风格的进程、文件描述符、终端和信号接口；Windows 原生实现不能直接假定存在相同的整数 fd、`pollfd` 或 `kill` 语义。 |
| UTF-16 | Windows 原生常用的宽字符编码；Windows 进程参数和环境块与 Unix 的 UTF-8 `char**` 表示不同。 |
| compatibility shim | 兼容适配层；把上层统一接口转换成当前操作系统的文件权限、终端句柄、进程控制或路径 API。 |
| file descriptor / fd | 操作系统中的文件或管道句柄抽象；Unix 通常是整数，Windows Zig runtime 中可能是句柄指针或不同类型，不能直接混用。 |
| Windows HANDLE | Windows 内核对象句柄；Zig 0.16 的 `std.process.Child.Id` 在 Windows 上就是进程 HANDLE，不能直接当作 PID 或用整数格式化。 |
| Win32 `GetProcessId` | 从进程 HANDLE 查询数值 PID 的 Windows API；fx 在持久化后台进程身份前用它完成句柄到 PID 的转换。 |
| `std.Io` | Zig 0.16 的新 I/O 抽象；通过 `Io`、`Io.File`、`Io.Dir` 和 vtable 统一文件、目录、流操作，替代新代码中直接调用部分旧 POSIX API。 |
| 编译期平台分支 | 使用 `if (comptime ...)` 让目标平台不支持的代码路径不参与该目标的类型检查、链接和运行。 |
| Winsock | Windows 的 socket API；其 poll 结构和消息标志与 POSIX `pollfd`、`MSG.NOSIGNAL` 不完全相同。 |
| 负能力（negative capability） | 明确记录某平台不支持某项能力，并返回稳定的 `Unsupported`/等价结果，而不是静默伪造成功。 |
| WTF-16 | Windows command line 使用的可逆宽字符表示；本轮从 PEB 读取原始 command line，避免把 Windows 参数误当作 Unix `argv`。 |
| PEB | Process Environment Block，Windows 进程环境块；其中包含启动参数、环境和标准句柄等进程级信息。 |
| ConDrv | Windows Console Driver；Zig 0.16 `std.Io` 在 Windows 上用于查询 console buffer 和终端属性的驱动接口。 |
| SSE | Server-Sent Events，服务器推送事件；本轮本地 gateway fixture 用它逐事件返回文本增量和完成状态。 |
| OpenAI-compatible endpoint | 遵循 OpenAI Chat Completions 请求/响应形状的服务入口；vLLM 常提供 `/v1` 入口，但它不自动等于 fx 当前的 AI Gateway 协议。 |
| positional reader | 通过显式 offset 读取文件、不改变共享文件游标的 I/O reader；Zig 0.16 Windows no-follow handle 路径在本轮触发了兼容性问题。 |
| streaming reader | 按当前文件游标顺序读取的 reader；本轮用它读取 context 文件以避开 Windows positional-read 状态机。 |
| `STATUS_CANCELLED` | Windows NTSTATUS 取消状态；本轮定位到它进入 Zig 0.16 `NtReadFile` cancellation state machine 的错误分支。 |
| `STATUS_INVALID_PARAMETER` | Windows NTSTATUS 参数无效状态；本轮错误的异步/同步 file handle 标记组合曾在顺序读取时产生该状态。 |
| invalid enum discriminant | 不属于当前 enum 成员集合的原始枚举值；旧 session 数据可能产生它，直接 `@tagName` 会触发 `unreachable`。 |
| `copyForwards` equal-length contract | Zig 0.16 内存复制 API 的约束：源和目标切片长度必须相等；删除文本时应只复制保留的尾部长度。 |
| Windows ACL | Windows Access Control List，控制文件/目录访问权限的安全描述；与 POSIX `0600/0700` mode 不是同一底层模型，fx 在 Windows 上只把 mode 检查作为兼容层语义。 |
| inode identity check | 打开文件前后比较文件身份标识；本轮用于在 Windows 以同步句柄打开后，确认它仍对应初始 no-follow stat 的 regular file。 |
| synchronous file handle | 可通过顺序 I/O 直接完成读写的文件句柄；本轮用它避开 Zig 0.16 Windows no-follow 打开路径产生的异步句柄状态不一致。 |
| sequential streaming reader | 只沿当前文件位置顺序消费数据的 reader；适合本轮有限大小的 session marker、sidecar 和全文读取，不触发 positional read 的 Windows cancellation 状态机。 |
| directory metadata barrier | 将文件 rename/删除等目录命名空间变更推进到稳定介质的同步边界；Windows/Zig 0.16 缺少便携的 POSIX `fsync(dir)` 等价物，因此当前实现是 best-effort。 |
| trace append serialization | trace 追加串行化；进程内用 Io mutex、文件 stat/seek/writer 组合追加记录，避免并发或 libc seek shim 覆盖相邻 trace 片段。 |
| protocol adapter | 协议适配器；在不改变两端核心实现的情况下，把一种请求/流式响应协议转换成另一种协议；本轮桥接 OpenAI Chat Completions 与 fx AI Gateway SSE。 |
| SSH local port forwarding | SSH 本地端口转发；把 Windows 本地监听端口安全映射到远端主机的 loopback 服务，本轮用于访问 4×V100 上的 vLLM。 |
| chat template / system-first | chat template 是模型服务把 messages 拼成模型输入的规则；system-first 表示 system message 必须位于 messages 首位，Qwen 服务会校验该顺序。 |
| WebGL | 浏览器的 GPU 图形 API；HTML 通过 canvas 和 WebGL/Three.js 绘制实时画面，本轮浏览器验证以可见 canvas、截图和控制台状态为证据。 |
| strict patch contract | 严格 patch 合约；候选必须提供匹配的 candidate id、优化方向、shader/pass 类型和受限的相对 asset 名称，才能进入物化和 replay。 |
| materializer | 物化器；把 agent 的 semantic proposal 转换成可供 replay 使用的 SPIR-V shader 或 pass 资产，本轮由 Vulkan fixture 执行。 |
| semantic patch digest | 语义 patch 摘要；从优化方向、类型和参数计算候选身份，忽略 candidate id、agent 名称及物化文件名，用于并发重复提案去重。 |
| run state / events | run state 是可恢复的最新快照；events 是按时间追加的调度事件流；两者与候选 ledger 分离，便于长时运行和故障审计。 |
| planner direction catalog | 高级模型生成的优化方向清单；每项包含假设、目标 pass/shader 和约束，供 supervisor 分配给独立 case。 |
| case_spec | 单个优化案例的结构化规格；绑定 case id、方向、假设和允许的修改边界，防止 agent 在同一轮无边界重复探索。 |
| independent variation workspace | 独立 variation 工作目录；每个 Qwen agent 只在自己的目录中产生 patch、日志和 trace，便于隔离、并发和恢复。 |
| Qwen identity summary | adapter 从 fx agent 输出中提取的有限身份字段，例如模型名、步数和工具调用状态；不包含原始模型文本或凭据。 |
| controlled retry budget | 受控重试预算；只为未生成 patch 或可诊断失败的 case 分配有限重试次数，不改变 case direction，也不把失败伪装成成功。 |
| GPU timestamp/counter evaluator | GPU 时间戳/硬件计数器评估器；在 GPU 执行边界采集 pass 或 event 的实际耗时和计数器，区别于包含进程启动开销的 replay-wall proxy。 |
| `finish_reason` | 流式模型响应的结束原因；`stop` 表示模型结束文本，`tool-calls` 表示模型请求执行工具。 |
| non-tool completion | 非工具完成；模型返回文本但 `tool_call_count=0`，没有执行 `write_file`，因此不能产出 agent 所需的 patch 文件。 |
| function-specific tool choice | 函数特定工具选择；在 OpenAI-compatible 请求中要求模型调用指定函数，例如 `write_file`，而不是仅要求调用任意工具。 |
| attempt workspace | 尝试工作区；一次 agent recovery attempt 的隔离目录，避免上一次生成物或会话状态污染下一次尝试。 |
| `invalid_tool_finish` | 工具结束状态不一致；响应中有 tool call 但结束原因仍是 `stop`，fx 可能拒绝该响应；bridge 需要将其规范化为 `tool-calls`。 |
| bounded output cap | 有界输出上限；在测试 bridge 处限制上游 `max_tokens`，防止非工具长文本耗尽单个 case 的等待预算。 |
| Mali Offline Compiler / MOC | Arm 提供的离线 shader 编译与性能报告工具；本轮用 `malioc.exe --vulkan --format json` 分析 SPIR-V，但它针对所选 Mali core，不是本机 NVIDIA 或远端 V100 的实测。 |
| offline shader guidance | 离线 shader guidance；由编译器静态报告产生的方向提示，例如 cycle、pipeline、寄存器和 occupancy，供 agent 选择假设，不替代运行时性能 oracle。 |
| pipeline cycle count | pipeline 周期估算；Mali 报告按 Arithmetic、Load/Store、Texture、Varying 等 pipeline 给出路径周期，表示编译器模型下的 shader 成本。 |
| bound pipeline | bound pipeline；在一条 shader 路径上可能成为瓶颈的 Mali pipeline，适合提示 agent 优先尝试减少对应类别的工作。 |
| SPIR-V execution model | SPIR-V entry point 的 shader stage 标识，例如 Vertex、Fragment、GLCompute；本轮从 `OpEntryPoint` 读取它，以支持无 `.vert/.frag` 扩展名的 GFXR `sh*` 文件。 |
| GFXR measurement-file | GFXReconstruct replay 的 frame measurement JSON；可包含 frame duration 和 FPS，但当前回放器不提供 per-pass hardware counter，因此必须标注 measurement kind。 |
| GPU-only duration | 只表示 GPU 执行区间的耗时；GFXR frame duration 不是该指标，因为它还可能包含 replay CPU、驱动提交和同步开销。 |
| completion boundary | 完成边界；例如 GFXR 的 `--flush-measurement-range` 在测量区间起止等待 GPU work 完成，能保证区间覆盖已完成的 GPU 工作，但不会消除 CPU/driver 时间。 |
| metric source / measurement kind | 性能数字的来源和真实性分类；账本同时记录它们，避免把 Mali 离线周期、GFXR frame duration 和真实 GPU counter 混为同一指标。 |
| working tree | Git 当前 checkout 中的源码、未提交修改和未跟踪文件集合；本轮按它相对 `origin/main` 的差异做分类，不假定所有修改都是本轮新建。 |
| generated experiment artifact | 实验生成物；例如 `.e2e/` 下的 capture、截图、SPIR-V、ledger、trace 和 report，属于可复现实验证据，不是生产源码。 |
| classification index | 分类索引；用主题入口把源码、脚本、fixture、第三方工具和实验记录关联起来，同时保留原始时间戳文档。 |
| canonical upstream | canonical upstream；项目声明的权威上游仓库，本轮为 `vercel-labs/fx`，用于判断本地 fork 是否落后。 |
| focused Windows smoke root | focused Windows smoke root；面向 Windows 可运行能力的独立 Zig 测试入口，通过真实构建二进制验证公开命令，不实例化平台不支持的 Unix 测试夹具。 |
| POSIX full registry | POSIX full registry；上游为 Unix 进程、PTY、poll 和 signal 语义准备的全量测试注册表，不能直接等价移植到 Windows。 |
| test root module | test root module；Zig 测试编译的根模块，决定哪些源文件和测试声明被实例化；本轮 Windows 与 POSIX 使用不同根模块。 |
