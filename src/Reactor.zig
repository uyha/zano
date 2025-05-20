const Reactor = @This();

message_map: MessageMap = .empty,
bus: Bus,

pub fn init(name: [:0]const u8) Bus.OpenError!Reactor {
    return .{
        .bus = try .open(name),
    };
}
pub fn deinit(self: *Reactor, allocator: Allocator) void {
    for (self.message_map.entries.items(.value)) |*value| {
        value.deinit(allocator);
    }
    self.message_map.deinit(allocator);
    self.bus.deinit();
}

pub const RegisterError = Allocator.Error;
pub fn register(
    self: *Reactor,
    allocator: Allocator,
    id: CanId,
    handler: MessageHandler,
) RegisterError!void {
    const result = try self.message_map.getOrPut(allocator, id);
    if (!result.found_existing) {
        result.value_ptr.* = .empty;
    }
    const handlers = result.value_ptr;
    try handlers.append(allocator, handler);
}

pub const ProcessError = Bus.ReadError;
pub fn processMessage(self: *Reactor) ProcessError!void {
    const message = try self.bus.read();

    if (self.message_map.getPtr(message.id)) |handlers| {
        var i: usize = 0;
        while (i < handlers.items.len) {
            const handler = &handlers.items[i];
            if (!handler.func(handler.context, message.id, message.slice())) {
                _ = handlers.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }
}

/// The function type that `Reactor` accepts. If the function returns `false`,
/// the handler containing it will be removed from the `Reactor`.
pub const MessageFunc = fn (
    context: ?*anyopaque,
    id: CanId,
    bytes: []const u8,
) bool;

pub const MessageHandler = struct {
    func: *const MessageFunc,
    context: ?*anyopaque,

    pub fn init(func: *const MessageFunc, context: ?*anyopaque) MessageHandler {
        return .{
            .func = func,
            .context = context,
        };
    }
};

const std = @import("std");
const Allocator = std.mem.Allocator;
const MessageHandlers = std.ArrayListUnmanaged(MessageHandler);
const MessageMap = std.AutoArrayHashMapUnmanaged(CanId, MessageHandlers);

const zano = @import("root.zig");
const msg = zano.msg;
const CanId = msg.CanId;
const Bus = zano.Bus;
