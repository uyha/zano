pub fn main() !void {
    var bus: zano.Bus = try .open("vcan0");
    defer bus.deinit();

    try bus.set(.err_filter, .all);
    try bus.set(.fd_frames, true);

    try bus.write(.std(0x00, &.{}));
    try bus.write(.stdRemote(0x00));
    try bus.write(.ext(0x00, &.{}));
    try bus.write(.extRemote(0x00));
    std.debug.print("{any}\n", .{try bus.read()});
}

const std = @import("std");
const posix = std.posix;

const zano = @import("zano");
