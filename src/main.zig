const lib = @import("sandbar_lib");
const std = @import("std");
const c = @cImport({
    @cInclude("sandbar.h");
});

pub fn main() !u8 {
    return @intCast(c.c_main(
        @intCast(std.os.argv.len),
        @ptrCast(std.os.argv),
    ));
}

