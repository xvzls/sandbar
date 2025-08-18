const lib = @import("root.zig");
const c = lib.c;

fn release(
    _: ?*anyopaque,
    wl_buffer: ?*c.struct_wl_buffer,
) callconv(.c) void {
    // Sent by the compositor when it's no longer using
    // this buffer
    c.wl_buffer_destroy(wl_buffer);
}

pub const object = c.struct_wl_buffer_listener{
    .release = release,
};

