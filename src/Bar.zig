const std = @import("std");
const lib = @import("root.zig");
const c = lib.c;

wl_output: ?*c.struct_wl_output,
wl_surface: ?*c.struct_wl_surface,
layer_surface: ?*c.struct_zwlr_layer_surface_v1,
river_output_status: ?*c.struct_zriver_output_status_v1,

registry_name: u32,
output_name: [*c]u8,

configured: bool,
width: u32,
height: u32,
textpadding: u32,
stride: u32,
bufsize: u32,

mtags: u32,
ctags: u32,
urg: u32,
sel: bool,
layout: [*c]u8,
title: [*c]u8,
status: [*c]u8,

hidden: bool,
bottom: bool,
redraw: bool,

link: c.struct_wl_list,

