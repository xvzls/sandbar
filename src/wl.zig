const lib = @import("root.zig");
const std = @import("std");
const c = lib.c;

pub fn List(comptime T: type) type {
    return extern struct {
        wl_list: c.wl_list,
        
        pub inline fn from(list: *c.wl_list) *@This() {
            return @ptrCast(list);
        }
        
        pub fn Iterator(
            comptime link: []const u8
        ) type {
            return extern struct {
                start: *c.wl_list,
                current: *c.wl_list,
                preceding: *c.wl_list,
                
                pub inline fn from(
                    list: *c.wl_list
                ) @This() {
                    return @This(){
                        .start = list,
                        .current = list,
                        .preceding = list.next,
                    };
                }
                
                pub inline fn next(this: *@This()) ?*T {
                    if (this.preceding == this.start) {
                        return null;
                    }
                    
                    this.current = this.preceding;
                    this.preceding = this.current.next;
                    
                    return @fieldParentPtr(
                        link,
                        this.current,
                    );
                }
            };
        }
        
        pub fn iterator(
            this: *@This(),
            comptime link: []const u8,
        ) Iterator(link) {
            return Iterator(link).from(@ptrCast(this));
        }
    };
}

pub fn Array(comptime T: type) type {
    return extern struct {
        wl_array: c.wl_array,
        
        pub inline fn items(this: *@This()) []T {
            var slice: []T = undefined;
            
            slice.ptr = @ptrCast(@alignCast(
                this.wl_array.data
            ));
            slice.len = this.wl_array.size / @sizeOf(T);
            
            return slice;
        }
    };
}

