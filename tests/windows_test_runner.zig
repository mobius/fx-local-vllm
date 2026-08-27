//! Windows test runner with the same Zig 0.16 permission compatibility used
//! by the native fx executable.
const builtin = @import("builtin");
const std = @import("std");

pub const std_options_FilePermissions: ?type = if (builtin.os.tag == .windows)
    enum(u32) {
        default_file = 0,
        _,

        pub const default_dir: @This() = .default_file;
        pub const executable_file: @This() = .default_file;
        pub const has_executable_bit = false;

        pub fn fromMode(mode: anytype) @This() {
            const numeric_mode: u32 = @intCast(mode);
            const attributes: u32 = if (numeric_mode & 0o222 == 0) 1 else 0;
            return @enumFromInt(attributes);
        }

        pub fn toMode(self: @This()) u32 {
            _ = self;
            return 0;
        }

        pub fn toAttributes(self: @This()) std.os.windows.FILE.ATTRIBUTE {
            return @bitCast(@intFromEnum(self));
        }

        pub fn readOnly(self: @This()) bool {
            return @intFromEnum(self) & 1 != 0;
        }

        pub fn setReadOnly(self: @This(), read_only: bool) @This() {
            const attributes = @intFromEnum(self);
            return @enumFromInt(if (read_only) attributes | 1 else attributes & ~@as(u32, 1));
        }
    }
else
    null;

const Io = std.Io;
const testing = std.testing;

pub fn main(init: std.process.Init.Minimal) void {
    @disableInstrumentation();

    var failed: usize = 0;
    var skipped: usize = 0;
    var leaked: usize = 0;
    testing.environ = init.environ;

    for (builtin.test_functions) |test_fn| {
        testing.allocator_instance = .{};
        testing.io_instance = .init(testing.allocator, .{
            .argv0 = .init(init.args),
            .environ = init.environ,
        });

        const result = test_fn.func();
        testing.io_instance.deinit();
        if (testing.allocator_instance.deinit() == .leak) leaked += 1;

        if (result) |_| {
            std.debug.print("OK {s}\n", .{test_fn.name});
        } else |err| switch (err) {
            error.SkipZigTest => {
                skipped += 1;
                std.debug.print("SKIP {s}\n", .{test_fn.name});
            },
            else => {
                failed += 1;
                std.debug.print("FAIL {s}: {t}\n", .{ test_fn.name, err });
                if (@errorReturnTrace()) |trace| std.debug.dumpErrorReturnTrace(trace);
            },
        }
    }

    std.debug.print(
        "Windows test summary: {d} failed, {d} skipped, {d} leaked\n",
        .{ failed, skipped, leaked },
    );
    if (failed != 0 or leaked != 0) std.process.exit(1);
}

/// Run fuzz corpora once in the normal Windows test build. The actual
/// libFuzzer runner is intentionally left to Zig's dedicated fuzz build.
pub fn fuzz(
    context: anytype,
    comptime testOne: fn (context: @TypeOf(context), *std.testing.Smith) anyerror!void,
    options: std.testing.FuzzInputOptions,
) anyerror!void {
    for (options.corpus) |input| {
        var smith: std.testing.Smith = .{ .in = input };
        try testOne(context, &smith);
    }
    var smith: std.testing.Smith = .{ .in = "" };
    try testOne(context, &smith);
}

test {
    _ = Io;
}
