const lib = @import("root.zig");
const std = @import("std");
const c = lib.c;

// Layer-surface setup adapted from layer-shell example
// in [wlroots]
fn configure(
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
    
    var bar: *lib.Bar = @ptrCast(@alignCast(data));
    
    const w = raw_w * lib.buffer_scale;
    const h = raw_h * lib.buffer_scale;
    
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
    
    _ = lib.draw_frame(bar);
}

fn closed(
    _: ?*anyopaque,
    _: ?*c.struct_zwlr_layer_surface_v1,
) callconv(.c) void {
    lib.run_display = false;
}

pub const object = c.struct_zwlr_layer_surface_v1_listener{
    .configure = configure,
    .closed = closed,
};


