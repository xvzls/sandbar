const lib = @import("sandbar_lib");
const std = @import("std");

pub fn main() !u8 {
    return @intCast(lib.c.c_main(
        @intCast(std.os.argv.len),
        @ptrCast(std.os.argv),
    ));
}

