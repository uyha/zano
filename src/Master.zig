const Master = @This();

reactor: *Reactor,
devices: Devices = .empty,

pub fn init(reactor: *Reactor) Master {
    return .{
        .reactor = reactor,
    };
}
pub fn deinit(self: *Master, allocator: Allocator) void {
    self.devices.deinit(allocator);
}

pub const ResetError = zano.Bus.WriteError || Reactor.ListenError;
pub fn reset(self: *Master) ResetError!void {
    // Broadcast NMT reset communication message to discover devices on the bus
    for (self.devices.items) |device| {
        try self.reactor.bus.write(.std(0x000, &.{ 0x80, device.id }));
    }
}

pub const NewDeviceError = Allocator.Error || Reactor.ListenError;
pub fn newDevice(self: *Master, allocator: Allocator, id: u8) NewDeviceError!*Device {
    const device = try self.devices.addOne(allocator);

    device.* = .{ .id = id, .master = self };

    try device.observe();

    return device;
}

const std = @import("std");
const Devices = std.ArrayListUnmanaged(Device);
const Allocator = std.mem.Allocator;

const zano = @import("root.zig");
const Reactor = zano.Reactor;
const Device = zano.Device;
const CanId = zano.CanId;
