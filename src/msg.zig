pub const CanId = packed struct(u32) {
    id: u29,
    err: bool = false,
    remote: bool = false,
    extended: bool = false,

    pub fn new(id: u16) CanId {
        return .{ .id = id & 0x7FF };
    }
    pub fn newRemote(id: u16) CanId {
        return .{
            .id = id & 0x7FF,
            .remote = true,
        };
    }
    pub fn ext(id: u32) CanId {
        return .{
            .id = id & 0x1F_FF_FF_FF,
            .extended = true,
        };
    }
    pub fn extRemote(id: u32) CanId {
        return .{
            .id = id & 0x1F_FF_FF_FF,
            .remote = true,
            .extended = true,
        };
    }
};

const max_data_len = if (conf.can_fd) 64 else 8;
pub const Message = struct {
    id: CanId,
    len: u8,
    data: [max_data_len]u8,

    pub const Error = error{DataTooBig};
    pub fn new(id: u16, data: []const u8) Error!Message {
        if (data.len > 8) {
            return Error.DataTooBig;
        }

        var message: Message = .{
            .id = .new(id),
            .len = @intCast(data.len),
            .data = undefined,
        };

        @memcpy(message.data[0..data.len], data);

        return message;
    }

    pub fn newRemote(id: u16) Error!Message {
        return .{ .id = .newRemote(id), .len = 0, .data = undefined };
    }
};

const std = @import("std");

const conf = @import("conf");
