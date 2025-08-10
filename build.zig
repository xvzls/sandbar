const std = @import("std");

fn shell(
    b: *std.Build,
    command: []const []const u8,
) []const u8 {
    var child = std.process.Child.init(
        command,
        b.allocator,
    );
    child.stdout_behavior = .Pipe;
    child.spawn() catch |err| {
        std.debug.print("Failed to run:\n  ", .{});
        for (command) |param| {
            std.debug.print("{s} ", .{ param });
        }
        std.debug.print("\n{}\n", .{ err });
        std.process.exit(1);
    };
    
    var stdout = std.ArrayList(u8).init(b.allocator);
    child.stdout.?.reader().readAllArrayList(
        &stdout,
        1024
    ) catch |err| {
        std.debug.print("Failed to read stdout:\n  ", .{});
        for (command) |param| {
            std.debug.print("{s} ", .{ param });
        }
        std.debug.print("\n{}\n", .{ err });
        std.process.exit(1);
    };
    
    _ = child.wait() catch |err| {
        std.debug.print("Failed to wait:\n  ", .{});
        for (command) |param| {
            std.debug.print("{s} ", .{ param });
        }
        std.debug.print("\n{}\n", .{ err });
        std.process.exit(1);
    };
    
    return std.mem.trim(u8, stdout.items, "\n");
}

fn getPkgConfigVariable(
    b: *std.Build,
    package: []const u8,
    variable: []const u8,
) []const u8 {
    return shell(b, &.{
        "pkg-config",
        "--variable",
        variable,
        package,
    });
}

fn generateProtocolHeader(
    b: *std.Build,
    wayland_scanner: []const u8,
    input: []const u8,
    output: []const u8,
) *std.Build.Step.Run {
    const generate_protocol_header = b
        .addSystemCommand(&.{
            wayland_scanner,
            "client-header",
            input,
            output,
        });
    generate_protocol_header.setName(b.fmt(
        "generate {s}",
        .{ output }
    ));
    
    return generate_protocol_header;
}

fn generateProtocolSource(
    b: *std.Build,
    wayland_scanner: []const u8,
    input: []const u8,
    output: []const u8,
) *std.Build.Step.Run {
    const generate_protocol_header = b
        .addSystemCommand(&.{
            wayland_scanner,
            "private-code",
            input,
            output,
        });
    generate_protocol_header.setName(b.fmt(
        "generate {s}",
        .{ output }
    ));
    
    return generate_protocol_header;
}

fn generateProtocol(
    b: *std.Build,
    wayland_scanner: []const u8,
    input: []const u8,
    output: []const u8,
) struct {
    step: *std.Build.Step,
    header: []const u8,
    source: []const u8,
} {
    const header_output_path =
        b.fmt("include/{s}.h", .{ output });
    const header = generateProtocolHeader(
        b,
        wayland_scanner,
        input,
        header_output_path
    );
    const source_output_path =
        b.fmt("src/{s}.c", .{ output });
    const source = generateProtocolSource(
        b,
        wayland_scanner,
        input,
        source_output_path
    );
    
    const step = b.step(
        b.fmt("generate {s}", .{ output }),
        b.fmt("creates {s} protocol files", .{ output }),
    );
    
    step.dependOn(&header.step);
    step.dependOn(&source.step);
    
    return .{
        .step = step,
        .header = header_output_path,
        .source = source_output_path,
    };
}

fn includePaths(b: *std.Build) [][]const u8 {
    const raw = shell(b, &.{
        "pkg-config",
        "--cflags",
        "wayland-client",
        "wayland-cursor",
        "fcft",
        "pixman-1",
    });
    
    var list = std.ArrayList([]const u8).init(b.allocator);
    var iter = std.mem.splitScalar(u8, raw, ' ');
    while (iter.next()) |item| {
        const slice = b.allocator.dupe(u8, item[2 ..]) catch unreachable;
        list.append(slice) catch unreachable;
    }
    
    return list.items;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    const wayland_scanner = getPkgConfigVariable(
        b,
        "wayland-scanner",
        "wayland_scanner",
    );
    const wayland_protocols = getPkgConfigVariable(
        b,
        "wayland-protocols",
        "pkgdatadir",
    );
    
    const generate_xdg_shell_protocol =
        generateProtocol(
            b,
            wayland_scanner,
            b.fmt(
                "{s}/stable/xdg-shell/xdg-shell.xml",
                .{
                    wayland_protocols
                },
            ),
            "xdg-shell-protocol",
        );
    const generate_wlr_layer_shell_protocol =
        generateProtocol(
            b,
            wayland_scanner,
            "protocols/wlr-layer-shell-unstable-v1.xml",
            "wlr-layer-shell-unstable-v1-protocol",
        );
    const generate_river_status_protocol =
        generateProtocol(
            b,
            wayland_scanner,
            "protocols/river-status-unstable-v1.xml",
            "river-status-unstable-v1-protocol",
        );
    const generate_river_control_protocol =
        generateProtocol(
            b,
            wayland_scanner,
            "protocols/river-control-unstable-v1.xml",
            "river-control-unstable-v1-protocol",
        );
    
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("sandbar_lib", lib_mod);
    
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "sandbar",
        .root_module = lib_mod,
    });
    lib.linkSystemLibrary("wayland-client");
    lib.linkSystemLibrary("wayland-cursor");
    lib.linkSystemLibrary("fcft");
    lib.linkSystemLibrary("pixman-1");
    lib.linkSystemLibrary("rt");
    lib.linkLibC();
    
    lib.step.dependOn(
        generate_xdg_shell_protocol.step
    );
    lib.step.dependOn(
        generate_wlr_layer_shell_protocol.step
    );
    lib.step.dependOn(
        generate_river_status_protocol.step
    );
    lib.step.dependOn(
        generate_river_control_protocol.step
    );
    lib.addIncludePath(.{
        .cwd_relative = "include",
    });
    const include_paths = includePaths(b);
    for (include_paths) |path| {
        lib.addIncludePath(.{
            .cwd_relative = path,
        });
    }
    lib.addCSourceFiles(.{
        .files = &.{
            generate_xdg_shell_protocol.source,
            generate_wlr_layer_shell_protocol.source,
            generate_river_status_protocol.source,
            generate_river_control_protocol.source,
            "sandbar.c",
        },
    });
    b.installArtifact(lib);
    
    const exe = b.addExecutable(.{
        .name = "sandbar",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);
    
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
    
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });
    
    const run_lib_unit_tests = b.addRunArtifact(
        lib_unit_tests
    );
    
    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });
    
    const run_exe_unit_tests = b.addRunArtifact(
        exe_unit_tests
    );
    
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}

