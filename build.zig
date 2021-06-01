const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("sf-write", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.linkSystemLibrary("SDL2");
    exe.linkSystemLibrary("SDL2_ttf");
    exe.linkSystemLibrary("c");

    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);

    const run = b.step("run", "Run the App");
    const run_cmd = exe.run();
    run.dependOn(&run_cmd.step);
}
