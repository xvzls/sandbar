const std = @import("std");
pub const c = @cImport({
    @cInclude("sandbar.h");
});

export
var height: u32 = 0;

export
var textpadding: u32 = 0;

export
var vertical_padding: u32 = 1;

export
var buffer_scale: u32 = 1;

fn wl_buffer_release(
    _: ?*anyopaque,
    wl_buffer: ?*c.struct_wl_buffer,
) callconv(.c) void {
    // Sent by the compositor when it's no longer using
    // this buffer
    c.wl_buffer_destroy(wl_buffer);
}

export
const wl_buffer_listener = c.struct_wl_buffer_listener{
    .release = wl_buffer_release,
};

export
fn parse_color(
    raw_string: [*c]const u8,
    color: *c.pixman_color_t,
) c_int {
    const string = std.mem.trimLeft(
        u8,
        std.mem.span(raw_string),
        "#",
    );
    
    if (
        (string.len != 6 and string.len != 8) or
        c.isxdigit(string[0]) == 0 or
        c.isxdigit(string[1]) == 0
    ) {
        return -1;
    }
    
    var parsed =
        std.fmt.parseInt(u32, string, 16)
    catch
        return -1;
    
    if (string.len == 8) {
        color.alpha = @intCast((parsed & 0xff) * 0x101);
        parsed >>= 8;
    } else {
        color.alpha = 0xffff;
    }
    
    color.red = @intCast(
        ((parsed >> 16) & 0xff) * 0x101
    );
    color.green = @intCast(
        ((parsed >>  8) & 0xff) * 0x101
    );
    color.blue = @intCast(
        ((parsed >>  0) & 0xff) * 0x101
    );
    
    return 0;
}

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

// Layer-surface setup adapted from layer-shell example
// in [wlroots]
fn layer_surface_configure(
    data: ?*anyopaque,
    surface: ?*c.struct_zwlr_layer_surface_v1,
    serial: u32,
    raw_w: u32,
    raw_h: u32,
) callconv(.c) void {
	c.zwlr_layer_surface_v1_ack_configure(
	    surface,
	    serial,
	);
    
	var bar: *c.Bar = @ptrCast(@alignCast(data));
	
	const w = raw_w * buffer_scale;
	const h = raw_h * buffer_scale;
    
	if (
	    bar.configured and
	    w == bar.width and
	    h == bar.height
	) {
		return;
	}
	
	bar.width = w;
	bar.height = h;
	bar.stride = bar.width * 4;
	bar.bufsize = bar.stride * bar.height;
	bar.configured = true;
    
	_ = c.draw_frame(bar);
}

fn layer_surface_closed(
    _: ?*anyopaque,
    _: ?*c.struct_zwlr_layer_surface_v1,
) callconv(.c) void {
    run_display = false;
}

export
const layer_surface_listener = c.struct_zwlr_layer_surface_v1_listener{
    .configure = layer_surface_configure,
    .closed = layer_surface_closed,
};

