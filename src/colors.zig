const c = @import("c.zig");

pub const white = c.SDL_Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
pub const red = c.SDL_Color{ .r = 255, .g = 0, .b = 0, .a = 255 };
pub const green = c.SDL_Color{ .r = 0, .g = 255, .b = 0, .a = 255 };
pub const blue = c.SDL_Color{ .r = 0, .g = 0, .b = 255, .a = 255 };
pub const black = c.SDL_Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
pub const grey = c.SDL_Color{ .r = 40, .g = 40, .b = 40, .a = 255 };
pub const yellow = c.SDL_Color{ .r = 255, .g = 255, .b = 0, .a = 255 };
