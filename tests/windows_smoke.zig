//! Focused Windows validation for the fx product.
//!
//! The upstream test registry is intentionally POSIX-heavy. This root keeps
//! Windows CI useful by validating the compiled product through its public
//! command-line surface; the production build still compiles the complete fx
//! source graph.
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

fn productPath() ![]const u8 {
    const path_z = std.c.getenv("FX_TEST_PRODUCT_EXE") orelse
        return error.TestProductExecutableMissing;
    return std.mem.sliceTo(path_z, 0);
}

fn runProduct(args: []const []const u8) !std.process.RunResult {
    const executable = try productPath();
    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(std.testing.allocator);
    try argv.append(std.testing.allocator, executable);
    try argv.appendSlice(std.testing.allocator, args);
    return std.process.run(std.testing.allocator, std.testing.io, .{
        .argv = argv.items,
        .stdout_limit = .limited(64 * 1024),
        .stderr_limit = .limited(64 * 1024),
    });
}

test "Windows smoke runner targets Windows" {
    try std.testing.expectEqual(std.Target.Os.Tag.windows, builtin.os.tag);
}

test "fx Windows product prints its version and exits" {
    const result = runProduct(&.{"--version"}) catch |err| switch (err) {
        error.TestProductExecutableMissing => return error.SkipZigTest,
        else => return err,
    };
    defer {
        std.testing.allocator.free(result.stdout);
        std.testing.allocator.free(result.stderr);
    }

    try std.testing.expectEqual(std.process.Child.Term{ .exited = 0 }, result.term);
    try std.testing.expect(result.stdout.len > 0 or result.stderr.len > 0);
}

test "fx Windows product renders top-level help and exits" {
    const result = runProduct(&.{"--help"}) catch |err| switch (err) {
        error.TestProductExecutableMissing => return error.SkipZigTest,
        else => return err,
    };
    defer {
        std.testing.allocator.free(result.stdout);
        std.testing.allocator.free(result.stderr);
    }

    try std.testing.expectEqual(std.process.Child.Term{ .exited = 0 }, result.term);
    const output = if (result.stdout.len > 0) result.stdout else result.stderr;
    try std.testing.expect(std.mem.indexOf(u8, output, "help") != null);
}
