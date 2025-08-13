const lib = @import("root.zig");
const std = @import("std");
const c = @cImport({
    @cInclude("sandbar.h");
});

fn capabilities(
    data: ?*anyopaque,
    _: ?*c.struct_wl_seat,
    code: u32,
) callconv(.c) void {
    var seat: *c.Seat = @ptrCast(@alignCast(data.?));
    
    const has_pointer = (
        code & c.WL_SEAT_CAPABILITY_POINTER
    ) != 0;
    
    if (has_pointer and seat.wl_pointer == null) {
        seat.wl_pointer = c.wl_seat_get_pointer(
            seat.wl_seat,
        );
        _ = c.wl_pointer_add_listener(
            seat.wl_pointer,
            &lib.pointer_listener,
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

fn name(
    _: ?*anyopaque,
    _: ?*c.struct_wl_seat,
    _: [*c]const u8,
) callconv(.c) void {
}

pub const object = c.struct_wl_seat_listener{
    .capabilities = capabilities,
    .name = name,
};

