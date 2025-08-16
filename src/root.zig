const std = @import("std");
const wl = @import("wl.zig");
pub const c = @cImport({
    @cInclude("sandbar.h");
});

pub export
const wl_buffer_listener = @import("wl_buffer_listener.zig").object;

pub export
const pointer_listener = @import("pointer_listener.zig").object;

pub export
const output_listener = @import("output_listener.zig").object;

pub export
const layer_surface_listener = @import("layer_surface_listener.zig").object;

pub export
const seat_listener = @import("seat_listener.zig").object;

pub export
const river_output_status_listener = @import("river_output_status_listener.zig").object;

pub export
const river_seat_status_listener = @import("river_seat_status_listener.zig").object;

pub export
const registry_listener = @import("registry_listener.zig").object;

pub export
var active_fg_color = c.pixman_color_t{
    .red = 0xeeee,
    .green = 0xeeee,
    .blue = 0xeeee,
    .alpha = 0xffff,
};

pub export
var active_bg_color = c.pixman_color_t{
    .red = 0x0000,
    .green = 0x5555,
    .blue = 0x7777,
    .alpha = 0xffff,
};

pub export
var inactive_fg_color = c.pixman_color_t{
    .red = 0xbbbb,
    .green = 0xbbbb,
    .blue = 0xbbbb,
    .alpha = 0xffff,
};

pub export
var inactive_bg_color = c.pixman_color_t{
    .red = 0x2222,
    .green = 0x2222,
    .blue = 0x2222,
    .alpha = 0xffff,
};

pub export
var urgent_fg_color = c.pixman_color_t{
    .red = 0x2222,
    .green = 0x2222,
    .blue = 0x2222,
    .alpha = 0xffff,
};

pub export
var urgent_bg_color = c.pixman_color_t{
    .red = 0xeeee,
    .green = 0xeeee,
    .blue = 0xeeee,
    .alpha = 0xffff,
};

pub export
var title_fg_color = c.pixman_color_t{
    .red = 0xeeee,
    .green = 0xeeee,
    .blue = 0xeeee,
    .alpha = 0xffff,
};

pub export
var title_bg_color = c.pixman_color_t{
    .red = 0x0000,
    .green = 0x5555,
    .blue = 0x7777,
    .alpha = 0xffff,
};


pub export
var height: u32 = 0;

pub export
var textpadding: u32 = 0;

pub export
var vertical_padding: u32 = 1;

pub export
var buffer_scale: u32 = 1;

pub export
var layer_shell: ?*c.struct_zwlr_layer_shell_v1 = null;

pub export
var display: ?*c.struct_wl_display = null;

pub export
var river_status_manager: ?*c.struct_zriver_status_manager_v1 = null;

pub export
var fontstr: [*c]const u8 = "monospace:size=16";

pub export
const PROGRAM = "sandbar";

pub export
fn show_bar(bar: *c.Bar) callconv(.c) void {
    bar.wl_surface = c.wl_compositor_create_surface(
        compositor
    );
    if (bar.wl_surface == null) {
        @panic("Could not create wl_surface");
    }
    
    bar.layer_surface = c.zwlr_layer_shell_v1_get_layer_surface(
        layer_shell,
        bar.wl_surface,
        bar.wl_output,
        c.ZWLR_LAYER_SHELL_V1_LAYER_BOTTOM,
        PROGRAM,
    );
    if (bar.layer_surface == null) {
        @panic("Could not create layer_surface");
    }
    
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

pub export
fn hide_bar(bar: *c.Bar) void {
    c.zwlr_layer_surface_v1_destroy(bar.layer_surface);
    c.wl_surface_destroy(bar.wl_surface);
    
    bar.configured = false;
    bar.hidden = true;
}

pub export
fn setup_bar(bar: *c.Bar) void {
    bar.height = height * buffer_scale;
    bar.textpadding = textpadding;
    bar.bottom = bottom;
    bar.hidden = hidden;
    
    bar.river_output_status = c.zriver_status_manager_v1_get_river_output_status(
        river_status_manager,
        bar.wl_output
    );
    if (bar.river_output_status == null) {
        @panic("Could not create river_output_status");
    }
    
    _ = c.zriver_output_status_v1_add_listener(
        bar.river_output_status,
        &river_output_status_listener,
        bar,
    );
    
    if (!bar.hidden) {
        show_bar(bar);
    }
}

pub export
fn setup_seat(seat: *c.Seat) void {
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

pub export
fn teardown_bar(bar: *c.Bar) void {
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

pub export
fn teardown_seat(seat: *c.Seat) void {
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

pub export
fn draw_frame(
    bar: *c.Bar,
) c_int {
    // Allocate buffer to be attached to the surface
    const fd = c.allocate_shm_file(bar.bufsize);
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
    
    for (0 .. tags_l) |i| {
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
        
        x = c.draw_text(
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
        var seats = wl.List(c.Seat)
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
                x = c.draw_text(
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
            x = c.draw_text(
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

pub export
fn parse_color(
    raw_string: [*c]const u8,
    color: *c.pixman_color_t,
) c_int {
    const string = std.mem.trimLeft(
        u8,
        std.mem.span(raw_string),
        "#",
    );
    
    if (
        (string.len != 6 and string.len != 8) or
        c.isxdigit(string[0]) == 0 or
        c.isxdigit(string[1]) == 0
    ) {
        return -1;
    }
    
    var parsed =
        std.fmt.parseInt(u32, string, 16)
    catch
        return -1;
    
    if (string.len == 8) {
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
    
    return 0;
}

// Shared memory support function adapted from
// [wayland-book]
pub export
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

pub export
var river_control: ?*c.struct_zriver_control_v1 = null;

pub export
var tags: [*c][*c]u8 = undefined;

pub export
var tags_l: u32 = 0;

pub export
var hidden = false;

pub export
var bottom = false;

pub export
var hide_vacant = false;

pub export
var no_title = false;

pub export
var no_status_commands = false;

pub export
var no_mode = false;

pub export
var no_layout = false;

pub export
var hide_normal_mode = false;

pub export
var compositor: ?*c.struct_wl_compositor = null;

pub export
var shm: ?*c.struct_wl_shm = null;

pub export
var bar_list: c.wl_list = undefined;

pub export
var seat_list: c.wl_list = undefined;

pub inline fn text_width(
    text: [*c]u8,
    maxwidth: u32,
    padding: u32,
    commands: bool,
) u32 {
    return c.draw_text(
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

pub export
var font: ?*c.fcft_font = null;

pub export
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
    var state: u32 = c.UTF8_ACCEPT;
    var last_cp: u32 = 0;
    
    var p = raw_text;
    while (p.* != 0) : (p += 1) {
        // Check for inline ^ commands
        if (
            !no_status_commands and
            commands and
            state == c.UTF8_ACCEPT and
            p.* == '^'
        ) {
            p += 1;
            if (p.* != '^') {
                // Parse color
                var arg = c.strchr(p, '(');
                const end = c.strchr(arg + 1, ')');
                if (arg == null or end == null) {
                    continue;
                }
                arg.* = 0;
                end.* = 0;
                arg += 1;
                
                if (c.strcmp(p, "bg") == 0) {
                    if (draw_bg) {
                        if (arg.* == 0) {
                            cur_bg_color = bg_color.?.*;
                        } else {
                            _ = parse_color(
                                arg,
                                &cur_bg_color,
                            );
                        }
                    }
                } else if (c.strcmp(p, "fg") == 0) {
                    if (draw_fg) {
                        var color: c.pixman_color_t = undefined;
                        var refresh = true;
                        if (arg.* == 0) {
                            color = fg_color.?.*;
                        } else if (parse_color(
                            arg,
                            &color,
                        ) == -1) {
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
                
                // Restore string for later redraws
                arg -= 1;
                arg.* = '(';
                end.* = ')';
                p = end;
                continue;
            }
        }
        
        // Returns nonzero if more bytes are needed
        if (c.utf8decode(&state, &codepoint, p.*) != 0) {
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


pub export
var run_display = false;

pub export
fn set_status(bar: *c.Bar, data: [*c]const u8) void {
    if (bar.status) |ptr| {
        c.free(ptr);
    }
    bar.status = c.strdup(data) orelse @panic("strdup");
    
    bar.redraw = true;
}

pub export
fn set_visible(bar: *c.Bar, _: [*c]const u8) void {
    if (bar.hidden) {
        show_bar(bar);
    }
}

pub export
fn set_invisible(bar: *c.Bar, _: [*c]const u8) void {
    if (!bar.hidden) {
        hide_bar(bar);
    }
}

pub export
fn toggle_visibility(bar: *c.Bar, _: [*c]const u8) void {
    if (bar.hidden) {
        show_bar(bar);
    } else {
        hide_bar(bar);
    }
}

pub export
fn set_top(bar: *c.Bar, _: [*c]const u8) void {
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

pub export
fn set_bottom(bar: *c.Bar, _: [*c]const u8) void {
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

pub export
fn toggle_location(bar: *c.Bar, _: [*c]const u8) void {
    if (bar.bottom) {
        set_top(bar, null);
    } else {
        set_bottom(bar, null);
    }
}

pub export
fn debug_string(
    chars: [*c]const u8,
    size: isize
) void {
    var string: []const u8 = undefined;
    string.len = @intCast(size);
    string.ptr = chars;
    
    std.debug.print("debug: '{s}'", .{ string });
}

inline
fn find_function(
    command: []const u8
) ?*const fn(
    bar: *c.Bar,
    data: [*c]const u8,
) callconv(.c) void {
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

pub export
fn read_stdin() c_int {
    const in = std.io.getStdIn().reader();
    var buffer: [8192]u8 = undefined;
    
    const line = in.readUntilDelimiter(
        &buffer,
        '\n',
    ) catch |err| @panic(@errorName(err));
    std.debug.print("line: {s}\n", .{ line });
    
    var words = std.mem.splitScalar(u8, line, ' ');
    const output =
        words.next()
    orelse
        @panic("no output param in input");
    const command =
        words.next()
    orelse
        @panic("no command param in input");
    const dataOld = words.rest();
    const data = c.strndup(@ptrCast(dataOld), dataOld.len);
    
    var bars = wl.List(c.Bar)
        .from(&bar_list)
        .iterator("link");
    
    const function = find_function(command) orelse @panic("invalid command");
    
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

