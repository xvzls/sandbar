const std = @import("std");
pub const c = @cImport({
    @cInclude("sandbar.h");
});

export
fn wl_buffer_release(
    _: ?*anyopaque,
    wl_buffer: ?*c.struct_wl_buffer,
) void {
	// Sent by the compositor when it's no longer using
	// this buffer
    c.wl_buffer_destroy(wl_buffer);
}

export
const wl_buffer_listener = c.struct_wl_buffer_listener{
    .release = wl_buffer_release,
};

// Shared memory support function adapted from
// [wayland-book]
export
fn allocate_shm_file(size: c_long) c_int {
    const fd = c.memfd_create("surface", c.MFD_CLOEXEC);
    if (fd == -1) {
        return -1;
    }
    
    var ret: c_int = 0;
    while (true) {
        ret = std.c.ftruncate(fd, size);
        if (ret != -1 or std.c._errno().* != c.EINTR) {
            break;
        }
    }
    
    if (ret == -1) {
        const err = c.close(fd);
        if (err != 0) {
            return err;
        }
        return -1;
    }
    
    return fd;
}

export
var run_display = false;

export
fn layer_surface_closed(
    _: *anyopaque,
    _: *c.struct_zwlr_layer_surface_v1,
) void {
    std.debug.print("mogos\n", .{});
    run_display = false;
}

