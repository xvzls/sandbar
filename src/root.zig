const std = @import("std");
pub const wl = @import("wl.zig");
pub const c = @cImport({
    @cDefine("_GNU_SOURCE", {});
    @cInclude("ctype.h");
    @cInclude("errno.h");
    @cInclude("fcft/fcft.h");
    @cInclude("fcntl.h");
    @cInclude("linux/input-event-codes.h");
    @cInclude("pixman.h");
    @cInclude("signal.h");
    @cInclude("stdbool.h");
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
    @cInclude("string.h");
    @cInclude("poll.h");
    @cInclude("sys/mman.h");
    @cInclude("sys/select.h");
    @cInclude("wayland-client.h");
    @cInclude("wayland-cursor.h");
    @cInclude("wayland-util.h");
    
    @cInclude("unistd.h");
    
    @cInclude("xdg-shell-protocol.h");
    @cInclude("wlr-layer-shell-unstable-v1-protocol.h");
    @cInclude("river-status-unstable-v1-protocol.h");
    @cInclude("river-control-unstable-v1-protocol.h");
});

pub const Bar = @import("Bar.zig");
pub const Seat = @import("Seat.zig");

pub
const wl_buffer_listener = @import("wl_buffer_listener.zig").object;

pub
const pointer_listener = @import("pointer_listener.zig").object;

pub
const output_listener = @import("output_listener.zig").object;

pub
const layer_surface_listener = @import("layer_surface_listener.zig").object;

pub
const seat_listener = @import("seat_listener.zig").object;

pub
const river_output_status_listener = @import("river_output_status_listener.zig").object;

pub
const river_seat_status_listener = @import("river_seat_status_listener.zig").object;

pub
const registry_listener = @import("registry_listener.zig").object;

pub
var active_fg_color = c.pixman_color_t{
    .red = 0xeeee,
    .green = 0xeeee,
    .blue = 0xeeee,
    .alpha = 0xffff,
};

pub
var active_bg_color = c.pixman_color_t{
    .red = 0x0000,
    .green = 0x5555,
    .blue = 0x7777,
    .alpha = 0xffff,
};

pub
var inactive_fg_color = c.pixman_color_t{
    .red = 0xbbbb,
    .green = 0xbbbb,
    .blue = 0xbbbb,
    .alpha = 0xffff,
};

pub
var inactive_bg_color = c.pixman_color_t{
    .red = 0x2222,
    .green = 0x2222,
    .blue = 0x2222,
    .alpha = 0xffff,
};

pub
var urgent_fg_color = c.pixman_color_t{
    .red = 0x2222,
    .green = 0x2222,
    .blue = 0x2222,
    .alpha = 0xffff,
};

pub
var urgent_bg_color = c.pixman_color_t{
    .red = 0xeeee,
    .green = 0xeeee,
    .blue = 0xeeee,
    .alpha = 0xffff,
};

pub
var title_fg_color = c.pixman_color_t{
    .red = 0xeeee,
    .green = 0xeeee,
    .blue = 0xeeee,
    .alpha = 0xffff,
};

pub
var title_bg_color = c.pixman_color_t{
    .red = 0x0000,
    .green = 0x5555,
    .blue = 0x7777,
    .alpha = 0xffff,
};


pub
var height: u32 = 0;

pub
var textpadding: u32 = 0;

pub
var vertical_padding: u32 = 1;

pub
var buffer_scale: u32 = 1;

pub
var layer_shell: ?*c.struct_zwlr_layer_shell_v1 = null;

pub
var display: ?*c.struct_wl_display = null;

pub
var river_status_manager: ?*c.struct_zriver_status_manager_v1 = null;

pub
const PROGRAM = "sandbar";

pub
fn show_bar(bar: *Bar) callconv(.c) void {
    bar.wl_surface = c.wl_compositor_create_surface(
        compositor
    ) orelse @panic("Could not create wl_surface");
    
    bar.layer_surface = c.zwlr_layer_shell_v1_get_layer_surface(
        layer_shell,
        bar.wl_surface,
        bar.wl_output,
        c.ZWLR_LAYER_SHELL_V1_LAYER_BOTTOM,
        PROGRAM,
    ) orelse @panic("Could not create layer_surface");
    
    _ = c.zwlr_layer_surface_v1_add_listener(
        bar.layer_surface,
        &layer_surface_listener,
        bar,
    );
    
    c.zwlr_layer_surface_v1_set_size(
        bar.layer_surface,
        0,
        bar.height / buffer_scale,
    );
    c.zwlr_layer_surface_v1_set_anchor(
        bar.layer_surface,
        @intCast(
            (if (bar.bottom)
                c.ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM
            else
                c.ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP
            )
                | c.ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT
                | c.ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT,
        )
    );
    c.zwlr_layer_surface_v1_set_exclusive_zone(
        bar.layer_surface,
        @intCast(bar.height / buffer_scale),
    );
    c.wl_surface_commit(bar.wl_surface);
    
    bar.hidden = false;
}

pub
fn hide_bar(bar: *Bar) void {
    c.zwlr_layer_surface_v1_destroy(bar.layer_surface);
    c.wl_surface_destroy(bar.wl_surface);
    
    bar.configured = false;
    bar.hidden = true;
}

pub
fn setup_bar(bar: *Bar) void {
    bar.height = height * buffer_scale;
    bar.textpadding = textpadding;
    bar.bottom = bottom;
    bar.hidden = hidden;
    
    bar.river_output_status = c.zriver_status_manager_v1_get_river_output_status(
        river_status_manager,
        bar.wl_output
    ) orelse @panic("Could not create river_output_status");
    
    _ = c.zriver_output_status_v1_add_listener(
        bar.river_output_status,
        &river_output_status_listener,
        bar,
    );
    
    if (!bar.hidden) {
        show_bar(bar);
    }
}

pub
fn setup_seat(seat: *Seat) void {
    seat.river_seat_status = c.zriver_status_manager_v1_get_river_seat_status(
        river_status_manager,
        seat.wl_seat,
    ) orelse @panic("Could not create river_seat_status");
    _ = c.zriver_seat_status_v1_add_listener(
        seat.river_seat_status,
        &river_seat_status_listener,
        seat,
    );
}

pub
fn teardown_bar(bar: *Bar) void {
    if (bar.title) |ptr| {
        c.free(ptr);
    }
    if (bar.layout) |ptr| {
        c.free(ptr);
    }
    if (bar.status) |ptr| {
        c.free(ptr);
    }
    if (bar.output_name) |ptr| {
        c.free(ptr);
    }
    
    c.zriver_output_status_v1_destroy(
        bar.river_output_status,
    );
    
    if (!bar.hidden) {
        c.zwlr_layer_surface_v1_destroy(
            bar.layer_surface,
        );
        c.wl_surface_destroy(bar.wl_surface);
    }
    
    c.wl_output_destroy(bar.wl_output);
    c.free(bar);
}

pub
fn teardown_seat(seat: *Seat) void {
    if (seat.mode) |ptr| {
        c.free(ptr);
    }
    
    c.zriver_seat_status_v1_destroy(
        seat.river_seat_status
    );
    
    if (seat.wl_pointer) |ptr| {
        c.wl_pointer_destroy(ptr);
    }
    
    c.wl_seat_destroy(seat.wl_seat);
    c.free(seat);
}

pub
fn draw_frame(bar: *Bar) c_int {
    // Allocate buffer to be attached to the surface
    const fd = allocate_shm_file(bar.bufsize);
    if (fd == -1) {
        return -1;
    }
    
    const raw_data = c.mmap(
        null,
        bar.bufsize,
        c.PROT_READ | c.PROT_WRITE,
        c.MAP_SHARED,
        fd,
        0,
    );
    if (raw_data == c.MAP_FAILED) {
        _ = c.close(fd);
        return -1;
    }
    const data: [*c]u32 = @ptrCast(@alignCast(
        raw_data
    ));
    
    const pool = c.wl_shm_create_pool(
        shm,
        fd,
        @intCast(bar.bufsize),
    );
    const buffer = c.wl_shm_pool_create_buffer(
        pool,
        0,
        @intCast(bar.width),
        @intCast(bar.height),
        @intCast(bar.stride),
        c.WL_SHM_FORMAT_ARGB8888,
    );
    _ = c.wl_buffer_add_listener(
        buffer,
        &wl_buffer_listener,
        null,
    );
    c.wl_shm_pool_destroy(pool);
    _ = c.close(fd);
    
    // Pixman image corresponding to main buffer
    const final = c.pixman_image_create_bits(
        c.PIXMAN_a8r8g8b8,
        @intCast(bar.width),
        @intCast(bar.height),
        data,
        @intCast(bar.width * 4),
    );
    
    // Text background and foreground layers
    const foreground = c.pixman_image_create_bits(
        c.PIXMAN_a8r8g8b8,
        @intCast(bar.width),
        @intCast(bar.height),
        null,
        @intCast(bar.width * 4),
    );
    const background = c.pixman_image_create_bits(
        c.PIXMAN_a8r8g8b8,
        @intCast(bar.width),
        @intCast(bar.height),
        null,
        @intCast(bar.width * 4),
    );
    
    // Draw on images
    var x: u32 = 0;
    const y: u32 = (
        bar.height +
        @as(u32, @intCast(font.?.ascent)) -
        @as(u32, @intCast(font.?.descent))
    ) / 2;
    const boxs: u32 = @intCast(
        @divFloor(font.?.height, 9)
    );
    const boxw: u32 = @intCast(
        @divFloor(font.?.height, 6) + 2
    );
    
    for (0 .. tags.len) |i| {
        const one: u32 = 1;
        const ii: u5 = @intCast(i);
        
        const active = (bar.mtags & one << ii) != 0;
        const occupied = (bar.ctags & one << ii) != 0;
        const urgent = (bar.urg & one << ii) != 0;
        
        if (
            hide_vacant and
            !active and
            !occupied and
            !urgent
        ) {
            continue;
        }
        
        const fg_color = if (urgent)
            &urgent_fg_color
        else if (active)
            &active_fg_color
        else
            &inactive_fg_color;
        const bg_color = if (urgent)
            &urgent_bg_color
        else if (active)
            &active_bg_color
        else
            &inactive_bg_color;
        
        if (!hide_vacant and occupied) {
            _ = c.pixman_image_fill_boxes(
                c.PIXMAN_OP_SRC,
                foreground,
                fg_color,
                1,
                &c.pixman_box32_t{
                    .x1 = @intCast(x + boxs),
                    .x2 = @intCast(x + boxs + boxw),
                    .y1 = @intCast(boxs),
                    .y2 = @intCast(boxs + boxw),
                },
            );
            
            if ((!bar.sel or !active) and boxw >= 3) {
                // Make box hollow
                _ = c.pixman_image_fill_boxes(
                    c.PIXMAN_OP_SRC,
                    foreground,
                    &std.mem.zeroes(c.pixman_color_t),
                    1,
                    &c.pixman_box32_t{
                        .x1 = @intCast(x + boxs + 1),
                        .x2 = @intCast(x + boxs + boxw - 1),
                        .y1 = @intCast(boxs + 1),
                        .y2 = @intCast(boxs + boxw - 1),
                    },
                );
            }
        }
        
        x = draw_text(
            tags[i],
            x,
            y,
            foreground,
            background,
            fg_color,
            bg_color,
            bar.width,
            bar.height,
            bar.textpadding,
            false,
        );
    }
    
    if (!no_mode) {
        var seats = wl.List(Seat)
            .from(&seat_list)
            .iterator("link");
        
        while (seats.next()) |seat| {
            if ((
                hide_normal_mode and
                (
                    seat.mode != null and
                    c.strcmp(seat.mode, "normal") != 0
                )
            ) or !hide_normal_mode) {
                x = draw_text(
                    seat.mode,
                    x,
                    y,
                    foreground,
                    background,
                    &inactive_fg_color,
                    &inactive_bg_color,
                    bar.width,
                    bar.height,
                    bar.textpadding,
                    false,
                );
            }
        }
    }
    
    if (!no_layout) {
        if ((bar.mtags & bar.ctags) != 0) {
            x = draw_text(
                bar.layout,
                x,
                y,
                foreground,
                background,
                &inactive_fg_color,
                &inactive_bg_color,
                bar.width,
                bar.height,
                bar.textpadding,
                false,
            );
        }
    }
    
    const status_width = text_width(
        bar.status,
        bar.width - x,
        bar.textpadding,
        true,
    );
    _ = draw_text(
        bar.status,
        bar.width - status_width,
        y,
        foreground,
        background,
        &inactive_fg_color,
        &inactive_bg_color,
        bar.width,
        bar.height,
        bar.textpadding,
        true,
    );
    
    if (!no_title) {
        x = draw_text(
            bar.title,
            x,
            y,
            foreground,
            background,
            if (bar.sel)
                &title_fg_color
            else
                &inactive_fg_color,
            if (bar.sel)
                &title_bg_color
            else
                &inactive_bg_color,
            bar.width - status_width,
            bar.height,
            bar.textpadding,
            false,
        );
    }
    
    _ = c.pixman_image_fill_boxes(
        c.PIXMAN_OP_SRC,
        background,
        if (bar.sel)
            &title_bg_color
        else
            &title_bg_color,
        1,
        &c.pixman_box32_t{
            .x1 = @intCast(x),
            .x2 = @intCast(bar.width - status_width),
            .y1 = 0,
            .y2 = @intCast(bar.height),
        },
    );
    
    // Draw background and foreground on bar
    c.pixman_image_composite32(
        c.PIXMAN_OP_OVER,
        background,
        null,
        final,
        0,
        0,
        0,
        0,
        0,
        0,
        @intCast(bar.width),
        @intCast(bar.height),
    );
    _ = c.pixman_image_composite32(
        c.PIXMAN_OP_OVER,
        foreground,
        null,
        final,
        0,
        0,
        0,
        0,
        0,
        0,
        @intCast(bar.width),
        @intCast(bar.height),
    );
    
    _ = c.pixman_image_unref(foreground);
    _ = c.pixman_image_unref(background);
    _ = c.pixman_image_unref(final);
    
    _ = c.munmap(data, bar.bufsize);
    
    c.wl_surface_set_buffer_scale(
        bar.wl_surface,
        @intCast(buffer_scale),
    );
    c.wl_surface_attach(bar.wl_surface, buffer, 0, 0);
    c.wl_surface_damage_buffer(
        bar.wl_surface,
        0,
        0,
        @intCast(bar.width),
        @intCast(bar.height),
    );
    c.wl_surface_commit(bar.wl_surface);
    
    return 0;
}

pub
fn parse_color(
    string: []const u8
) !c.pixman_color_t {
    const hex = std.mem.trimLeft(u8, string, "#");
    
    if (hex.len != 6 and hex.len != 8) {
        return error.InvalidHexSize;
    }
    
    var parsed = try std.fmt.parseInt(u32, hex, 16);
    var color: c.pixman_color_t = undefined;
    
    if (hex.len == 8) {
        color.alpha = @intCast((parsed & 0xff) * 0x101);
        parsed >>= 8;
    } else {
        color.alpha = 0xffff;
    }
    
    color.red = @intCast(
        ((parsed >> 16) & 0xff) * 0x101
    );
    color.green = @intCast(
        ((parsed >>  8) & 0xff) * 0x101
    );
    color.blue = @intCast(
        ((parsed >>  0) & 0xff) * 0x101
    );
    
    return color;
}

// Shared memory support function adapted from
// [wayland-book]
pub
fn allocate_shm_file(size: c_long) c_int {
    const fd = c.memfd_create("surface", c.MFD_CLOEXEC);
    if (fd == -1) {
        return -1;
    }
    
    var ret: c_int = 0;
    while (true) {
        ret = std.c.ftruncate(fd, size);
        if (ret != -1 or std.c._errno().* != c.EINTR) {
            break;
        }
    }
    
    if (ret == -1) {
        const err = c.close(fd);
        if (err != 0) {
            return err;
        }
        return -1;
    }
    
    return fd;
}

pub
var river_control: ?*c.struct_zriver_control_v1 = null;

pub
var tags: [][*c]u8 = undefined;

pub
var hidden = false;

pub
var bottom = false;

pub
var hide_vacant = false;

pub
var no_title = false;

pub
var no_status_commands = false;

pub
var no_mode = false;

pub
var no_layout = false;

pub
var hide_normal_mode = false;

pub
var compositor: ?*c.struct_wl_compositor = null;

pub
var shm: ?*c.struct_wl_shm = null;

pub
var bar_list: c.wl_list = undefined;

pub
var seat_list: c.wl_list = undefined;

pub inline
fn text_width(
    text: [*c]u8,
    maxwidth: u32,
    padding: u32,
    commands: bool,
) u32 {
    return draw_text(
        text,
        0,
        0,
        null,
        null,
        null,
        null,
        maxwidth,
        0,
        padding,
        commands,
    );
}

pub
var font: ?*c.fcft_font = null;

const Utf8 = enum(u32) {
    accept = 0,
    reject = 1,
};

const UTF8_D = [_]u8{
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, // 00..1f
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, // 20..3f
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, // 40..5f
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, // 60..7f
	1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9, // 80..9f
	7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7, // a0..bf
	8,8,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2, // c0..df
	0xa,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x4,0x3,0x3, // e0..ef
	0xb,0x6,0x6,0x6,0x5,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8, // f0..ff
	0x0,0x1,0x2,0x3,0x5,0x8,0x7,0x1,0x1,0x1,0x4,0x6,0x1,0x1,0x1,0x1, // s0..s0
	1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,0,1,0,1,1,1,1,1,1, // s1..s2
	1,2,1,1,1,1,1,2,1,2,1,1,1,1,1,1,1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1, // s3..s4
	1,2,1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1,1,1,1,1,1,3,1,3,1,1,1,1,1,1, // s5..s6
	1,3,1,1,1,1,1,3,1,3,1,1,1,1,1,1,1,3,1,1,1,1,1,1,1,1,1,1,1,1,1,1, // s7..s8
};

inline
fn utf8_decode(
    state: *u32,
    codep: *u32,
    byte: u8,
) u32 {
	const kind: u32 = @intCast(UTF8_D[byte]);
    
	codep.* = if (state.* != @intFromEnum(Utf8.accept))
		(byte & 0x3f) | (codep.* << 6)
	else
		(@as(u32, 0xff) >> @as(u5, @intCast(kind))) & (byte);
    
	state.* = @intCast(UTF8_D[256 + state.* * 16 + kind]);
    
	return state.*;
}

pub
fn draw_text(
    raw_text: [*c]const u8,
    raw_x: u32,
    y: u32,
    foreground: ?*c.pixman_image_t,
    background: ?*c.pixman_image_t,
    fg_color: ?*c.pixman_color_t,
    bg_color: ?*c.pixman_color_t,
    max_x: u32,
    buf_height: u32,
    padding: u32,
    commands: bool,
) u32 {
    var x = raw_x;
    if (raw_text == null or max_x == 0) {
        return x;
    }
    
    const text: []const u8 = std.mem.span(raw_text);
    if (text.len == 0) {
        return x;
    }
    
    const ix: u32 = x;
    var nx: u32 = x + padding;
    
    if (nx + padding >= max_x) {
        return x;
    }
    x = nx;
    
    const draw_fg = foreground != null and fg_color != null;
    const draw_bg = background != null and bg_color != null;
    
    var fg_fill: ?*c.pixman_image_t = if (draw_fg)
        c.pixman_image_create_solid_fill(fg_color)
    else
        null;
    var cur_bg_color: c.pixman_color_t = if (draw_bg)
        bg_color.?.*
    else
        std.mem.zeroes(c.pixman_color_t);
    
    var codepoint: u32 = 0;
    var state: u32 = @intFromEnum(Utf8.accept);
    var last_cp: u32 = 0;
    
    var p = raw_text;
    while (p.* != 0) : (p += 1) {
        // Check for inline ^ commands
        if (
            !no_status_commands and
            commands and
            state == @intFromEnum(Utf8.accept) and
            p.* == '^'
        ) {
            p += 1;
            if (p.* != '^') {
                // Parse color
                const start =
                    std.mem.indexOfScalar(u8, std.mem.span(p), '(')
                orelse
                    continue;
                const end =
                    std.mem.indexOfScalarPos(u8, std.mem.span(p), start, ')')
                orelse
                    continue;
                const ground = p[0 .. start];
                const hex = p[start + 1 .. end];
                
                if (std.mem.eql(u8, ground, "bg")) {
                    if (draw_bg) {
                        cur_bg_color = if (hex.len == 0)
                            bg_color.?.*
                        else
                            parse_color(hex)
                        catch |err|
                            @panic(@errorName(err));
                    }
                } else if (std.mem.eql(u8, ground, "fg")) {
                    if (draw_fg) {
                        var color: c.pixman_color_t = undefined;
                        var refresh = true;
                        
                        if (hex.len == 0) {
                            color = fg_color.?.*;
                        } else if (parse_color(
                            hex
                        )) |value| {
                            color = value;
                        } else |_| {
                            refresh = false;
                        }
                        
                        if (refresh) {
                            _ = c.pixman_image_unref(
                                fg_fill
                            );
                            fg_fill = c.pixman_image_create_solid_fill(&color);
                        }
                    }
                }
                
                p += end;
                continue;
            }
        }
        
        // Returns nonzero if more bytes are needed
        if (utf8_decode(&state, &codepoint, p.*) != 0) {
            continue;
        }
        // Turn off subpixel rendering, which
        // complicates things when mixed with alpha
        // channels
        const glyph = c.fcft_rasterize_char_utf32(
            font,
            codepoint,
            c.FCFT_SUBPIXEL_NONE,
        );
        if (glyph == null) {
            continue;
        }
        // Adjust x position based on kerning with
        // previous glyph
        var kern: c_long = 0;
        if (last_cp != 0) {
            _ = c.fcft_kerning(
                font,
                last_cp,
                codepoint,
                &kern,
                null,
            );
        }
        
        nx = @intCast(x + kern + glyph.*.advance.x);
        if (nx + padding > max_x) {
            break;
        }
        last_cp = codepoint;
        x += @intCast(kern);
        
        if (draw_fg) {
            // Detect and handle pre-rendered glyphs
            // (e.g. emoji)
            if (
                c.pixman_image_get_format(glyph.*.pix) ==
                c.PIXMAN_a8r8g8b8
            ) {
                // Only the alpha channel of the mask is
                // used, so we can use fgfill here to
                // blend prerendered glyphs with the
                // same opacity
                c.pixman_image_composite32(
                    c.PIXMAN_OP_OVER,
                    glyph.*.pix,
                    fg_fill,
                    foreground,
                    0,
                    0,
                    0,
                    0,
                    @intCast(x + @as(u32, @intCast(glyph.*.x))),
                    @intCast(y - @as(u32, @intCast(glyph.*.y))),
                    glyph.*.width,
                    glyph.*.height,
                );
            } else {
                // Applying the foreground color here
                // would mess up component alphas for
                // subpixel-rendered text, so we apply
                // it when blending.
                c.pixman_image_composite32(
                    c.PIXMAN_OP_OVER,
                    fg_fill,
                    glyph.*.pix,
                    foreground,
                    0,
                    0,
                    0,
                    0,
                    @intCast(x + @as(u32, @intCast(glyph.*.x))),
                    @intCast(y - @as(u32, @intCast(glyph.*.y))),
                    glyph.*.width,
                    glyph.*.height,
                );
            }
        }
        
        if (draw_bg) {
            _ = c.pixman_image_fill_boxes(
                c.PIXMAN_OP_OVER,
                background,
                &cur_bg_color,
                1,
                &c.pixman_box32_t{
                    .x1 = @intCast(x),
                    .x2 = @intCast(nx),
                    .y1 = 0,
                    .y2 = @intCast(buf_height),
                },
            );
        }
        
        // Increment pen position
        x = nx;
    }
    
    if (draw_fg) {
        _ = c.pixman_image_unref(fg_fill);
    }
    if (last_cp == 0) {
        return ix;
    }
    nx = x + padding;
    if (draw_bg) {
        // Fill padding background
        _ = c.pixman_image_fill_boxes(
            c.PIXMAN_OP_OVER,
            background,
            bg_color,
            1,
            &c.pixman_box32_t{
                .x1 = @intCast(ix),
                .x2 = @intCast(ix + padding),
                .y1 = 0,
                .y2 = @intCast(buf_height),
            },
        );
        _ = c.pixman_image_fill_boxes(
            c.PIXMAN_OP_OVER,
            background,
            bg_color,
            1,
            &c.pixman_box32_t{
                .x1 = @intCast(x),
                .x2 = @intCast(nx),
                .y1 = 0,
                .y2 = @intCast(buf_height),
            },
        );
    }
    
    return nx;
}


pub
var run_display = false;

fn set_status(bar: *Bar, data: ?[]const u8) void {
    if (bar.status) |ptr| {
        c.free(ptr);
    }
    bar.status = std.heap.c_allocator.dupeZ(
        u8,
        data.?
    ) catch |err| @panic(@errorName(err));
    
    bar.redraw = true;
}

fn set_visible(bar: *Bar, _: ?[]const u8) void {
    if (bar.hidden) {
        show_bar(bar);
    }
}

fn set_invisible(bar: *Bar, _: ?[]const u8) void {
    if (!bar.hidden) {
        hide_bar(bar);
    }
}

fn toggle_visibility(bar: *Bar, _: ?[]const u8) void {
    if (bar.hidden) {
        show_bar(bar);
    } else {
        hide_bar(bar);
    }
}

fn set_top(bar: *Bar, _: ?[]const u8) void {
    if (!bar.hidden) {
        c.zwlr_layer_surface_v1_set_anchor(
            bar.layer_surface,
            c.ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP
                | c.ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT
                | c.ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT
        );
        bar.redraw = true;
    }
    
    bar.bottom = false;
}

fn set_bottom(bar: *Bar, _: ?[]const u8) void {
    if (!bar.hidden) {
        c.zwlr_layer_surface_v1_set_anchor(
            bar.layer_surface,
            c.ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM
                | c.ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT
                | c.ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT
        );
        bar.redraw = true;
    }
    
    bar.bottom = true;
}

fn toggle_location(bar: *Bar, _: ?[]const u8) void {
    if (bar.bottom) {
        set_top(bar, null);
    } else {
        set_bottom(bar, null);
    }
}

inline
fn find_function(
    command: []const u8
) ?*const fn(
    bar: *Bar,
    data: ?[]const u8,
) void {
    const commands = .{
        .@"status" = set_status,
        .@"hide" = set_visible,
        .@"toggle-visibility" = toggle_location,
        .@"set-top" = set_top,
        .@"set-bottom" = set_bottom,
        .@"toggle-location" = toggle_location,
    };
    
    inline for (
        std.meta.fields(@TypeOf(commands))
    ) |field| {
        if (std.mem.eql(u8, field.name, command)) {
            return @field(commands, field.name);
        }
    }
    
    return null;
}

pub
fn read_stdin() c_int {
    const in = std.io.getStdIn().reader();
    var buffer: [8192]u8 = undefined;
    
    const line = in.readUntilDelimiter(
        &buffer,
        '\n',
    ) catch |err| @panic(@errorName(err));
    
    var words = std.mem.splitScalar(u8, line, ' ');
    const output =
        words.next()
    orelse
        @panic("no output param in input");
    const command =
        words.next()
    orelse
        @panic("no command param in input");
    const data = words.rest();
    
    var bars = wl.List(Bar)
        .from(&bar_list)
        .iterator("link");
    
    const function =
        find_function(command)
    orelse
        @panic("invalid command");
    
    if (std.mem.eql(u8, output, "all")) {
        while (bars.next()) |bar| {
            function(bar, data);
        }
    } else if (std.mem.eql(u8, output, "selected")) {
        while (bars.next()) |bar| {
            if (bar.sel) {
                function(bar, data);
            }
        }
    } else {
        while (bars.next()) |bar| {
            if (bar.output_name) |name| {
                if (std.mem.eql(
                    u8,
                    output,
                    std.mem.span(name),
                )) {
                    function(bar, data);
                }
            }
        }
    }
    
    return 1;
}

pub
fn event_loop() void {
    var fds = [_]c.struct_pollfd{
        .{
            .fd = c.wl_display_get_fd(display),
            .events = c.POLLIN,
            .revents = 0,
        },
        .{
            .fd = c.STDIN_FILENO,
            .events = c.POLLIN,
            .revents = 0,
        },
    };
    
    while (run_display) {
        _ = c.wl_display_flush(display);
        
        if (c.poll(&fds, 2, -1) < 0) {
            if (std.c._errno().* == c.EINTR) {
                continue;
            }
            @panic("bad poll");
        }
        
        if ((fds[0].revents & c.POLLIN) != 0) {
            if (c.wl_display_dispatch(display) == -1) {
                break;
            }
        }
        if ((fds[1].revents & c.POLLIN) != 0) {
            if (read_stdin() == -1) {
                break;
            }
        }
        
        var bars = wl.List(Bar)
            .from(&bar_list)
            .iterator("link");
        while (bars.next()) |bar| {
            if (bar.redraw) {
                if (!bar.hidden) {
                    _ = draw_frame(bar);
                }
                bar.redraw = false;
            }
        }
    }
}

pub
fn sig_handler(signal: c_int) callconv(.c) void {
    if (
        signal == c.SIGINT or
        signal == c.SIGHUP or
        signal == c.SIGTERM
    ) {
        run_display = false;
    }
}

