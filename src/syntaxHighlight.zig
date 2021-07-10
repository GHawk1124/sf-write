const std = @import("std");

pub const zigDeclarations: []const []const []const u8 =
    &[_][]const []const u8{
    &[_][]const u8{ "const", "var" },
    &[_][]const u8{ "defer", "\"" },
    &[_][]const u8{ "pub", "fn", "for", "while", "if", "else", "try", "orelse" },
    &[_][]const u8{ "void", "u8", "u16", "u32", "u64", "usize", "i8", "i16", "i32", "i64", "isize" },
};

pub fn printSyntax(str: []const []const []const u8) void {
    for (str) |array| {
        for (array) |word| {
            std.debug.print("{s}", .{word});
        }
    }
}
