pub fn main() !void {
    var bus: zano.Bus = try .open("vcan0");
    defer bus.deinit();

    try bus.set(.err_filter, .all);
    try bus.set(.fd_frames, true);

    try bus.write(.std(0x00, &.{}));
    try bus.write(.stdRemote(0x00));
    try bus.write(.ext(0x00, &.{}));
    try bus.write(.extRemote(0x00));

    var epoll: Epoll = try .init(.none);
    defer epoll.deinit();

    try epoll.add(bus.handle, .{ .events = .in, .data = .fd(bus.handle) });
    try epoll.modify(bus.handle, .{ .events = .in, .data = .fd(bus.handle) });

    var buffer: [16]Epoll.WaitEvent = undefined;
    while (true) {
        for (epoll.wait(&buffer, -1)) |event| {
            _ = &event;
            const message = try bus.read();
            std.debug.print("{X:03}: {X:02}\n", .{ message.id.id, message.slice() });
        }
    }
}

const std = @import("std");
const posix = std.posix;

const zano = @import("zano");
const Epoll = zano.Epoll;
