const std = @import("std");
const c = @cImport({
    @cInclude("sandbar.h");
});

fn description(
    _: ?*anyopaque,
    _: ?*c.struct_wl_output,
    _: [*c]const u8,
) callconv(.c) void {
}

fn done(
    _: ?*anyopaque,
    _: ?*c.struct_wl_output,
) callconv(.c) void {
}

fn geometry(
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

fn mode(
    _: ?*anyopaque,
    _: ?*c.struct_wl_output,
    _: u32,
    _: i32,
    _: i32,
    _: i32,
) callconv(.c) void {
}

fn name(
    data: ?*anyopaque,
    _: ?*c.struct_wl_output,
    output_name: [*c]const u8,
) callconv(.c) void {
    const bar: *c.Bar = @alignCast(@ptrCast(data.?));
    
    if (bar.output_name) |ptr| {
        c.free(ptr);
    }
    
    bar.output_name = std.heap.c_allocator.dupeZ(
        u8,
        std.mem.span(output_name)
    ) catch |err| {
        @panic(@errorName(err));
    };
}

fn scale(
    _: ?*anyopaque,
    _: ?*c.struct_wl_output,
    _: i32,
) callconv(.c) void {
}

pub const object = c.struct_wl_output_listener{
    .description = description,
    .done = done,
    .geometry = geometry,
    .mode = mode,
    .name = name,
    .scale = scale,
};

