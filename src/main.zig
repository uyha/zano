fn echo(_: ?*anyopaque, id: zano.msg.CanId, bytes: []const u8) bool {
    std.debug.print("{s}:{} ({s})\n", .{ @src().file, @src().line, @src().fn_name });
    std.debug.print("{X:03}: {X:02}\n", .{ id.id, bytes });

    return true;
}
fn oche(state: ?*anyopaque, id: zano.msg.CanId, bytes: []const u8) bool {
    const count: *usize = @alignCast(@ptrCast(state.?));
    count.* += 1;

    std.debug.print("{s}:{} ({s})\n", .{ @src().file, @src().line, @src().fn_name });
    std.debug.print("{X:03}: {X:02}\n", .{ id.id, bytes });

    return count.* < 1;
}
fn remove(_: ?*anyopaque, id: zano.msg.CanId, bytes: []const u8) bool {
    std.debug.print("{s}:{} ({s})\n", .{ @src().file, @src().line, @src().fn_name });
    std.debug.print("{X:03}: {X:02}\n", .{ id.id, bytes });

    return false;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer std.debug.assert(!gpa.detectLeaks());

    const allocator = gpa.allocator();

    var reactor: zano.Reactor = try .init("vcan0");
    defer reactor.deinit(allocator);

    var count: usize = 0;

    try reactor.register(allocator, .std(0x000), .init(remove, null));
    try reactor.register(allocator, .std(0x000), .init(oche, &count));
    try reactor.register(allocator, .std(0x000), .init(remove, null));
    try reactor.register(allocator, .std(0x000), .init(echo, null));

    var epoll: Epoll = try .init(.none);
    defer epoll.deinit();

    try epoll.add(reactor.bus.handle, .fd(.in, reactor.bus.handle));

    var buffer: [16]Epoll.WaitEvent = undefined;
    for (0..5) |_| {
        for (epoll.wait(&buffer, -1)) |event| {
            if (event.data.file_descriptor == reactor.bus.handle) {
                std.debug.print("{s}:{} ({s})\n", .{ @src().file, @src().line, @src().fn_name });
                try reactor.processMessage();
                std.debug.print("\n", .{});
            }
        }
    }
}

const std = @import("std");
const posix = std.posix;

const zano = @import("zano");
const Epoll = zano.Epoll;
const TimerFd = zano.TimerFd;
