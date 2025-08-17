const std = @import("std");
const lib = @import("root.zig");
const c = lib.c;

wl_seat: ?*c.struct_wl_seat,
wl_pointer: ?*c.struct_wl_pointer,
river_seat_status: ?*c.zriver_seat_status_v1,
registry_name: u32,

bar: ?*lib.Bar,
hovering: bool,
pointer_x: u32,
pointer_y: u32,
pointer_button: u32,

mode: [*c]u8,

link: c.struct_wl_list,

