pub const msg = @import("msg.zig");
pub const Message = msg.Message;

pub const bus = @import("bus.zig");
pub const Bus = bus.Bus;

pub const eds = @import("eds.zig");

comptime {
    const t = @import("std").testing;

    t.refAllDecls(eds);
}
