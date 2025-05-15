const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const conf = b.addOptions();
    conf.addOption(
        bool,
        "can_fd",
        b.option(bool, "can_fd", "Enable support for CAN Flexible Data Rate") orelse false,
    );
    const module = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    module.addOptions("conf", conf);

    const library = b.addLibrary(.{
        .linkage = .static,
        .name = "zano",
        .root_module = module,
    });

    b.installArtifact(library);

    const exe = b.addExecutable(.{
        .name = "zano",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);
    exe.root_module.addImport("zano", module);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
