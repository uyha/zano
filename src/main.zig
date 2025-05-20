pub fn main() !void {
    var bus: zano.Bus = try .open("vcan0");
    defer bus.deinit();

    try bus.set(.err_filter, .all);
    try bus.set(.fd_frames, true);

    try bus.write(.std(0x00, &.{}));
    try bus.write(.stdRemote(0x00));
    try bus.write(.ext(0x00, &.{}));
    try bus.write(.extRemote(0x00));

    var timer: TimerFd = try .init(.monotonic, .nonblock);
    defer timer.deinit();
    try timer.set(.every(.sec(1)));

    var epoll: Epoll = try .init(.none);
    defer epoll.deinit();

    try epoll.add(bus.handle, .{ .events = .in, .data = .fd(bus.handle) });
    try epoll.add(timer.handle, .{ .events = .in, .data = .fd(timer.handle) });

    var buffer: [16]Epoll.WaitEvent = undefined;
    while (true) {
        for (epoll.wait(&buffer, -1)) |event| {
            std.debug.print("{s}:{} ({s})\n", .{ @src().file, @src().line, @src().fn_name });
            if (event.data.file_descriptor == bus.handle) {
                const message = try bus.read();
                std.debug.print(
                    "{X:03}: {X:02}\n",
                    .{ message.id.id, message.slice() },
                );
            }
            if (event.data.file_descriptor == timer.handle) {
                std.debug.print("Timer expires: {}\n", .{try timer.read()});
            }
        }
    }
}

const std = @import("std");
const posix = std.posix;

const zano = @import("zano");
const Epoll = zano.Epoll;
const TimerFd = zano.TimerFd;
