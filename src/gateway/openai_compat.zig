const std = @import("std");

const debug_trace = @import("../core/shared/debug_trace.zig");
const io_mod = @import("../core/shared/io.zig");
const types = @import("../core/shared/types.zig");

const protocol_env = "FX_GATEWAY_PROTOCOL";
const allow_private_env = "FX_GATEWAY_ALLOW_PRIVATE_HTTP";
const default_max_tokens: u32 = 8192;
const qwen38_max_tokens: u32 = 16384;
const ioa_max_tokens: u32 = 16384;

pub const openai_models_path = "/v1/models";

pub fn protocolEnabled() bool {
    const raw = io_mod.getenv(protocol_env) orelse return false;
    return std.ascii.eqlIgnoreCase(raw, "openai") or
        std.ascii.eqlIgnoreCase(raw, "openai-compatible");
}

pub fn looksLikeOpenAiChatUrl(chat_url: []const u8) bool {
    return std.mem.indexOf(u8, chat_url, "/chat/completions") != null;
}

pub fn shouldUseOpenAiWire(chat_url: []const u8) bool {
    return protocolEnabled() or looksLikeOpenAiChatUrl(chat_url);
}

pub fn allowPrivateHttp() bool {
    const raw = io_mod.getenv(allow_private_env) orelse return false;
    return std.mem.eql(u8, raw, "1") or std.ascii.eqlIgnoreCase(raw, "true");
}

pub fn isLoopbackHttpUrl(url: []const u8) bool {
    const uri = std.Uri.parse(url) catch return false;
    if (!std.ascii.eqlIgnoreCase(uri.scheme, "http")) return false;
    if (uri.user != null or uri.password != null) return false;
    const host_component = uri.host orelse return false;
    var host_buf: [std.Io.net.HostName.max_len]u8 = undefined;
    const host = host_component.toRaw(&host_buf) catch return false;
    return std.mem.eql(u8, host, "127.0.0.1") or
        std.ascii.eqlIgnoreCase(host, "localhost") or
        std.mem.eql(u8, host, "[::1]");
}

pub fn isPrivateLanHttpUrl(url: []const u8) bool {
    const uri = std.Uri.parse(url) catch return false;
    if (!std.ascii.eqlIgnoreCase(uri.scheme, "http")) return false;
    if (uri.user != null or uri.password != null) return false;
    const host_component = uri.host orelse return false;
    var host_buf: [std.Io.net.HostName.max_len]u8 = undefined;
    const host = host_component.toRaw(&host_buf) catch return false;
    return isRfc1918Host(host);
}

pub fn isHttpsUrl(url: []const u8) bool {
    const uri = std.Uri.parse(url) catch return false;
    if (!std.ascii.eqlIgnoreCase(uri.scheme, "https")) return false;
    if (uri.user != null or uri.password != null) return false;
    return uri.host != null;
}

pub fn isAllowedGatewayUrl(url: []const u8) bool {
    if (isLoopbackHttpUrl(url)) return true;
    if (!protocolEnabled()) return false;
    if (isHttpsUrl(url)) return true;
    return allowPrivateHttp() and isPrivateLanHttpUrl(url);
}

pub fn openaiModelsPath() []const u8 {
    const base = io_mod.getenv("FX_GATEWAY_BASE_URL") orelse return openai_models_path;
    const trimmed = std.mem.trimEnd(u8, base, "/");
    if (std.mem.endsWith(u8, trimmed, "/v1") or std.mem.endsWith(u8, trimmed, "/v2"))
        return "/models";
    return openai_models_path;
}

pub fn derivedChatUrl(base: []const u8) []const u8 {
    const trimmed = std.mem.trimEnd(u8, base, "/");
    const suffix = if (std.mem.endsWith(u8, trimmed, "/v1") or std.mem.endsWith(u8, trimmed, "/v2"))
        "/chat/completions"
    else
        "/v1/chat/completions";
    const n = (std.fmt.bufPrint(&derived_chat_url_buf, "{s}{s}", .{ trimmed, suffix }) catch {
        return trimmed;
    }).len;
    derived_chat_url_len = n;
    return derived_chat_url_buf[0..derived_chat_url_len];
}

var derived_chat_url_buf: [512]u8 = undefined;
var derived_chat_url_len: usize = 0;

fn isRfc1918Host(host: []const u8) bool {
    var it = std.mem.splitScalar(u8, host, '.');
    const a_s = it.next() orelse return false;
    const b_s = it.next() orelse return false;
    const c_s = it.next() orelse return false;
    const d_s = it.next() orelse return false;
    if (it.next() != null) return false;
    const a = std.fmt.parseInt(u8, a_s, 10) catch return false;
    const b = std.fmt.parseInt(u8, b_s, 10) catch return false;
    _ = std.fmt.parseInt(u8, c_s, 10) catch return false;
    _ = std.fmt.parseInt(u8, d_s, 10) catch return false;
    if (a == 10) return true;
    if (a == 192 and b == 168) return true;
    if (a == 172 and b >= 16 and b <= 31) return true;
    return false;
}

/// Rewrite Vercel AI Gateway `{prompt, tools, maxOutputTokens}` JSON into
/// OpenAI-compatible `{messages, tools, max_tokens, stream}`.
pub fn rewriteVercelBodyToOpenAi(alloc: std.mem.Allocator, body: []const u8) ![]u8 {
    return rewriteVercelBodyToOpenAiWithModel(alloc, body, null);
}

pub fn rewriteVercelBodyToOpenAiWithModel(
    alloc: std.mem.Allocator,
    body: []const u8,
    model_override: ?[]const u8,
) ![]u8 {
    const parsed = std.json.parseFromSlice(std.json.Value, alloc, body, .{}) catch
        return alloc.dupe(u8, body);
    defer parsed.deinit();
    if (parsed.value != .object) return alloc.dupe(u8, body);
    const root = parsed.value.object;

    var out: std.Io.Writer.Allocating = .init(alloc);
    errdefer out.deinit();
    try out.writer.writeByte('{');
    var wrote_field = false;

    const model_name: ?[]const u8 = if (model_override) |m|
        m
    else if (root.get("model")) |model|
        if (model == .string) model.string else null
    else
        null;
    if (model_name) |model| {
        try writeComma(&out.writer, &wrote_field);
        try out.writer.writeAll("\"model\":");
        try std.json.Stringify.value(model, .{}, &out.writer);
    }

    const prompt = root.get("prompt") orelse root.get("messages");
    try writeComma(&out.writer, &wrote_field);
    try out.writer.writeAll("\"messages\":");
    if (prompt) |msgs| {
        try writeOpenAiMessages(&out.writer, msgs);
    } else {
        try out.writer.writeAll("[]");
    }

    if (root.get("tools")) |tools| {
        try writeComma(&out.writer, &wrote_field);
        try out.writer.writeAll("\"tools\":");
        try writeOpenAiTools(&out.writer, tools);
    }

    const qwen = if (model_name) |m| isQwenFamily(m) else false;
    const ioa = if (model_name) |m| isIoaFamily(m) else false;
    var max_tokens: u32 = if (qwen) qwen38_max_tokens else if (ioa) ioa_max_tokens else default_max_tokens;
    if (envU32("FX_MAX_TOKENS")) |n| {
        max_tokens = n;
    } else if (!qwen and !ioa) {
        if (root.get("maxOutputTokens")) |v| {
            if (v == .integer and v.integer > 0) max_tokens = @intCast(@min(v.integer, default_max_tokens));
        } else if (root.get("max_tokens")) |v| {
            if (v == .integer and v.integer > 0) max_tokens = @intCast(@min(v.integer, default_max_tokens));
        }
    }
    try writeComma(&out.writer, &wrote_field);
    try out.writer.print("\"max_tokens\":{d}", .{max_tokens});

    try writeComma(&out.writer, &wrote_field);
    try out.writer.writeAll("\"stream\":true");

    if (ioa) {
        var effort: []const u8 = ioaDefaultEffort(model_name.?);
        if (io_mod.getenv("FX_REASONING_EFFORT")) |raw| {
            if (raw.len > 0) effort = raw;
        }
        try writeComma(&out.writer, &wrote_field);
        try out.writer.writeAll("\"reasoning_effort\":");
        try std.json.Stringify.value(effort, .{}, &out.writer);
    } else if (qwen) {
        const raw_effort = blk: {
            if (io_mod.getenv("FX_REASONING_EFFORT")) |raw| {
                if (raw.len > 0) break :blk raw;
            }
            if (root.get("reasoning")) |r| {
                if (r == .string and r.string.len > 0) break :blk r.string;
            }
            break :blk "medium";
        };
        const thinking = qwenThinkingEnabled(raw_effort);
        const effort = mapQwenReasoningEffort(raw_effort);
        try writeComma(&out.writer, &wrote_field);
        if (thinking) {
            try out.writer.writeAll(
                \\"temperature":1.0,"top_p":0.95,"presence_penalty":0.0,"top_k":20,"chat_template_kwargs":{"enable_thinking":true,"preserve_thinking":true},"reasoning_effort":
            );
            try std.json.Stringify.value(effort, .{}, &out.writer);
        } else {
            try out.writer.writeAll(
                \\"temperature":1.0,"top_p":0.95,"presence_penalty":1.5,"top_k":20,"chat_template_kwargs":{"enable_thinking":false,"preserve_thinking":false}
            );
        }
    }

    try out.writer.writeByte('}');
    const slice = try out.toOwnedSlice();
    debug_trace.logf(
        "stream",
        "openai rewrite bytes={d} has_prompt={s} prefix={s}",
        .{
            slice.len,
            if (std.mem.indexOf(u8, slice, "\"prompt\":") != null) "yes" else "no",
            slice[0..@min(slice.len, 160)],
        },
    );
    return slice;
}

fn isIoaFamily(model: []const u8) bool {
    return std.mem.indexOf(u8, model, "deepseek-v4-") != null and
        std.mem.endsWith(u8, model, "-ioa");
}

fn ioaDefaultEffort(model: []const u8) []const u8 {
    if (std.mem.indexOf(u8, model, "pro") != null) return "low";
    return "max";
}

fn qwenThinkingEnabled(raw: []const u8) bool {
    return !std.ascii.eqlIgnoreCase(raw, "off") and
        !std.ascii.eqlIgnoreCase(raw, "none") and
        !std.ascii.eqlIgnoreCase(raw, "false") and
        !std.ascii.eqlIgnoreCase(raw, "0");
}

fn mapQwenReasoningEffort(raw: []const u8) []const u8 {
    if (std.ascii.eqlIgnoreCase(raw, "low")) return "low";
    if (std.ascii.eqlIgnoreCase(raw, "xhigh") or
        std.ascii.eqlIgnoreCase(raw, "high") or
        std.ascii.eqlIgnoreCase(raw, "max"))
        return "xhigh";
    return "medium";
}

fn isQwenFamily(model: []const u8) bool {
    return std.mem.indexOf(u8, model, "Qwen") != null or
        std.mem.indexOf(u8, model, "qwen") != null or
        std.mem.indexOf(u8, model, "Huihui") != null or
        std.mem.indexOf(u8, model, "huihui") != null;
}

fn envU32(name: []const u8) ?u32 {
    const raw = io_mod.getenv(name) orelse return null;
    return std.fmt.parseInt(u32, raw, 10) catch null;
}

fn writeComma(writer: *std.Io.Writer, wrote_field: *bool) !void {
    if (wrote_field.*) try writer.writeByte(',');
    wrote_field.* = true;
}

fn writeOpenAiMessages(writer: *std.Io.Writer, msgs: std.json.Value) !void {
    if (msgs != .array) {
        try writer.writeAll("[]");
        return;
    }
    try writer.writeByte('[');
    var first = true;
    var pending_system: ?std.json.Value = null;
    for (msgs.array.items) |item| {
        if (item != .object) continue;
        const role_v = item.object.get("role") orelse continue;
        if (role_v != .string) continue;
        const role = role_v.string;
        if (std.mem.eql(u8, role, "system") or std.mem.eql(u8, role, "developer")) {
            pending_system = item;
            continue;
        }
        if (pending_system) |sys| {
            if (!first) try writer.writeByte(',');
            first = false;
            try writeOpenAiMessage(writer, sys, "system");
            pending_system = null;
        }
        if (!first) try writer.writeByte(',');
        first = false;
        const mapped = if (std.mem.eql(u8, role, "tool")) "tool" else role;
        try writeOpenAiMessage(writer, item, mapped);
    }
    if (pending_system) |sys| {
        if (!first) try writer.writeByte(',');
        try writeOpenAiMessage(writer, sys, "system");
    }
    try writer.writeByte(']');
}

fn writeOpenAiMessage(writer: *std.Io.Writer, item: std.json.Value, role: []const u8) !void {
    try writer.writeAll("{\"role\":");
    try std.json.Stringify.value(role, .{}, writer);
    try writer.writeAll(",\"content\":");
    try writeFlattenedContent(writer, item.object.get("content"));
    if (item.object.get("tool_calls")) |calls| {
        try writer.writeAll(",\"tool_calls\":");
        try std.json.Stringify.value(calls, .{}, writer);
    }
    if (item.object.get("tool_call_id")) |id| {
        try writer.writeAll(",\"tool_call_id\":");
        try std.json.Stringify.value(id, .{}, writer);
    }
    try writer.writeByte('}');
}

fn writeFlattenedContent(writer: *std.Io.Writer, content: ?std.json.Value) !void {
    const value = content orelse {
        try writer.writeAll("\"\"");
        return;
    };
    switch (value) {
        .string => |s| try std.json.Stringify.value(s, .{}, writer),
        .array => |arr| {
            var buf: std.Io.Writer.Allocating = .init(std.heap.page_allocator);
            defer buf.deinit();
            for (arr.items) |part| {
                if (part != .object) continue;
                if (part.object.get("text")) |t| {
                    if (t == .string) try buf.writer.writeAll(t.string);
                }
            }
            try std.json.Stringify.value(buf.written(), .{}, writer);
        },
        else => try writer.writeAll("\"\""),
    }
}

fn writeOpenAiTools(writer: *std.Io.Writer, tools: std.json.Value) !void {
    if (tools != .array) {
        try writer.writeAll("[]");
        return;
    }
    try writer.writeByte('[');
    var first = true;
    for (tools.array.items) |tool| {
        if (tool != .object) continue;
        if (!first) try writer.writeByte(',');
        first = false;
        if (tool.object.get("function") != null) {
            try std.json.Stringify.value(tool, .{}, writer);
            continue;
        }
        const name = if (tool.object.get("name")) |n| (if (n == .string) n.string else "tool") else "tool";
        const desc = if (tool.object.get("description")) |d| (if (d == .string) d.string else "") else "";
        try writer.writeAll("{\"type\":\"function\",\"function\":{\"name\":");
        try std.json.Stringify.value(name, .{}, writer);
        try writer.writeAll(",\"description\":");
        try std.json.Stringify.value(desc, .{}, writer);
        try writer.writeAll(",\"parameters\":");
        if (tool.object.get("inputSchema") orelse tool.object.get("parameters")) |params| {
            try std.json.Stringify.value(params, .{}, writer);
        } else {
            try writer.writeAll("{\"type\":\"object\",\"properties\":{}}");
        }
        try writer.writeAll("}}");
    }
    try writer.writeByte(']');
}

const ToolAcc = struct {
    used: bool = false,
    id: std.ArrayListUnmanaged(u8) = .empty,
    name: std.ArrayListUnmanaged(u8) = .empty,
    args: std.ArrayListUnmanaged(u8) = .empty,

    fn deinit(self: *ToolAcc, alloc: std.mem.Allocator) void {
        self.id.deinit(alloc);
        self.name.deinit(alloc);
        self.args.deinit(alloc);
    }
};

fn findFreeToolAcc(accs: []ToolAcc) ?*ToolAcc {
    for (accs) |*acc| {
        if (!acc.used) return acc;
    }
    return null;
}

fn applyToolCallDelta(
    alloc: std.mem.Allocator,
    accs: []ToolAcc,
    tc: std.json.Value,
) !void {
    var idx: usize = 0;
    if (tc.object.get("index")) |iv| {
        if (iv == .integer and iv.integer >= 0) {
            idx = @min(@as(usize, @intCast(iv.integer)), accs.len - 1);
        }
    }
    const id_s: []const u8 = if (tc.object.get("id")) |id_v|
        if (id_v == .string) id_v.string else ""
    else
        "";

    var acc: *ToolAcc = &accs[idx];
    if (id_s.len > 0) {
        var found: ?*ToolAcc = null;
        for (accs) |*candidate| {
            if (candidate.used and std.mem.eql(u8, candidate.id.items, id_s)) {
                found = candidate;
                break;
            }
        }
        if (found) |existing| {
            acc = existing;
        } else {
            if (acc.used and acc.id.items.len > 0 and !std.mem.eql(u8, acc.id.items, id_s)) {
                acc = findFreeToolAcc(accs) orelse acc;
            }
            acc.used = true;
            acc.id.clearRetainingCapacity();
            try acc.id.appendSlice(alloc, id_s);
        }
    } else {
        acc.used = true;
    }

    const fn_v = tc.object.get("function") orelse return;
    if (fn_v != .object) return;
    if (fn_v.object.get("name")) |n| {
        if (n == .string and n.string.len > 0) {
            acc.name.clearRetainingCapacity();
            try acc.name.appendSlice(alloc, n.string);
        }
    }
    if (fn_v.object.get("arguments")) |a| {
        if (a == .string and a.string.len > 0) {
            if (a.string[0] == '{' and acc.args.items.len > 0) {
                if (try types.ToolArgumentIntegrity.classifySerialized(alloc, acc.args.items) == .valid) {
                    const next = findFreeToolAcc(accs) orelse acc;
                    if (next != acc) {
                        next.used = true;
                        if (acc.name.items.len > 0 and next.name.items.len == 0) {
                            try next.name.appendSlice(alloc, acc.name.items);
                        }
                        acc = next;
                    }
                }
            }
            try acc.args.appendSlice(alloc, a.string);
        }
    }
}

pub const StreamCallback = *const fn (*anyopaque, []const u8) void;

/// Parse OpenAI `chat.completion.chunk` SSE into a GatewayCompletion.
pub fn consumeOpenAiSse(
    alloc: std.mem.Allocator,
    reader: *std.Io.Reader,
    callback_ctx: *anyopaque,
    on_content_chunk: StreamCallback,
    cancel_flag: *std.atomic.Value(bool),
) !types.GatewayCompletion {
    var content_buf: std.ArrayListUnmanaged(u8) = .empty;
    errdefer content_buf.deinit(alloc);
    var tool_calls: std.ArrayListUnmanaged(types.ToolCall) = .empty;
    errdefer {
        for (tool_calls.items) |call| {
            alloc.free(call.id);
            alloc.free(call.name);
            alloc.free(call.arguments_json);
        }
        tool_calls.deinit(alloc);
    }

    var pending_line: std.ArrayListUnmanaged(u8) = .empty;
    defer pending_line.deinit(alloc);
    var finish_reason: ?types.ProviderFinishReason = null;
    var input_tokens: ?u64 = null;
    var output_tokens: ?u64 = null;

    const MaxToolAcc = 8;
    var accs: [MaxToolAcc]ToolAcc = [_]ToolAcc{.{}} ** MaxToolAcc;
    defer for (&accs) |*acc| acc.deinit(alloc);

    while (true) {
        if (cancel_flag.load(.seq_cst)) return error.Cancelled;
        const line = readSseLine(alloc, reader, &pending_line) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        } orelse break;
        defer if (pending_line.items.len > 0) pending_line.clearRetainingCapacity();

        const trimmed = std.mem.trim(u8, line, " \r");
        if (trimmed.len == 0) continue;
        if (!std.mem.startsWith(u8, trimmed, "data:")) continue;
        const data = std.mem.trim(u8, trimmed["data:".len..], " ");
        if (std.mem.eql(u8, data, "[DONE]")) break;
        const parsed = std.json.parseFromSlice(std.json.Value, alloc, data, .{}) catch continue;
        defer parsed.deinit();
        if (parsed.value != .object) continue;
        const obj = parsed.value.object;

        if (obj.get("usage")) |usage| {
            if (usage == .object) {
                if (usage.object.get("prompt_tokens")) |v| {
                    if (v == .integer and v.integer >= 0) input_tokens = @intCast(v.integer);
                }
                if (usage.object.get("completion_tokens")) |v| {
                    if (v == .integer and v.integer >= 0) output_tokens = @intCast(v.integer);
                }
            }
        }

        const choices = obj.get("choices") orelse continue;
        if (choices != .array or choices.array.items.len == 0) continue;
        const choice = choices.array.items[0];
        if (choice != .object) continue;

        if (choice.object.get("finish_reason")) |fr| {
            if (fr == .string and fr.string.len > 0) {
                finish_reason = types.ProviderFinishReason.parse_legacy(fr.string) orelse .stop;
            }
        }

        const delta = choice.object.get("delta") orelse choice.object.get("message") orelse continue;
        if (delta != .object) continue;

        if (delta.object.get("content")) |c| {
            if (c == .string and c.string.len > 0) {
                try content_buf.appendSlice(alloc, c.string);
                on_content_chunk(callback_ctx, c.string);
            }
        }
        if (delta.object.get("reasoning_content") orelse delta.object.get("reasoning")) |r| {
            _ = r;
        }
        if (delta.object.get("tool_calls")) |tcs| {
            if (tcs == .array) {
                for (tcs.array.items) |tc| {
                    if (tc != .object) continue;
                    try applyToolCallDelta(alloc, &accs, tc);
                }
            }
        }
    }

    for (&accs, 0..) |*acc, i| {
        if (!acc.used or acc.name.items.len == 0) continue;
        var args: []const u8 = acc.args.items;
        if (args.len == 0) args = "{}";
        if (try types.ToolArgumentIntegrity.classifySerialized(alloc, args) == .malformed_json) {
            args = "{}";
        }
        var id_buf: [16]u8 = undefined;
        const id = if (acc.id.items.len > 0) acc.id.items else std.fmt.bufPrint(&id_buf, "call_{d}", .{i}) catch "call_0";
        try tool_calls.append(alloc, .{
            .id = try alloc.dupe(u8, id),
            .name = try alloc.dupe(u8, acc.name.items),
            .arguments_json = try alloc.dupe(u8, args),
        });
        if (finish_reason == null or finish_reason == .stop) finish_reason = .tool_calls;
    }

    var completion: types.GatewayCompletion = .{
        .finish_reason = finish_reason orelse .stop,
        .usage = .{
            .input_tokens = input_tokens,
            .output_tokens = output_tokens,
        },
    };
    if (content_buf.items.len > 0) {
        completion.content = try content_buf.toOwnedSlice(alloc);
    } else {
        content_buf.deinit(alloc);
    }
    if (tool_calls.items.len > 0) {
        completion.tool_calls = try tool_calls.toOwnedSlice(alloc);
    } else {
        tool_calls.deinit(alloc);
    }
    debug_trace.logf(
        "stream",
        "openai sse finish={s} content_bytes={d} tools={d}",
        .{
            if (completion.finish_reason) |r| r.label() else "(none)",
            if (completion.content) |c| c.len else 0,
            completion.tool_calls.len,
        },
    );
    return completion;
}

fn readSseLine(
    alloc: std.mem.Allocator,
    reader: *std.Io.Reader,
    pending: *std.ArrayListUnmanaged(u8),
) !?[]const u8 {
    pending.clearRetainingCapacity();
    while (true) {
        const byte = reader.takeByte() catch |err| switch (err) {
            error.EndOfStream => {
                if (pending.items.len == 0) return null;
                return pending.items;
            },
            else => return err,
        };
        if (byte == '\n') return pending.items;
        if (byte == '\r') continue;
        try pending.append(alloc, byte);
        if (pending.items.len > 32 * 1024 * 1024) return error.GatewaySseEventTooLarge;
    }
}

test "rewrite maps prompt tools and maxOutputTokens" {
    const alloc = std.testing.allocator;
    const src =
        \\{"prompt":[{"role":"system","content":"be brief"},{"role":"user","content":[{"type":"text","text":"hi"}]}],"tools":[{"name":"read_file","description":"r","inputSchema":{"type":"object"}}],"maxOutputTokens":4096}
    ;
    const out = try rewriteVercelBodyToOpenAi(alloc, src);
    defer alloc.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"messages\":") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"prompt\":") == null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"max_tokens\":4096") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"stream\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"type\":\"function\"") != null);
}

test "rewrite injects model override" {
    const alloc = std.testing.allocator;
    const src = "{\"prompt\":[{\"role\":\"user\",\"content\":\"hi\"}]}";
    const out = try rewriteVercelBodyToOpenAiWithModel(alloc, src, "demo-model");
    defer alloc.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"model\":\"demo-model\"") != null);
}

test "rewrite applies Qwen3.8 official sampling" {
    const alloc = std.testing.allocator;
    const src = "{\"prompt\":[{\"role\":\"user\",\"content\":\"hi\"}],\"maxOutputTokens\":256}";
    const out = try rewriteVercelBodyToOpenAiWithModel(alloc, src, "Qwen3.8-27B-AWQ-INT4");
    defer alloc.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"max_tokens\":16384") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"temperature\":1.0") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"top_p\":0.95") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"top_k\":20") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"enable_thinking\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"preserve_thinking\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"reasoning_effort\":\"medium\"") != null);
}

test "Qwen high maps to xhigh and off disables thinking" {
    const alloc = std.testing.allocator;
    const high = try rewriteVercelBodyToOpenAiWithModel(
        alloc,
        "{\"prompt\":[{\"role\":\"user\",\"content\":\"hi\"}],\"reasoning\":\"high\"}",
        "Qwen3.8-27B-INT4",
    );
    defer alloc.free(high);
    try std.testing.expect(std.mem.indexOf(u8, high, "\"reasoning_effort\":\"xhigh\"") != null);
    const off = try rewriteVercelBodyToOpenAiWithModel(
        alloc,
        "{\"prompt\":[{\"role\":\"user\",\"content\":\"hi\"}],\"reasoning\":\"off\"}",
        "Qwen3.8-27B-INT4",
    );
    defer alloc.free(off);
    try std.testing.expect(std.mem.indexOf(u8, off, "\"enable_thinking\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, off, "\"presence_penalty\":1.5") != null);
}

test "rewrite applies IOA flash max and pro low" {
    const alloc = std.testing.allocator;
    const src = "{\"prompt\":[{\"role\":\"user\",\"content\":\"hi\"}]}";
    const flash = try rewriteVercelBodyToOpenAiWithModel(alloc, src, "deepseek-v4-flash-ioa");
    defer alloc.free(flash);
    try std.testing.expect(std.mem.indexOf(u8, flash, "\"max_tokens\":16384") != null);
    try std.testing.expect(std.mem.indexOf(u8, flash, "\"reasoning_effort\":\"max\"") != null);
    const pro = try rewriteVercelBodyToOpenAiWithModel(alloc, src, "deepseek-v4-pro-ioa");
    defer alloc.free(pro);
    try std.testing.expect(std.mem.indexOf(u8, pro, "\"max_tokens\":16384") != null);
    try std.testing.expect(std.mem.indexOf(u8, pro, "\"reasoning_effort\":\"low\"") != null);
}

test "rewrite flattens user content parts" {
    const alloc = std.testing.allocator;
    const src =
        \\{"prompt":[{"role":"user","content":[{"type":"text","text":"pong"}]}]}
    ;
    const out = try rewriteVercelBodyToOpenAi(alloc, src);
    defer alloc.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"content\":\"pong\"") != null);
}

test "private LAN http is rfc1918 only" {
    try std.testing.expect(isPrivateLanHttpUrl("http://10.0.0.8:8000/v1"));
    try std.testing.expect(isPrivateLanHttpUrl("http://192.168.1.2:18090/v1"));
    try std.testing.expect(isPrivateLanHttpUrl("http://172.16.0.2:9/v1"));
    try std.testing.expect(!isPrivateLanHttpUrl("http://8.8.8.8:80/v1"));
    try std.testing.expect(!isPrivateLanHttpUrl("https://example.com/v1"));
}

test "derived chat url appends /v1/chat/completions once" {
    try std.testing.expectEqualStrings(
        "http://127.0.0.1:8000/v1/chat/completions",
        derivedChatUrl("http://127.0.0.1:8000"),
    );
    try std.testing.expectEqualStrings(
        "http://127.0.0.1:8000/v1/chat/completions",
        derivedChatUrl("http://127.0.0.1:8000/v1"),
    );
    try std.testing.expectEqualStrings(
        "https://example.com/v2/chat/completions",
        derivedChatUrl("https://example.com/v2"),
    );
}

test "OpenAI wire is used for chat completions URLs" {
    try std.testing.expect(looksLikeOpenAiChatUrl("https://example.com/v2/chat/completions"));
    try std.testing.expect(!looksLikeOpenAiChatUrl("https://ai-gateway.vercel.sh/v3/ai/language-model"));
}

test "https origins are recognized" {
    try std.testing.expect(isHttpsUrl("https://example.com/v2"));
    try std.testing.expect(!isHttpsUrl("http://example.com/v2"));
    try std.testing.expect(!isHttpsUrl("https://user:pass@example.com/v2"));
}

test "consumeOpenAiSse accumulates incremental IOA tool_calls" {
    const alloc = std.testing.allocator;
    const payload =
        "data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"id\":\"call_1\",\"function\":{\"name\":\"list_dir\",\"arguments\":\"\"}}]},\"finish_reason\":\"\"}]}\n\n" ++
        "data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"function\":{\"name\":\"\",\"arguments\":\"{\"}}]},\"finish_reason\":\"\"}]}\n\n" ++
        "data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"function\":{\"name\":\"\",\"arguments\":\"\\\"path\\\":\\\"/tmp\\\"}\"}}]},\"finish_reason\":\"\"}]}\n\n" ++
        "data: {\"choices\":[{\"delta\":{\"tool_calls\":[]},\"finish_reason\":\"tool_calls\"}]}\n\n" ++
        "data: [DONE]\n\n";
    var reader = std.Io.Reader.fixed(payload);
    var cancel = std.atomic.Value(bool).init(false);
    const Noop = struct {
        fn chunk(_: *anyopaque, _: []const u8) void {}
    };
    const completion = try consumeOpenAiSse(alloc, &reader, undefined, Noop.chunk, &cancel);
    defer {
        if (completion.content) |c| alloc.free(c);
        for (completion.tool_calls) |call| {
            alloc.free(call.id);
            alloc.free(call.name);
            alloc.free(call.arguments_json);
        }
        alloc.free(completion.tool_calls);
    }
    try std.testing.expectEqual(types.ProviderFinishReason.tool_calls, completion.finish_reason.?);
    try std.testing.expectEqual(@as(usize, 1), completion.tool_calls.len);
    try std.testing.expectEqualStrings("list_dir", completion.tool_calls[0].name);
    try std.testing.expectEqualStrings("call_1", completion.tool_calls[0].id);
}

test "consumeOpenAiSse splits two complete argument objects" {
    const alloc = std.testing.allocator;
    const payload =
        "data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"id\":\"call_a\",\"index\":0,\"function\":{\"name\":\"list_files\",\"arguments\":\"{\\\"path\\\":\\\"\\\"}\"}}]}}]}\n\n" ++
        "data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"id\":\"call_b\",\"index\":0,\"function\":{\"name\":\"terminal\",\"arguments\":\"{\\\"command\\\":\\\"ls\\\"}\"}}]}}]}\n\n" ++
        "data: {\"choices\":[{\"delta\":{},\"finish_reason\":\"tool_calls\"}]}\n\n" ++
        "data: [DONE]\n\n";
    var reader = std.Io.Reader.fixed(payload);
    var cancel = std.atomic.Value(bool).init(false);
    const Noop = struct {
        fn chunk(_: *anyopaque, _: []const u8) void {}
    };
    const completion = try consumeOpenAiSse(alloc, &reader, undefined, Noop.chunk, &cancel);
    defer {
        if (completion.content) |c| alloc.free(c);
        for (completion.tool_calls) |call| {
            alloc.free(call.id);
            alloc.free(call.name);
            alloc.free(call.arguments_json);
        }
        alloc.free(completion.tool_calls);
    }
    try std.testing.expectEqual(@as(usize, 2), completion.tool_calls.len);
    try std.testing.expectEqualStrings("list_files", completion.tool_calls[0].name);
    try std.testing.expectEqualStrings("terminal", completion.tool_calls[1].name);
}

test "consumeOpenAiSse reads content and stop" {
    const alloc = std.testing.allocator;
    const payload =
        "data: {\"choices\":[{\"delta\":{\"content\":\"po\"},\"finish_reason\":null}]}\n\n" ++
        "data: {\"choices\":[{\"delta\":{\"content\":\"ng\"},\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":3,\"completion_tokens\":2}}\n\n" ++
        "data: [DONE]\n\n";
    var reader = std.Io.Reader.fixed(payload);
    var cancel = std.atomic.Value(bool).init(false);
    const Noop = struct {
        fn chunk(_: *anyopaque, _: []const u8) void {}
    };
    const completion = try consumeOpenAiSse(alloc, &reader, undefined, Noop.chunk, &cancel);
    defer if (completion.content) |c| alloc.free(c);
    try std.testing.expectEqualStrings("pong", completion.content.?);
    try std.testing.expectEqual(types.ProviderFinishReason.stop, completion.finish_reason.?);
}
