const lib = @import("root.zig");
const std = @import("std");
const wl = lib.wl;
const c = lib.c;

fn global(
    _: ?*anyopaque,
    registry: ?*c.struct_wl_registry,
    name: u32,
    interface: [*c]const u8,
    _: u32,
) callconv(.c) void {
    if (c.strcmp(
        interface,
        c.wl_compositor_interface.name
    ) == 0) {
        lib.compositor = @ptrCast(@alignCast(c.wl_registry_bind(
            registry,
            name,
            &c.wl_compositor_interface,
            4,
        )));
    } else if (c.strcmp(
        interface,
        c.wl_shm_interface.name
    ) == 0) {
        lib.shm = @ptrCast(@alignCast(c.wl_registry_bind(
            registry,
            name,
            &c.wl_shm_interface,
            1,
        )));
    } else if (c.strcmp(
        interface,
        c.zwlr_layer_shell_v1_interface.name,
    ) == 0) {
        lib.layer_shell = @ptrCast(@alignCast(c.wl_registry_bind(
            registry,
            name,
            &c.zwlr_layer_shell_v1_interface,
            1,
        )));
    } else if (c.strcmp(
        interface,
        c.zriver_status_manager_v1_interface.name,
    ) == 0) {
        lib.river_status_manager = @ptrCast(@alignCast(c.wl_registry_bind(
            registry,
            name,
            &c.zriver_status_manager_v1_interface,
            4,
        )));
    } else if (c.strcmp(
        interface,
        c.zriver_control_v1_interface.name,
    ) == 0) {
        lib.river_control = @ptrCast(@alignCast(c.wl_registry_bind(
            registry,
            name,
            &c.zriver_control_v1_interface,
            1,
        )));
    } else if (c.strcmp(
        interface,
        c.wl_output_interface.name
    ) == 0) {
        const bar: *lib.Bar = std.heap.c_allocator.create(lib.Bar) catch |err| @panic(@errorName(err));
        bar.* = std.mem.zeroes(lib.Bar);
        
        bar.registry_name = name;
        bar.wl_output = @ptrCast(@alignCast(c.wl_registry_bind(
            registry,
            name,
            &c.wl_output_interface,
            4,
        )));
        _ = c.wl_output_add_listener(
            bar.wl_output,
            &lib.output_listener,
            bar,
        );
        if (lib.run_display) {
            lib.setup_bar(bar);
        }
        c.wl_list_insert(&lib.bar_list, &bar.link);
    } else if (c.strcmp(
        interface,
        c.wl_seat_interface.name
    ) == 0) {
        const seat: *lib.Seat = std.heap.c_allocator.create(lib.Seat) catch |err| @panic(@errorName(err));
        seat.* = std.mem.zeroes(lib.Seat);
        
        seat.registry_name = name;
        seat.wl_seat = @ptrCast(@alignCast(c.wl_registry_bind(
            registry,
            name,
            &c.wl_seat_interface,
            7,
        )));
        _ = c.wl_seat_add_listener(
            seat.wl_seat,
            &lib.seat_listener,
            seat,
        );
        if (lib.run_display) {
            lib.setup_seat(seat);
        }
        c.wl_list_insert(&lib.seat_list, &seat.link);
    }
}

fn global_remove(
    _: ?*anyopaque,
    _: ?*c.struct_wl_registry,
    name: u32,
) callconv(.c) void {
    var bars = wl.List(lib.Bar)
        .from(&lib.bar_list)
        .iterator("link");
    
    while (bars.next()) |bar| {
        if (bar.registry_name == name) {
            c.wl_list_remove(&bar.link);
            lib.teardown_bar(bar);
            return;
        }
    }
    
    var seats = wl.List(lib.Seat)
        .from(&lib.seat_list)
        .iterator("link");
    
    while (seats.next()) |seat| {
        if (seat.registry_name == name) {
            c.wl_list_remove(&seat.link);
            lib.teardown_seat(seat);
            return;
        }
    }
}

pub
const object = c.struct_wl_registry_listener{
    .global = global,
    .global_remove = global_remove,
};

