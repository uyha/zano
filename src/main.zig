fn echo_state(
    _: ?*anyopaque,
    device: *zano.Device,
    old: ?zano.Device.NmtState,
) void {
    std.debug.print("State: {any} -> {any}\n", .{ old, device.nmt_state });
}
fn echo_verification_result(
    _: ?*anyopaque,
    _: *zano.Device,
    result: zano.Device.CheckResult,
) void {
    std.debug.print("Result: {}\n", .{result});
}
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer std.debug.assert(!gpa.detectLeaks());

    const allocator = gpa.allocator();

    var reactor: zano.Reactor = try .init(allocator, "vcan0");
    defer reactor.deinit();

    var master: zano.Master = .init(&reactor);
    defer master.deinit(allocator);

    const device: *zano.Device = try master.newDevice(allocator, 1);

    device.on_state = .init(echo_state, null);
    device.on_check = .init(echo_verification_result, null);

    var epoll: Epoll = try .init(.none);
    defer epoll.deinit();

    try epoll.add(reactor.bus.handle, .fd(.in, reactor.bus.handle));

    try master.reset();

    var buffer: [16]Epoll.WaitEvent = undefined;
    while (true) {
        for (epoll.wait(&buffer, -1)) |event| {
            if (event.data.file_descriptor == reactor.bus.handle) {
                try reactor.processMessage();
            }
        }
    }
}

const std = @import("std");
const posix = std.posix;

const zano = @import("zano");
const Epoll = zano.Epoll;
const TimerFd = zano.TimerFd;
