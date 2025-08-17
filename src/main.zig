const lib = @import("sandbar_lib");
const std = @import("std");
const wl = lib.wl;
const c = lib.c;
const clap = @import("clap");

const PROGRAM = "sandbar";
const VERSION = "0.2";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){
        .backing_allocator = std.heap.c_allocator,
    };
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const params = comptime clap.parseParamsComptime(
        \\--hidden                   bars will initially be hidden
        \\--bottom                   bars will initially be drawn at the bottom
        \\--hide-vacant-tags         do not display empty and inactive tags
        \\--no-title                 do not display current view title
        \\--no-status-commands       disable in-line commands in status text
        \\--no-layout                do not display the current layout
        \\--no-mode                  do not display the current mode
        \\--hide-normal-mode         only display the current mode when it is not set to normal
        \\--font <str>               specify a font
        \\--tags <str>...            specify custom tag names
        \\--vertical-padding <u32>   specify vertical pixel padding above and below text
        \\--scale <u32>              specify buffer scale value for integer scaling
        \\--active-fg-color <str>    specify text color of active tags or monitors
        \\--active-bg-color <str>    specify background color of active tags or monitors
        \\--inactive-fg-color <str>  specify text color of inactive tags or monitors
        \\--inactive-bg-color <str>  specify background color of inactive tags or monitors
        \\--urgent-fg-color <str>    specify text color of urgent tags
        \\--urgent-bg-color <str>    specify background color of urgent tags
        \\--title-fg-color <str>     specify text color of title bar
        \\--title-bg-color <str>     specify background color of title bar
        \\-v, --version              get version information
        \\-h, --help                 view this help text
        \\
    );
    
    var diagnostic = clap.Diagnostic{};
    var result = clap.parse(
        clap.Help,
        &params,
        clap.parsers.default,
        .{
            .diagnostic = &diagnostic,
            .allocator = allocator,
        },
    ) catch |err| {
        try diagnostic.report(
            std.io.getStdErr().writer(),
            err,
        );
        return err;
    };
    defer result.deinit();
    
    const args = result.args;
    
    if (args.@"version" != 0) {
        std.debug.print("{s} {s}\n", .{
            PROGRAM,
            VERSION,
        });
        return;
    }
    
    if (args.@"help" != 0) {
        return clap.help(
            std.io.getStdErr().writer(),
            clap.Help,
            &params,
            .{},
        );
    }
    
    lib.hidden = args.@"hidden" != 0;
    lib.bottom = args.@"bottom" != 0;
    lib.hide_vacant = args.@"hide-vacant-tags" != 0;
    lib.no_title = args.@"no-title" != 0;
    lib.no_status_commands = args.@"no-status-commands" != 0;
    lib.no_layout = args.@"no-layout" != 0;
    lib.no_mode = args.@"no-mode" != 0;
    lib.hide_normal_mode = args.@"hide-normal-mode" != 0;
    
    const font_str = args.@"font" orelse "monospace:size=16";
    
    if (args.@"vertical-padding") |number| {
        lib.vertical_padding = std.math.clamp(
            number,
            0,
            100,
        );
    }
    if (args.@"scale") |number| {
        lib.buffer_scale = number;
    }
    if (args.@"active-fg-color") |string| {
        lib.active_fg_color = try lib.parse_color(string);
    }
    if (args.@"active-bg-color") |string| {
        lib.active_bg_color = try lib.parse_color(string);
    }
    if (args.@"inactive-fg-color") |string| {
        lib.inactive_fg_color = try lib.parse_color(string);
    }
    if (args.@"inactive-bg-color") |string| {
        lib.inactive_bg_color = try lib.parse_color(string);
    }
    if (args.@"urgent-fg-color") |string| {
        lib.urgent_fg_color = try lib.parse_color(string);
    }
    if (args.@"urgent-bg-color") |string| {
        lib.urgent_bg_color = try lib.parse_color(string);
    }
    if (args.@"title-fg-color") |string| {
        lib.title_fg_color = try lib.parse_color(string);
    }
    if (args.@"title-bg-color") |string| {
        lib.title_bg_color = try lib.parse_color(string);
    }
    for (result.positionals) |tag| {
        _ = tag;
    //     if (++i + 1 >= argc)
    //         DIE("Option -tags requires at least two arguments");
    //     int v;
    //     if ((v = atoi(argv[i])) <= 0 || i + v >= argc)
    //         DIE("-tags: invalid arguments");
    //     if (tags) {
    //         for (uint32_t j = 0; j < tags_l; j++)
    //             free(tags[j]);
    //         free(tags);
    //     }
    //     if (!(tags = malloc(v * sizeof(char *))))
    //         EDIE("malloc");
    //     for (int j = 0; j < v; j++)
    //         if (!(tags[j] = strdup(argv[i + 1 + j])))
    //             EDIE("strdup");
    //     tags_l = v;
    //     i += v;
    }
    
    lib.display =
        c.wl_display_connect(null)
    orelse
        @panic("Failed to create display");
    
    c.wl_list_init(&lib.bar_list);
    c.wl_list_init(&lib.seat_list);
    
    const registry = c.wl_display_get_registry(
        lib.display
    );
    _ = c.wl_registry_add_listener(
        registry,
        &lib.registry_listener,
        null,
    );
    _ = c.wl_display_roundtrip(lib.display);
    if (
        lib.compositor == null or
        lib.shm == null or
        lib.layer_shell == null or
        lib.river_status_manager == null or
        lib.river_control == null
    ) {
        @panic("Compositor does not support all needed protocols");
    }
    
    _ = c.fcft_init(
        c.FCFT_LOG_COLORIZE_AUTO,
        false,
        c.FCFT_LOG_CLASS_ERROR,
    );
    _ = c.fcft_set_scaling_filter(
        c.FCFT_SCALING_FILTER_LANCZOS3,
    );
    
    var buf: [10]u8 = undefined;
    const attributes = try std.fmt.bufPrintZ(
        &buf,
        "dpi={}",
        .{
            96 * lib.buffer_scale
        },
    );
    lib.font = c.fcft_from_name(
        1,
        @ptrCast(@constCast(&.{
            font_str.ptr,
        })),
        attributes,
    ) orelse @panic("Could not load font");
    lib.textpadding = @intCast(
        @divTrunc(lib.font.?.height, 2)
    );
    lib.height = @divTrunc(
        @as(u32, @intCast(lib.font.?.height)),
        lib.buffer_scale,
    ) + lib.vertical_padding * 2;
    
    if (lib.tags.len == 0) { // TODO
        lib.tags = try allocator.alloc([*c]u8, 9);
        for (lib.tags, 1..) |*tag, i| {
            tag.* = try std.fmt.allocPrintZ(
                allocator,
                "{}",
                .{ i },
            );
        }
    }
    
    {
        var bars = wl.List(lib.Bar)
            .from(&lib.bar_list)
            .iterator("link");
        while (bars.next()) |bar| {
            lib.setup_bar(bar);
        }
    }
    
    {
        var seats = wl.List(lib.Seat)
            .from(&lib.seat_list)
            .iterator("link");
        while (seats.next()) |seat| {
            lib.setup_seat(seat);
        }
    }
    
    _ = c.wl_display_roundtrip(lib.display);
    
    if (c.fcntl(
        c.STDIN_FILENO,
        c.F_SETFL,
        c.O_NONBLOCK
    ) == -1) {
        @panic("fcntl");
    }
    
    _ = c.signal(c.SIGINT, lib.sig_handler);
    _ = c.signal(c.SIGHUP, lib.sig_handler);
    _ = c.signal(c.SIGTERM, lib.sig_handler);
    _ = c.signal(c.SIGCHLD, c.SIG_IGN);
    
    lib.run_display = true;
    lib.event_loop();
    
    for (lib.tags) |tag| {
        allocator.free(std.mem.span(tag));
    }
    allocator.free(lib.tags);
    
    {
        var bars = wl.List(lib.Bar)
            .from(&lib.bar_list)
            .iterator("link");
        while (bars.next()) |bar| {
            lib.teardown_bar(bar);
        }
    }
    
    {
        var seats = wl.List(lib.Seat)
            .from(&lib.seat_list)
            .iterator("link");
        while (seats.next()) |seat| {
            lib.teardown_seat(seat);
        }
    }
    
    c.zriver_control_v1_destroy(lib.river_control);
    c.zriver_status_manager_v1_destroy(
        lib.river_status_manager
    );
    c.zwlr_layer_shell_v1_destroy(lib.layer_shell);
    
    c.fcft_destroy(lib.font);
    c.fcft_fini();
    
    c.wl_shm_destroy(lib.shm);
    c.wl_compositor_destroy(lib.compositor);
    c.wl_registry_destroy(registry);
    c.wl_display_disconnect(lib.display);
}

