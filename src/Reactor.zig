const Reactor = @This();

message_map: MessageMap = .empty,
bus: Bus,

allocator: Allocator,

pub const InitError = Bus.OpenError;
pub fn init(allocator: Allocator, name: [:0]const u8) InitError!Reactor {
    return .{
        .bus = try .open(name),
        .allocator = allocator,
    };
}
pub fn deinit(self: *Reactor) void {
    for (self.message_map.entries.items(.value)) |*value| {
        value.deinit(self.allocator);
    }
    self.message_map.deinit(self.allocator);
    self.bus.deinit();
}

pub const ListenError = Allocator.Error;
pub fn listen(
    self: *Reactor,
    id: CanId,
    handler: MessageHandler,
) ListenError!void {
    const result = try self.message_map.getOrPut(self.allocator, id);
    if (!result.found_existing) {
        result.value_ptr.* = .empty;
    }
    const handlers = result.value_ptr;
    try handlers.append(self.allocator, handler);
}

pub const ProcessError = Bus.ReadError || ListenError;
pub fn processMessage(self: *Reactor) anyerror!void {
    const message = try self.bus.read();

    if (self.message_map.getPtr(message.id)) |handlers| {
        var i: usize = 0;
        while (i < handlers.items.len) {
            const handler = &handlers.items[i];
            const should_keep = try handler.func(
                handler.ctx,
                message.id,
                message.slice(),
            );
            if (should_keep) {
                i += 1;
            } else {
                _ = handlers.swapRemove(i);
            }
        }
    }
}

/// The function type that `Reactor` accepts. If the function returns `false`,
/// the handler containing it will be removed from the `Reactor`.
pub const MessageFunc = fn (
    ctx: ?*anyopaque,
    id: CanId,
    bytes: []const u8,
) anyerror!bool;
pub const MessageHandler = zano.Callback(MessageFunc);

const std = @import("std");
const Allocator = std.mem.Allocator;
const MessageHandlers = std.ArrayListUnmanaged(MessageHandler);
const MessageMap = std.AutoArrayHashMapUnmanaged(CanId, MessageHandlers);

const zano = @import("root.zig");
const msg = zano.msg;
const CanId = msg.CanId;
const Bus = zano.Bus;
