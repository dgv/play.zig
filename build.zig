const std = @import("std");
const zmpl_build = @import("zmpl");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const templates_paths = try zmpl_build.templatesPaths(
        b.allocator,
        &.{
            .{ .prefix = "", .path = &.{
                ".",
            } },
        },
    );
    const exe = b.addExecutable(.{
        .name = "play-zig",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("s3db", b.dependency("s3db", .{
        .target = target,
        .optimize = optimize,
    }).module("s3db"));
    exe.root_module.addImport("tmpfile", b.dependency("tmpfile", .{}).module("tmpfile"));
    exe.root_module.addImport("zcmd", b.dependency("zcmd", .{}).module("zcmd"));
    exe.root_module.addImport("string", b.dependency("zig-string", .{}).module("string"));
    exe.root_module.addImport("ziglyph", b.dependency("ziglyph", .{}).module("ziglyph"));
    exe.root_module.addImport("zmpl", b.dependency("zmpl", .{
        .target = target,
        .optimize = optimize,
        .zmpl_templates_paths = templates_paths,
    }).module("zmpl"));
    exe.root_module.addImport("httpz", b.dependency("httpz", .{
        .target = target,
        .optimize = optimize,
    }).module("httpz"));
    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
