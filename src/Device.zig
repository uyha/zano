//! Do not create `Device` directly, only create it via `Master.newDevice`

const Device = @This();

master: *Master,

id: u8,

on_state: ?zano.Callback(OnState) = null,
on_check: ?zano.Callback(OnCheck) = null,

nmt_state: ?NmtState = null,

identity: Identity = .{
    .vendor_id = 0x00,
    .revision_number = 0x42,
},

check_step: CheckStep = .product_code,

const CheckStep = enum {
    product_code,
    revision_number,
    done,
};
pub const CheckResult = enum {
    success,
    product_code_mismatched,
    revision_number_mismatched,
};

pub const OnState = fn (ctx: ?*anyopaque, device: *Device, old: ?NmtState) void;
pub const OnCheck = fn (
    ctx: ?*anyopaque,
    device: *Device,
    result: CheckResult,
) void;

pub const NmtState = enum(u8) {
    initializing = 0x00,
    pre_operational = 0x7F,
    operational = 0x05,
    stopped = 0x04,
};

pub fn observe(self: *Device) Reactor.ListenError!void {
    const reactor = self.master.reactor;

    try reactor.listen(.std(self.nmtId()), .init(mnt, self));
}

fn nmtId(self: *const Device) u16 {
    return 0x700 + @as(u16, self.id);
}
fn mnt(
    ctx: ?*anyopaque,
    id: CanId,
    bytes: []const u8,
) anyerror!bool {
    const self: *Device = @alignCast(@ptrCast(ctx.?));

    if (id.id != self.nmtId() or bytes.len != 1) {
        return true;
    }

    const old = self.nmt_state;
    self.nmt_state = intToEnum(NmtState, bytes[0]) catch return true;

    if (self.on_state) |callback| {
        callback.func(callback.ctx, self, old);
    }

    switch (self.nmt_state.?) {
        .pre_operational => {
            try self.startCheck();
        },
        else => {},
    }

    return true;
}

fn sdoId(self: *const Device) u16 {
    return 0x580 + @as(u16, self.id);
}
fn sdo(
    ctx: ?*anyopaque,
    id: CanId,
    bytes: []const u8,
) Reactor.ListenError!bool {
    _ = &ctx;
    _ = &id;
    _ = &bytes;

    return true;
}

fn configure(self: *Device) void {
    _ = &self;
}

fn startCheck(self: *Device) !void {
    const bus = &self.master.reactor.bus;

    self.check_step = if (self.identity.product_code != null)
        .product_code
    else if (self.identity.revision_number != null)
        .revision_number
    else
        .done;

    switch (self.check_step) {
        .product_code, .revision_number => |step| {
            try self.master.reactor.listen(.std(self.sdoId()), .init(check, self));

            try bus.write(.std(
                0x600 + @as(u16, self.id),
                &.{
                    0x40,
                    0x18,
                    0x10,
                    if (step == .product_code) 0x02 else 0x03,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                },
            ));
        },
        .done => if (self.on_check) |callback| {
            callback.func(callback.ctx, self, .success);
        },
    }
}

fn check(
    ctx: ?*anyopaque,
    _: CanId,
    bytes: []const u8,
) anyerror!bool {
    const self: *Device = @alignCast(@ptrCast(ctx));
    const bus = &self.master.reactor.bus;

    if (bytes.len != 8 or !eql(u8, bytes[0..3], &.{ 0x43, 0x18, 0x10 })) {
        return true;
    }

    switch (self.check_step) {
        .product_code => if (bytes[3] == 0x02) {
            if (self.identity.product_code != readInt(u32, bytes[4..8], .little)) {
                if (self.on_check) |callback| {
                    callback.func(callback.ctx, self, .product_code_mismatched);
                }
                return false;
            }
            self.check_step = .revision_number;
            try bus.write(.std(
                0x600 + @as(u16, self.id),
                &.{ 0x40, 0x18, 0x10, 0x03, 0x00, 0x00, 0x00, 0x00 },
            ));
        },
        .revision_number => if (bytes[3] == 0x03) {
            const result: CheckResult = blk: {
                if (self.identity.revision_number != readInt(u32, bytes[4..8], .little)) {
                    break :blk .revision_number_mismatched;
                } else {
                    break :blk .success;
                }
            };
            if (self.on_check) |callback| {
                callback.func(callback.ctx, self, result);
            }
            return false;
        },
        .done => return false,
    }

    return true;
}

const std = @import("std");
const eql = std.mem.eql;
const readInt = std.mem.readInt;
const intToEnum = std.meta.intToEnum;

const zano = @import("root.zig");
const Identity = zano.od.types.Identity;
const Master = zano.Master;
const CanId = zano.CanId;
const Reactor = zano.Reactor;
