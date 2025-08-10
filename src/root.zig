const std = @import("std");
pub const c = @cImport({
    @cInclude("sandbar.h");
});

export
var height: u32 = 0;

export
var textpadding: u32 = 0;

export
var vertical_padding: u32 = 1;

export
var buffer_scale: u32 = 1;

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
    
    var pos: ?*c.wl_list = seat_list.next;
    
    while (pos != &seat_list) : (pos = pos.?.next) {
        const it: *c.Seat = @fieldParentPtr(
            "link",
            pos.?,
        );
        
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

