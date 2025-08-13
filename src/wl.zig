const std = @import("std");
const c = @cImport({
    @cInclude("sandbar.h");
});

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
                
                pub inline fn from(
                    list: *c.wl_list
                ) @This() {
                    return @This(){
                        .start = list,
                        .current = list,
                    };
                }
                
                pub fn next(this: *@This()) ?*T {
                    this.current = this.current.next;
                    if (this.current == this.start) {
                        return null;
                    }
                    
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

