pub const msg = @import("msg.zig");
pub const Message = msg.Message;

pub const bus = @import("bus.zig");
pub const Bus = bus.Bus;

pub const eds = @import("eds.zig");

pub const Reactor = @import("Reactor.zig");
pub const Master = @import("Master.zig");

pub const Epoll = @import("linux/Epoll.zig");
pub const TimerFd = @import("linux/TimerFd.zig");

comptime {
    const t = @import("std").testing;

    t.refAllDecls(eds);
}
