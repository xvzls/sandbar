const lib = @import("root.zig");
const std = @import("std");
const wl = @import("wl.zig");
const c = @cImport({
    @cInclude("sandbar.h");
});

var cursor_image: ?*c.struct_wl_cursor_image = null;
var cursor_surface: ?*c.struct_wl_surface = null;

fn enter(
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
            @intCast(24 * lib.buffer_scale),
            lib.shm
        ).?;
        cursor_image = c.wl_cursor_theme_get_cursor(
            cursor_theme,
            "left_ptr",
        ).*.images[0];
        cursor_surface = c.wl_compositor_create_surface(
            lib.compositor,
        );
        c.wl_surface_set_buffer_scale(
            cursor_surface,
            @intCast(c.buffer_scale),
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

fn leave(
    data: ?*anyopaque,
    _: ?*c.struct_wl_pointer,
    _: u32,
    _: ?*c.struct_wl_surface,
) callconv(.c) void {
    var seat: *c.Seat = @alignCast(@ptrCast(data.?));
    
    seat.hovering = false;
}

fn button(
    data: ?*anyopaque,
    _: ?*c.struct_wl_pointer,
    _: u32,
    _: u32,
    code: u32,
    state: u32,
) callconv(.c) void {
    var seat: *c.Seat = @alignCast(@ptrCast(data.?));
    
    seat.pointer_button = if (
        state == c.WL_POINTER_BUTTON_STATE_PRESSED
    ) code else 0;
}

fn motion(
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

fn frame(
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
    
    const pointer_button = seat.pointer_button;
    seat.pointer_button = 0;
    
    var i: u5 = 0;
    var x: u32 = 0;
    const one: u32 = 1;
    while (true) {
        if (c.hide_vacant) {
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
        
        x += lib.text_width(
            lib.tags[@intCast(i)],
            seat.bar.*.width - x,
            seat.bar.*.textpadding,
            false,
        ) / lib.buffer_scale;
        
        if (seat.pointer_x >= x){
            i += 1;
            if (i < lib.tags_l) {
                continue;
            }
        }
        
        break;
    }
    
    if (i < lib.tags_l) {
        // Clicked on tags
        const cmd = switch (pointer_button) {
            c.BTN_LEFT => "set-focused-tags",
            c.BTN_MIDDLE => "toggle-focused-tags",
            c.BTN_RIGHT => "set-view-tags",
            else => return,
        };
        
        c.zriver_control_v1_add_argument(
            c.river_control,
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
            c.river_control,
            @ptrCast(&buf),
        );
        _ = c.zriver_control_v1_run_command(
            c.river_control,
            seat.wl_seat,
        );
        return;
    }
    
    if (true) {
        return;
    }
    
    var seats = wl.List(c.Seat)
        .from(&lib.seat_list)
        .iterator("link");
    
    while (seats.next()) |it| {
        x += lib.text_width(
            it.mode,
            seat.bar.*.width - x,
            seat.bar.*.textpadding,
            false,
        ) / lib.buffer_scale;
        
        if (seat.pointer_x < x) {
            // Clicked on mode
            const mode = switch (pointer_button) {
                c.BTN_LEFT => "normal",
                c.BTN_RIGHT => "passthrough",
                else => return,
            };
            
            c.zriver_control_v1_add_argument(
                lib.river_control,
                "enter-mode",
            );
            c.zriver_control_v1_add_argument(
                lib.river_control,
                mode,
            );
            _ = c.zriver_control_v1_run_command(
                lib.river_control,
                it.wl_seat,
            );
            return;
        }
    }
    
    // TODO: run custom commands upon clicking layout,
    // title, status
    if ((seat.bar.*.mtags & seat.bar.*.ctags) != 0) {
        x += lib.text_width(
            seat.bar.*.layout,
            seat.bar.*.width - x,
            seat.bar.*.textpadding,
            false,
        ) / lib.buffer_scale;
        if (seat.pointer_x < x) {
            // Clicked on layout
            return;
        }
    }
    
    if (
        seat.pointer_x <
        seat.bar.*.width / lib.buffer_scale - lib.text_width(
            seat.bar.*.status,
            seat.bar.*.width - x,
            seat.bar.*.textpadding,
            true,
        ) / lib.buffer_scale
    ) {
        // Clicked on title
        return;
    }
    
    // Clicked on status
}

pub const object = c.struct_wl_pointer_listener{
    .button = button,
    .enter = enter,
    .frame = frame,
    .leave = leave,
    .motion = motion,
};

