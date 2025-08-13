const lib = @import("root.zig");
const std = @import("std");
const wl = @import("wl.zig");
const c = @cImport({
    @cInclude("sandbar.h");
});

fn focused_output(
    data: ?*anyopaque,
    _: ?*c.struct_zriver_seat_status_v1,
    wl_output: ?*c.struct_wl_output,
) callconv(.c) void {
    const seat: *c.Seat = @ptrCast(@alignCast(data.?));
    
    var bars = wl.List(c.Bar)
        .from(&lib.bar_list)
        .iterator("link");
    
    while (bars.next()) |bar| {
        if (bar.wl_output == wl_output) {
            seat.bar = bar;
            seat.bar.*.sel = true;
            seat.bar.*.redraw = true;
            return;
        }
    }
    
    seat.bar = null;
}

fn unfocused_output(
    data: ?*anyopaque,
    _: ?*c.struct_zriver_seat_status_v1,
    _: ?*c.struct_wl_output,
) callconv(.c) void {
    const seat: *c.Seat = @ptrCast(@alignCast(data.?));
    const bar: *c.Bar = seat.bar orelse return;
    
    bar.sel = false;
    bar.redraw = true;
    seat.bar = null;
}

fn focused_view(
    data: ?*anyopaque,
    _: ?*c.struct_zriver_seat_status_v1,
    title: [*c]const u8,
) callconv(.c) void {
    if (lib.no_title) {
        return;
    }
    
    const seat: *c.Seat = @ptrCast(@alignCast(data.?));
    const bar: *c.Bar = seat.bar orelse return;
    
    if (bar.title) |ptr| {
        c.free(ptr);
    }
    
    bar.title = std.heap.c_allocator.dupeZ(
        u8,
        std.mem.span(title)
    ) catch |err| {
        @panic(@errorName(err));
    };
    
    bar.redraw = true;
}

fn mode(
    data: ?*anyopaque,
    _: ?*c.struct_zriver_seat_status_v1,
    name: [*c]const u8,
) callconv(.c) void {
    const seat: *c.Seat = @ptrCast(@alignCast(data.?));
    
    if (seat.mode) |ptr| {
        c.free(ptr);
    }
    
    seat.mode = std.heap.c_allocator.dupeZ(
        u8,
        std.mem.span(name)
    ) catch |err| {
        @panic(@errorName(err));
    };
    
    var bars = wl.List(c.Bar)
        .from(&lib.bar_list)
        .iterator("link");
    
    while (bars.next()) |bar| {
        bar.redraw = true;
    }
}

pub const object = c.struct_zriver_seat_status_v1_listener{
    .focused_output = focused_output,
    .unfocused_output = unfocused_output,
    .focused_view = focused_view,
    .mode = mode,
};

