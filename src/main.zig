const std = @import("std");
const c = @import("c.zig");
const ln = @import("lineNumbers.zig");
const colors = @import("colors.zig");
const fb = @import("fileBuf.zig");
const args = @import("args.zig");
const settings = @import("settings.zig");
const synHigh = @import("syntaxHighlight.zig");

const cursor = struct {
    x: u16,
    y: u16,
    insert: bool = false,
};

pub fn main() anyerror!void {
    // synHigh.printSyntax(synHigh.zigDeclarations);
    const compSettings = settings.compile_settings{};

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    if (c.TTF_Init() != 0) {
        c.SDL_Log("Unable to initialize TTF: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.TTF_Quit();

    const screen = c.SDL_CreateWindow("sf-write", c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, compSettings.window_width, compSettings.window_height, c.SDL_WINDOW_RESIZABLE) orelse {
        c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(screen);

    const renderer = c.SDL_CreateRenderer(screen, -1, 0) orelse {
        c.SDL_Log("Unable to create renderer: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);

    const font_ttf = @embedFile(compSettings.font);
    const rw = c.SDL_RWFromConstMem(
        @ptrCast(*const c_void, &font_ttf[0]),
        @intCast(c_int, font_ttf.len),
    ) orelse {
        c.SDL_Log("Unable to get RWFromConstMem: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    // const font = c.TTF_OpenFont("Sans.ttf", 24);
    const font = c.TTF_OpenFontRW(rw, 1, compSettings.font_size);

    const file_arg = try args.getFileArg(allocator);

    var curs = cursor{ .x = 0, .y = 0 };

    var text: fb.fileBuf = undefined;
    if (!(file_arg.len > 0)) {
        const open_raw_text: []const u8 =
            \\ Welcome to sf-write!
            \\ Author: Garrett Comes
            \\ Liscense: MIT
        ;
        var open_text_iterator = std.mem.split(open_raw_text, "\n");
        var open_text = std.ArrayList([]const u8).init(allocator);
        const open_len: usize = comptime len: {
            var temp: usize = 0;
            for (open_raw_text) |char| {
                if (char == '\n') temp += 1;
            }
            break :len temp;
        };

        while (open_text_iterator.next()) |line| {
            const line_cstr = try std.cstr.addNullByte(allocator, line);
            try open_text.append(line_cstr);
        }

        text = fb.fileBuf{ .file_len = open_len, .textBuf = open_text };
    } else {
        text = fb.fileBuf{ .file_len = 0, .textBuf = std.ArrayList([]const u8).init(allocator) };
        try text.readFile(allocator, file_arg);
    }

    var camera = c.SDL_Rect{ .x = 0, .y = 0, .w = 0, .h = 0 };

    var quit: bool = false;
    var renderText: bool = true;
    while (!quit) {
        // Only render text when we have to
        if (renderText) {
            _ = c.SDL_RenderClear(renderer);
            for (text.textBuf.items) |line, i| {
                var printed_line = line;
                const number_len = text.file_len;
                var wordColor = colors.white;
                var bgColor = colors.grey;

                // Various filters to the line can be added here
                // printed_line = line_filter: {
                //     const numberPrompt = ln.addLineNumbers(allocator, i, number_len);
                //     const nline = try std.fmt.allocPrint(allocator, "{s}{s}", .{ numberPrompt, line });
                //     break :line_filter nline;
                // };

                var line_iterator = std.mem.tokenize(printed_line, " ");
                var wordx: c_int = 0;

                while (line_iterator.next()) |word_raw| {
                    var winW: c_int = undefined;
                    _ = c.SDL_GetWindowSize(screen, &winW, null);
                    wordColor = colors.white;
                    for (synHigh.zigDeclarations) |syntaxGroup, j| {
                        for (syntaxGroup) |syntax| {
                            if (std.mem.eql(u8, word_raw, syntax)) {
                                if (j == 0) {
                                    wordColor = colors.red;
                                } else if (j == 1) {
                                    wordColor = colors.green;
                                } else if (j == 2) {
                                    wordColor = colors.blue;
                                }
                            }
                        }
                    }
                    if (curs.y == i) {
                        bgColor = colors.grey;
                    } else {
                        bgColor = colors.black;
                    }

                    const wordSpace = try std.fmt.allocPrint(allocator, "{s} ", .{word_raw});
                    const word = try std.cstr.addNullByte(allocator, wordSpace);

                    const surface = c.TTF_RenderText_Shaded(font, @ptrCast([*c]const u8, word), wordColor, bgColor) orelse {
                        c.SDL_Log("Unable to load TTF: %s", c.SDL_GetError());
                        return error.SDLInitializationFailed;
                    };
                    defer c.SDL_FreeSurface(surface);

                    const texture = c.SDL_CreateTextureFromSurface(renderer, surface) orelse {
                        c.SDL_Log("Unable to create texture: %s", c.SDL_GetError());
                        return error.SDLInitializationFailed;
                    };
                    defer c.SDL_DestroyTexture(texture);

                    var texW: c_int = 0;
                    var texH: c_int = 0;
                    const texQuery = c.SDL_QueryTexture(texture, null, null, &texW, &texH);
                    const line_y = @intCast(c_int, i) * texH;
                    const y = if (camera.y > 0) line_y - camera.y else line_y;
                    const str_rect = c.SDL_Rect{ .x = wordx, .y = y, .w = texW, .h = texH };
                    wordx += texW;
                    _ = c.SDL_RenderCopy(renderer, texture, null, &str_rect);
                }
            }
            renderText = false;
        }

        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.@"type") {
                c.SDL_QUIT => {
                    // Handle window "X"
                    quit = true;
                },
                c.SDL_WINDOWEVENT => {
                    // Render text on resize
                    renderText = true;
                },
                c.SDL_KEYDOWN => {
                    // Handle ctrl+q quit
                    if (event.key.keysym.sym == c.SDLK_q) {
                        if ((event.key.keysym.mod & c.KMOD_CTRL) != 0) {
                            quit = true;
                        }
                    }
                    if (event.key.keysym.sym == c.SDLK_h and !curs.insert) {
                        if (curs.x > 0) {
                            curs.x -= 1;
                        }
                    }
                    if (event.key.keysym.sym == c.SDLK_l and !curs.insert) {
                        if (curs.x < text.textBuf.items[curs.y].len) {
                            curs.x += 1;
                        }
                    }
                    if (event.key.keysym.sym == c.SDLK_j and !curs.insert) {
                        if (curs.y > 0) {
                            curs.y -= 1;
                        }
                    }
                    if (event.key.keysym.sym == c.SDLK_k and !curs.insert) {
                        if (curs.y < text.file_len) {
                            curs.y += 1;
                        }
                    }
                },
                c.SDL_MOUSEWHEEL => {
                    // Handle scrolling
                    renderText = true;
                    if (event.wheel.y != 0) {
                        if (camera.y + 3 * event.wheel.y >= 0) {
                            camera.y += 3 * event.wheel.y;
                        }
                    }
                },
                else => {
                    renderText = false;
                },
            }
        }

        c.SDL_RenderPresent(renderer);

        c.SDL_Delay(10);
    }
}
