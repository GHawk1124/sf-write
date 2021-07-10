const std = @import("std");

pub const fileBuf = struct {
    file_len: usize,
    textBuf: std.ArrayListAligned([]const u8, null),

    pub fn readFile(self: *fileBuf, Allocator: *std.mem.Allocator, infile: []const u8) !void {
        const text_raw = try std.fs.cwd().readFileAlloc(Allocator, infile, 4096);
        var text_iterator = std.mem.tokenize(text_raw, "\n");
        // self.textBuf = std.ArrayList([]const u8).init(Allocator);
        self.file_len = 0;
        while (text_iterator.next()) |line| {
            if (line.len > 0) {
                const line_cstr = try std.cstr.addNullByte(Allocator, line);
                try self.textBuf.append(line_cstr);
            } else {
                const line_cstr = try std.cstr.addNullByte(Allocator, "\n");
                try self.textBuf.append(line_cstr);
            }
            self.file_len += 1;
        }
        self.file_len -= 1;
    }
};
