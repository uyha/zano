/// Protocol taken from <linux/can.h>
const Protocol = enum(u32) {
    raw = 1,
    /// Broadcast Manager
    bcm = 2,
    /// VAG Transport Protocol v1.6
    tp16 = 3,
    /// VAG Transport Protocol v2.0
    tp20 = 4,
    /// Bosch MCNet
    mcnet = 5,
    /// ISO 15765-2 Transport Protocol
    isotp = 6,
    /// SAE J1939
    j1939 = 7,
};

/// Socket address structure for CAN sockets from <linux/can.h>
const SockAddr = extern struct {
    can_family: c_ushort,
    can_ifindex: c_int,
    can_addr: extern union {
        /// Transport Protocol address information
        tp: extern struct {
            rx_id: c_uint,
            tx_id: c_uint,
        },
        /// J1939 address information
        j1939: extern struct {
            name: u64,
            /// 8 bit: PS in PDU2 case, else 0
            /// 8 bit: PF
            /// 1 bit: DP
            /// 1 bit: reserved
            pgn: u32,
            addr: u8,
        },
    },
};

// Socket option level from <linux/can/raw.h>
const SOL = struct {
    const CAN_RAW = 101;
};

// Socket option from <linux/can/raw.h>
const Option = enum(u8) {
    filter = 1,
    err_filter,
    loopback,
    recv_own_msgs,
    fd_frames,
    join_filters,
    xl_frames,
};
fn OptionType(comptime option: Option) type {
    return switch (option) {
        .filter => []Filter,
        .err_filter => Error.Class,
        else => bool,
    };
}
pub const Filter = extern struct {
    id: u32,
    maks: u32,
};

pub const Bus = struct {
    handle: posix.socket_t,

    pub const OpenError =
        posix.SocketError ||
        posix.BindError ||
        posix.IoCtl_SIOCGIFINDEX_Error ||
        error{ NameTooLong, Unexpected };
    pub fn open(name: [:0]const u8) OpenError!Bus {
        if (name.len >= linux.IFNAMESIZE) {
            return OpenError.NameTooLong;
        }

        const socket = try posix.socket(
            c.AF.CAN,
            c.SOCK.RAW,
            @intFromEnum(Protocol.raw),
        );

        var request = posix.ifreq{
            .ifrn = .{ .name = @splat(0) },
            .ifru = undefined,
        };
        @memcpy(request.ifrn.name[0..name.len], name);

        try posix.ioctl_SIOCGIFINDEX(socket, &request);

        const address: SockAddr = .{
            .can_family = c.AF.CAN,
            .can_ifindex = request.ifru.ivalue,
            .can_addr = undefined,
        };
        try posix.bind(socket, @ptrCast(&address), @sizeOf(@TypeOf(address)));

        return .{ .handle = socket };
    }

    pub fn deinit(self: *Bus) void {
        posix.close(self.handle);
    }

    pub const WriteError = posix.WriteError;
    pub fn write(self: *const Bus, message: Message) WriteError!void {
        if (comptime conf.can_fd) {
            var frame: CanFdFrame = .{
                .can_id = message.id,
                .len = message.len,
                .data = undefined,
            };
            @memcpy(frame.data[0..message.data.len], message.data);

            _ = try posix.write(self.handle, asBytes(&frame));
        } else {
            var frame: CanFrame = .{
                .id = message.id,
                .len = message.len,
                .data = undefined,
            };
            @memcpy(&frame.data, message.data[0..8]);

            _ = try posix.write(self.handle, asBytes(&frame));
        }
    }

    pub const ReadError = posix.ReadError;
    pub fn read(self: *const Bus) ReadError!Message {
        const Frame = if (comptime conf.can_fd) CanFdFrame else CanFrame;

        var frame: Frame = undefined;

        _ = try posix.read(self.handle, asBytes(&frame));

        var result: Message = .{
            .id = frame.id,
            .len = frame.len,
            .data = undefined,
        };

        @memcpy(result.data[0..frame.len], frame.data[0..frame.len]);

        return result;
    }

    pub const SetError = posix.SetSockOptError;
    pub fn set(
        self: *const Bus,
        comptime option: Option,
        value: OptionType(option),
    ) SetError!void {
        try posix.setsockopt(
            self.handle,
            SOL.CAN_RAW,
            @intFromEnum(option),
            switch (option) {
                .filter => asBytes(&value),
                .err_filter => asBytes(&value),
                else => asBytes(&@as(c_int, @intFromBool(value))),
            },
        );
    }
};

const std = @import("std");
const asBytes = std.mem.asBytes;
const posix = std.posix;
const c = std.c;
const linux = std.os.linux;

const conf = @import("conf");

const zano = @import("root.zig");
const msg = zano.msg;
const CanFrame = msg.CanFrame;
const CanFdFrame = msg.CanFdFrame;
const Message = msg.Message;
const Error = msg.Error;
