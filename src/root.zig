const std = @import("std");
const wl = @import("wl.zig");
pub const c = @cImport({
    @cInclude("sandbar.h");
});


export
var active_fg_color = c.pixman_color_t{
    .red = 0xeeee,
    .green = 0xeeee,
    .blue = 0xeeee,
    .alpha = 0xffff,
};

export
var active_bg_color = c.pixman_color_t{
    .red = 0x0000,
    .green = 0x5555,
    .blue = 0x7777,
    .alpha = 0xffff,
};

export
var inactive_fg_color = c.pixman_color_t{
    .red = 0xbbbb,
    .green = 0xbbbb,
    .blue = 0xbbbb,
    .alpha = 0xffff,
};

export
var inactive_bg_color = c.pixman_color_t{
    .red = 0x2222,
    .green = 0x2222,
    .blue = 0x2222,
    .alpha = 0xffff,
};

export
var urgent_fg_color = c.pixman_color_t{
    .red = 0x2222,
    .green = 0x2222,
    .blue = 0x2222,
    .alpha = 0xffff,
};

export
var urgent_bg_color = c.pixman_color_t{
    .red = 0xeeee,
    .green = 0xeeee,
    .blue = 0xeeee,
    .alpha = 0xffff,
};

export
var title_fg_color = c.pixman_color_t{
    .red = 0xeeee,
    .green = 0xeeee,
    .blue = 0xeeee,
    .alpha = 0xffff,
};

export
var title_bg_color = c.pixman_color_t{
    .red = 0x0000,
    .green = 0x5555,
    .blue = 0x7777,
    .alpha = 0xffff,
};


export
var height: u32 = 0;

export
var textpadding: u32 = 0;

export
var vertical_padding: u32 = 1;

export
var buffer_scale: u32 = 1;

export
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

fn wl_buffer_release(
    _: ?*anyopaque,
    wl_buffer: ?*c.struct_wl_buffer,
) callconv(.c) void {
    // Sent by the compositor when it's no longer using
    // this buffer
    c.wl_buffer_destroy(wl_buffer);
}

export
const wl_buffer_listener = c.struct_wl_buffer_listener{
    .release = wl_buffer_release,
};

export
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
export
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

export
var river_control: ?*c.struct_zriver_control_v1 = null;

export
var tags: [*c][*c]u8 = undefined;

export
var tags_l: u32 = 0;

export
var hidden = false;

export
var bottom = false;

export
var hide_vacant = false;

export
var no_title = false;

export
var no_status_commands = false;

export
var no_mode = false;

export
var no_layout = false;

export
var hide_normal_mode = false;

export
var compositor: ?*c.struct_wl_compositor = null;

export
var shm: ?*c.struct_wl_shm = null;

export
var cursor_image: ?*c.struct_wl_cursor_image = null;

export
var cursor_surface: ?*c.struct_wl_surface = null;

export
var bar_list: c.wl_list = undefined;

export
var seat_list: c.wl_list = undefined;

inline fn text_width(
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

export
var font: ?*c.fcft_font = null;

export
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

fn pointer_enter(
    data: ?*anyopaque,
    pointer: ?*c.struct_wl_pointer,
    serial: u32,
    _: ?*c.struct_wl_surface,
    _: c.wl_fixed_t,
    _: c.wl_fixed_t,
) callconv(.c) void {
    var seat: *c.Seat = @alignCast(@ptrCast(data.?));
    
    seat.hovering = true;
    
    if (cursor_image == null) {
        const cursor_theme = c.wl_cursor_theme_load(
            null,
            @intCast(24 * buffer_scale),
            shm
        ).?;
        cursor_image = c.wl_cursor_theme_get_cursor(
            cursor_theme,
            "left_ptr",
        ).*.images[0];
        cursor_surface = c.wl_compositor_create_surface(
            compositor,
        );
        c.wl_surface_set_buffer_scale(
            cursor_surface,
            @intCast(buffer_scale),
        );
        c.wl_surface_attach(
            cursor_surface,
            c.wl_cursor_image_get_buffer(cursor_image),
            0,
            0,
        );
        c.wl_surface_commit(cursor_surface);
    }
    
    c.wl_pointer_set_cursor(
        pointer,
        serial,
        cursor_surface,
        @intCast(cursor_image.?.hotspot_x),
        @intCast(cursor_image.?.hotspot_y),
    );
}

fn pointer_leave(
    data: ?*anyopaque,
    _: ?*c.struct_wl_pointer,
    _: u32,
    _: ?*c.struct_wl_surface,
) callconv(.c) void {
    var seat: *c.Seat = @alignCast(@ptrCast(data.?));
    
    seat.hovering = false;
}

fn pointer_button(
    data: ?*anyopaque,
    _: ?*c.struct_wl_pointer,
    _: u32,
    _: u32,
    button: u32,
    state: u32,
) callconv(.c) void {
    var seat: *c.Seat = @alignCast(@ptrCast(data.?));
    
    seat.pointer_button = if (
        state == c.WL_POINTER_BUTTON_STATE_PRESSED
    ) button else 0;
}

fn pointer_motion(
    data: ?*anyopaque,
    _: ?*c.struct_wl_pointer,
    _: u32,
    surface_x: c.wl_fixed_t,
    surface_y: c.wl_fixed_t,
) callconv(.c) void {
    var seat: *c.Seat = @alignCast(@ptrCast(data.?));
    
    seat.pointer_x = @intCast(
        c.wl_fixed_to_int(surface_x)
    );
    seat.pointer_y = @intCast(
        c.wl_fixed_to_int(surface_y)
    );
}

fn pointer_frame(
    data: ?*anyopaque,
    _: ?*c.struct_wl_pointer,
) callconv(.c) void {
    var seat: *c.Seat = @alignCast(@ptrCast(data.?));
    
    if (
        seat.pointer_button == 0 or
        seat.bar == null or
        !seat.hovering
    ) {
        return;
    }
    
    const button = seat.pointer_button;
    seat.pointer_button = 0;
    
    var i: u5 = 0;
    var x: u32 = 0;
    const one: u32 = 1;
    while (true) {
        if (hide_vacant) {
            const active = (
                seat.bar.*.mtags & one << i
            ) != 0;
            const occupied = (
                seat.bar.*.ctags & one << i
            ) != 0;
            const urgent = (
                seat.bar.*.urg & one << i
            ) != 0;
            if (!active and !occupied and !urgent) {
                continue;
            }
        }
        
        x += text_width(
            tags[@intCast(i)],
            seat.bar.*.width - x,
            seat.bar.*.textpadding,
            false,
        ) / buffer_scale;
        
        if (seat.pointer_x >= x){
            i += 1;
            if (i < tags_l) {
                continue;
            }
        }
        
        break;
    }
    
    if (i < tags_l) {
        // Clicked on tags
        const cmd = switch (button) {
            c.BTN_LEFT => "set-focused-tags",
            c.BTN_MIDDLE => "toggle-focused-tags",
            c.BTN_RIGHT => "set-view-tags",
            else => return,
        };
        
        c.zriver_control_v1_add_argument(
            river_control,
            cmd,
        );
        
        var buf: [32]u8 = undefined;
        _ = c.snprintf(
            @ptrCast(&buf),
            @sizeOf(@TypeOf(buf)),
            "%d",
            one << i,
        );
        c.zriver_control_v1_add_argument(
            river_control,
            @ptrCast(&buf),
        );
        _ = c.zriver_control_v1_run_command(
            river_control,
            seat.wl_seat,
        );
        return;
    }
    
    if (true) {
        return;
    }
    
    var seats = wl.List(c.Seat)
        .from(&seat_list)
        .iterator("link");
    
    while (seats.next()) |it| {
        x += text_width(
            it.mode,
            seat.bar.*.width - x,
            seat.bar.*.textpadding,
            false,
        ) / buffer_scale;
        
        if (seat.pointer_x < x) {
            // Clicked on mode
            const mode = switch (button) {
                c.BTN_LEFT => "normal",
                c.BTN_RIGHT => "passthrough",
                else => return,
            };
            
            c.zriver_control_v1_add_argument(
                river_control,
                "enter-mode",
            );
            c.zriver_control_v1_add_argument(
                river_control,
                mode,
            );
            _ = c.zriver_control_v1_run_command(
                river_control,
                it.wl_seat,
            );
            return;
        }
    }
    
    // TODO: run custom commands upon clicking layout,
    // title, status
    if ((seat.bar.*.mtags & seat.bar.*.ctags) != 0) {
        x += text_width(
            seat.bar.*.layout,
            seat.bar.*.width - x,
            seat.bar.*.textpadding,
            false,
        ) / buffer_scale;
        if (seat.pointer_x < x) {
            // Clicked on layout
            return;
        }
    }
    
    if (
        seat.pointer_x <
        seat.bar.*.width / buffer_scale - text_width(
            seat.bar.*.status,
            seat.bar.*.width - x,
            seat.bar.*.textpadding,
            true,
        ) / buffer_scale
    ) {
        // Clicked on title
        return;
    }
    
    // Clicked on status
}

export
const pointer_listener = c.struct_wl_pointer_listener{
    .button = pointer_button,
    .enter = pointer_enter,
    .frame = pointer_frame,
    .leave = pointer_leave,
    .motion = pointer_motion,
};

fn output_description(
    _: ?*anyopaque,
    _: ?*c.struct_wl_output,
    _: [*c]const u8,
) callconv(.c) void {
}

fn output_done(
    _: ?*anyopaque,
    _: ?*c.struct_wl_output,
) callconv(.c) void {
}

fn output_geometry(
    _: ?*anyopaque,
    _: ?*c.struct_wl_output,
    _: i32,
    _: i32,
    _: i32,
    _: i32,
    _: i32,
    _: [*c]const u8,
    _: [*c]const u8,
    _: i32,
) callconv(.c) void {
}

fn output_mode(
    _: ?*anyopaque,
    _: ?*c.struct_wl_output,
    _: u32,
    _: i32,
    _: i32,
    _: i32,
) callconv(.c) void {
}

fn output_name(
    data: ?*anyopaque,
    _: ?*c.struct_wl_output,
    name: [*c]const u8,
) callconv(.c) void {
    var bar: *c.Bar = @alignCast(@ptrCast(data.?));
    
    if (bar.output_name != null) {
        c.free(bar.output_name);
    }
    
    bar.output_name = c.strdup(name);
    if (bar.output_name == null) {
        std.debug.print("strdup: {s}\n", .{
            c.strerror(std.c._errno().*),
        });
        std.process.exit(1);
    }
}

fn output_scale(
    _: ?*anyopaque,
    _: ?*c.struct_wl_output,
    _: i32,
) callconv(.c) void {
}

export
const output_listener = c.struct_wl_output_listener{
    .description = output_description,
    .done = output_done,
    .geometry = output_geometry,
    .mode = output_mode,
    .name = output_name,
    .scale = output_scale,
};

export
var run_display = false;

// Layer-surface setup adapted from layer-shell example
// in [wlroots]
fn layer_surface_configure(
    data: ?*anyopaque,
    surface: ?*c.struct_zwlr_layer_surface_v1,
    serial: u32,
    raw_w: u32,
    raw_h: u32,
) callconv(.c) void {
    c.zwlr_layer_surface_v1_ack_configure(
        surface,
        serial,
    );
    
    var bar: *c.Bar = @ptrCast(@alignCast(data));
    
    const w = raw_w * buffer_scale;
    const h = raw_h * buffer_scale;
    
    if (
        bar.configured and
        w == bar.width and
        h == bar.height
    ) {
        return;
    }
    
    bar.width = w;
    bar.height = h;
    bar.stride = bar.width * 4;
    bar.bufsize = bar.stride * bar.height;
    bar.configured = true;
    
    _ = c.draw_frame(bar);
}

fn layer_surface_closed(
    _: ?*anyopaque,
    _: ?*c.struct_zwlr_layer_surface_v1,
) callconv(.c) void {
    run_display = false;
}

export
const layer_surface_listener = c.struct_zwlr_layer_surface_v1_listener{
    .configure = layer_surface_configure,
    .closed = layer_surface_closed,
};


fn seat_capabilities(
    data: ?*anyopaque,
    _: ?*c.struct_wl_seat,
    capabilities: u32,
) callconv(.c) void {
    var seat: *c.Seat = @ptrCast(@alignCast(data.?));
    
    const has_pointer = (capabilities & c.WL_SEAT_CAPABILITY_POINTER) != 0;
    if (has_pointer and seat.wl_pointer == null) {
        seat.wl_pointer = c.wl_seat_get_pointer(
            seat.wl_seat,
        );
        _ = c.wl_pointer_add_listener(
            seat.wl_pointer,
            &pointer_listener,
            seat,
        );
    } else if (
        !has_pointer and
        seat.wl_pointer != null
    ) {
        c.wl_pointer_destroy(seat.wl_pointer);
        seat.wl_pointer = null;
    }
}

fn seat_name(
    _: ?*anyopaque,
    _: ?*c.struct_wl_seat,
    _: [*c]const u8,
) callconv(.c) void {
}

export
const seat_listener = c.struct_wl_seat_listener{
    .capabilities = seat_capabilities,
    .name = seat_name,
};

fn river_output_status_focused_tags(
    data: ?*anyopaque,
    _: ?*c.struct_zriver_output_status_v1,
    n_tags: u32,
) callconv(.c) void {
    var bar: *c.Bar = @ptrCast(@alignCast(data.?));
    
    bar.mtags = n_tags;
    bar.redraw = true;
}

fn river_output_status_urgent_tags(
    data: ?*anyopaque,
    _: ?*c.struct_zriver_output_status_v1,
    n_tags: u32,
) callconv(.c) void {
    var bar: *c.Bar = @ptrCast(@alignCast(data.?));
    
    bar.urg = n_tags;
    bar.redraw = true;
}

fn river_output_status_view_tags(
    data: ?*anyopaque,
    _: ?*c.struct_zriver_output_status_v1,
    wl_array: ?*c.struct_wl_array,
) callconv(.c) void {
    var bar: *c.Bar = @ptrCast(@alignCast(data.?));
    
    bar.ctags = 0;
    
    for (@as(
        *wl.Array(u32),
        @ptrCast(wl_array.?)
    ).items()) |item| {
        bar.ctags |= item;
    }
    bar.redraw = true;
}

fn river_output_status_layout_name(
    data: ?*anyopaque,
    _: ?*c.struct_zriver_output_status_v1,
    name: [*c]const u8,
) callconv(.c) void {
    var bar: *c.Bar = @ptrCast(@alignCast(data.?));
    
    if (bar.layout != null) {
        c.free(bar.layout);
    }
    
    bar.layout = c.strdup(name);
    if (bar.layout == null) {
        std.debug.print("strdup: {s}\n", .{
            c.strerror(std.c._errno().*),
        });
        std.process.exit(1);
    }
    
    bar.redraw = true;
}

fn river_output_status_layout_name_clear(
    data: ?*anyopaque,
    _: ?*c.struct_zriver_output_status_v1,
) callconv(.c) void {
    var bar: *c.Bar = @ptrCast(@alignCast(data.?));
    
    if (bar.layout != null) {
        c.free(bar.layout);
        bar.layout = null;
    }
}

export
const river_output_status_listener = c.struct_zriver_output_status_v1_listener{
    .focused_tags = river_output_status_focused_tags,
    .urgent_tags = river_output_status_urgent_tags,
    .view_tags = river_output_status_view_tags,
    .layout_name = river_output_status_layout_name,
    .layout_name_clear = river_output_status_layout_name_clear,
};


fn river_seat_status_focused_output(
    data: ?*anyopaque,
    _: ?*c.struct_zriver_seat_status_v1,
    wl_output: ?*c.struct_wl_output,
) callconv(.c) void {
    var seat: *c.Seat = @ptrCast(@alignCast(data.?));
    
    var pos: ?*c.wl_list = bar_list.next;
    while (pos != &bar_list) : (pos = pos.?.next) {
        const bar: *c.Bar = @fieldParentPtr(
            "link",
            pos.?,
        );
        if (bar.wl_output == wl_output) {
            seat.bar = bar;
            seat.bar.*.sel = true;
            seat.bar.*.redraw = true;
            return;
        }
    }
    
    seat.bar = null;
}

fn river_seat_status_unfocused_output(
    data: ?*anyopaque,
    _: ?*c.struct_zriver_seat_status_v1,
    _: ?*c.struct_wl_output,
) callconv(.c) void {
    var seat: *c.Seat = @ptrCast(@alignCast(data.?));
    const bar: *c.Bar = seat.bar orelse return;
    
    bar.sel = false;
    bar.redraw = true;
    seat.bar = null;
}

fn river_seat_status_focused_view(
    data: ?*anyopaque,
    _: ?*c.struct_zriver_seat_status_v1,
    title: [*c]const u8,
) callconv(.c) void {
    if (no_title) {
        return;
    }
    
    const seat: *c.Seat = @ptrCast(@alignCast(data.?));
    if (seat.bar == null) {
        return;
    }
    
    if (seat.bar.*.title != null) {
        c.free(seat.bar.*.title);
    }
    
    seat.bar.*.title = c.strdup(title);
    if (seat.bar.*.title == null) {
        std.debug.print("strdup: {s}\n", .{
            c.strerror(std.c._errno().*),
        });
        std.process.exit(1);
    }
    seat.bar.*.redraw = true;
}

fn river_seat_status_mode(
    data: ?*anyopaque,
    _: ?*c.struct_zriver_seat_status_v1,
    name: [*c]const u8,
) callconv(.c) void {
    var seat: *c.Seat = @ptrCast(@alignCast(data.?));
    
    if (seat.mode != null) {
        c.free(seat.mode);
    }
    
    seat.mode = c.strdup(name);
    if (seat.mode == null) {
        std.debug.print("strdup: {s}\n", .{
            c.strerror(std.c._errno().*),
        });
        std.process.exit(1);
    }
    
    var bars = *wl.List(c.Bar)
        .from(&bar_list)
        .iterator("link");
    
    while (bars.next()) |bar| {
        std.debug.print("got em bars\n", .{});
        bar.redraw = true;
    }
}

export
const river_seat_status_listener = c.struct_zriver_seat_status_v1_listener{
    .focused_output = river_seat_status_focused_output,
    .unfocused_output = river_seat_status_unfocused_output,
    .focused_view = river_seat_status_focused_view,
    .mode = river_seat_status_mode,
};

