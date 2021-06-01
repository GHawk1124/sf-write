const std = @import("std");
const c = @import("c.zig");
const ln = @import("lineNumbers.zig");
const colors = @import("colors.zig");

pub fn readFile(Allocator: *std.mem.Allocator, infile: []const u8) ![]const u8 {
    const file_contents = try std.fs.cwd().readFileAlloc(Allocator, infile, 4096);
    return file_contents;
}

pub fn main() anyerror!void {
    const compile_settings = struct {
        font: []const u8 = "../assets/Sans.ttf",
        font_size: usize = 24,
        window_width: usize = 1280,
        window_height: usize = 960,
    };

    const settings = compile_settings{ .font_size = 24 };

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

    const screen = c.SDL_CreateWindow("sf-write", c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, settings.window_width, settings.window_height, c.SDL_WINDOW_RESIZABLE) orelse {
        c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(screen);

    const renderer = c.SDL_CreateRenderer(screen, -1, 0) orelse {
        c.SDL_Log("Unable to create renderer: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);

    const font_ttf = @embedFile(settings.font);
    const rw = c.SDL_RWFromConstMem(
        @ptrCast(*const c_void, &font_ttf[0]),
        @intCast(c_int, font_ttf.len),
    ) orelse {
        c.SDL_Log("Unable to get RWFromConstMem: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    // const font = c.TTF_OpenFont("Sans.ttf", 24);
    const font = c.TTF_OpenFontRW(rw, 1, settings.font_size);

    var cmd_args = std.process.args();
    _ = cmd_args.skip();

    const file_arg: []const u8 = try (cmd_args.next(allocator) orelse {
        return error.InvalidArgs;
    });

    const text_raw = try readFile(allocator, file_arg);
    var text_iterator = std.mem.split(text_raw, "\n");
    var text = std.ArrayList([]const u8).init(allocator);
    var file_len: usize = 0;
    while (text_iterator.next()) |line| {
        const line_cstr = try std.cstr.addNullByte(allocator, line);
        try text.append(line_cstr);
        file_len += 1;
    }
    file_len -= 1;

    var camera = c.SDL_Rect{ .x = 0, .y = 0, .w = 0, .h = 0 };

    var quit = false;
    var renderText: bool = true;
    while (!quit) {
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
                },
                c.SDL_MOUSEWHEEL => {
                    // Handle scrolling
                    if (event.wheel.y > 0) {
                        renderText = true;
                        camera.y += 5;
                    } else if (event.wheel.y < 0) {
                        renderText = true;
                        if (camera.y > 0) {
                            camera.y -= 5;
                        }
                    }
                },
                else => {},
            }
        }

        // Only render text when we have to
        if (renderText) {
            _ = c.SDL_RenderClear(renderer);
            for (text.items) |line, i| {
                var printed_line = line;
                // Various Filters to the line can be added here
                printed_line = color_filter: {
                    const numberPrompt = ln.addLineNumbers(allocator, i, file_len);
                    const nline = try std.fmt.allocPrint(allocator, "{s}{s}", .{ numberPrompt, line });
                    break :color_filter nline;
                };
                const surface = c.TTF_RenderText_Shaded(font, @ptrCast([*c]const u8, printed_line), colors.white, colors.black) orelse {
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
                const x = 0; // - camera.x?
                const line_y = @intCast(c_int, i) * texH;
                const y = if (camera.y > 0) line_y - camera.y else line_y;
                const str_rect = c.SDL_Rect{ .x = x, .y = y, .w = texW, .h = texH };
                _ = c.SDL_RenderCopy(renderer, texture, null, &str_rect);
            }
            renderText = false;
        }

        c.SDL_RenderPresent(renderer);

        c.SDL_Delay(10);
    }
}
