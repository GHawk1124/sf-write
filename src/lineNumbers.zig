const std = @import("std");

pub fn countDigits(comptime T: type, n: T) T {
    var count: T = 0;
    var num = n;
    if (num == 0) {
        count += 1;
        return count;
    }
    while (num != 0) : (count += 1) {
        num = num / 10;
    }
    return count;
}

pub fn addLineNumbers(allocator: *std.mem.Allocator, iterator: usize, file_len: usize) ![]const u8 {
    const max_digits = countDigits(usize, file_len);
    const it_digits = countDigits(usize, iterator + 1);
    var spaces = std.ArrayList(u8).init(allocator);
    var i: usize = 0;
    while (i < max_digits * 2) : (i += 1) {
        try spaces.append(' ');
    }
    const spaces_slice = spaces.items[0 .. 2 * (max_digits - it_digits)];
    const num_prompt = try std.fmt.allocPrint(allocator, "{s}{d}   ", .{ spaces_slice, iterator + 1 });
    return num_prompt;
}
