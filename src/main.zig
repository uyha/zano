pub fn main() !void {
    var bus: zano.Bus = try .open("vcan0");
    defer bus.deinit();

    try bus.set(.err_filter, .all);
    try bus.set(.fd_frames, true);

    std.debug.print(
        "{}\n",
        .{@as(
            zano.bus.Error,
            @bitCast(zano.bus.CanFrame{
                .can_id = .{ .id = 0x3FF },
                .len = .{ .len = 0x00 },
                .data = [_]u8{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x00 },
            }),
        ).tx_error_counter()},
    );
}

const std = @import("std");
const posix = std.posix;

const zano = @import("zano");
