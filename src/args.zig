const std = @import("std");

pub fn getFileArg(Allocator: *std.mem.Allocator) ![]const u8 {
    var cmd_args = std.process.args();
    _ = cmd_args.skip();

    const file_arg: []const u8 = try (cmd_args.next(Allocator) orelse {
        return "";
    });
    return file_arg;
}
