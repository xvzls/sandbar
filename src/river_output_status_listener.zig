const std = @import("std");
const wl = @import("wl.zig");
const c = @cImport({
    @cInclude("sandbar.h");
});

fn focused_tags(
    data: ?*anyopaque,
    _: ?*c.struct_zriver_output_status_v1,
    n_tags: u32,
) callconv(.c) void {
    const bar: *c.Bar = @ptrCast(@alignCast(data.?));
    
    bar.mtags = n_tags;
    bar.redraw = true;
}

fn urgent_tags(
    data: ?*anyopaque,
    _: ?*c.struct_zriver_output_status_v1,
    n_tags: u32,
) callconv(.c) void {
    const bar: *c.Bar = @ptrCast(@alignCast(data.?));
    
    bar.urg = n_tags;
    bar.redraw = true;
}

fn view_tags(
    data: ?*anyopaque,
    _: ?*c.struct_zriver_output_status_v1,
    wl_array: ?*c.struct_wl_array,
) callconv(.c) void {
    const bar: *c.Bar = @ptrCast(@alignCast(data.?));
    
    bar.ctags = 0;
    
    for (@as(
        *wl.Array(u32),
        @ptrCast(wl_array.?)
    ).items()) |item| {
        bar.ctags |= item;
    }
    bar.redraw = true;
}

fn layout_name(
    data: ?*anyopaque,
    _: ?*c.struct_zriver_output_status_v1,
    name: [*c]const u8,
) callconv(.c) void {
    const bar: *c.Bar = @ptrCast(@alignCast(data.?));
    
    if (bar.layout) |ptr| {
        c.free(ptr);
    }
    
    bar.layout = std.heap.c_allocator.dupeZ(
        u8,
        std.mem.span(name)
    ) catch |err| {
        @panic(@errorName(err));
    };
    
    bar.redraw = true;
}

fn layout_name_clear(
    data: ?*anyopaque,
    _: ?*c.struct_zriver_output_status_v1,
) callconv(.c) void {
    const bar: *c.Bar = @ptrCast(@alignCast(data.?));
    
    if (bar.layout) |layout| {
        c.free(layout);
        bar.layout = null;
    }
}

pub const object = c.struct_zriver_output_status_v1_listener{
    .focused_tags = focused_tags,
    .urgent_tags = urgent_tags,
    .view_tags = view_tags,
    .layout_name = layout_name,
    .layout_name_clear = layout_name_clear,
};

