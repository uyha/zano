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

/// CAN frame taken from <linux/can.h>
pub const CanFrame = extern struct {
    can_id: msg.CanId,
    len: extern union {
        len: u8,
        can_dlc: u8,
    },
    pad: u8 = 0,
    res0: u8 = 0,
    len8_dlc: u8 = 0,
    data: [8]u8 align(8),
};

/// CAN flexible data rate frame taken from <linux/can.h>
const CanFdFrame = extern struct {
    can_id: msg.CanId,
    len: u8,
    flags: u8,
    res0: u8,
    res1: u8,
    data: [64]u8 align(8),
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
        else => true,
    };
}
pub const Filter = extern struct {
    id: u32,
    maks: u32,
};

/// Error from <linux/can/error.h>
pub const Error = extern struct {
    pub const Class = packed struct(u32) {
        /// TX timeout
        tx_timeout: bool,
        /// Lost arbitration: data[0]
        lostarb: bool,
        /// Controller problem: data[1]
        ctrl: bool,
        /// Protocol violations: data[2..4]
        prot: bool,
        // Transceiver status: data[4]
        trx: bool,
        /// No ACK received on transmission
        ack: bool,
        /// Bus off
        bus_off: bool,
        /// Bus error (may flood)
        bus_error: bool,
        /// Controller restarted
        restarted: bool,
        /// TX counter error: data[6]
        /// RX counter error: data[7]
        cnt: bool,
        _pad: u22,
    };
    pub const Controller = packed struct(u8) {
        /// RX buffer overflow
        rx_overflow: bool,
        /// TX buffer overflow
        tx_overflow: bool,
        /// Warning level reached for RX errors
        rx_warning: bool,
        /// Warning level reached for TX errors
        tx_warning: bool,
        /// Error passive status RX reached
        rx_passive: bool,
        /// Error passive status TX reached
        tx_passive: bool,
        _pad: u2,

        pub fn from(raw: u8) Controller {
            return @bitCast(raw);
        }
    };
    pub const Protocol = packed struct(u16) {
        /// Single bit error
        bit: bool,
        /// Frame format error
        form: bool,
        /// Bit stuffing error
        stuff: bool,
        /// Unable to send dominant bit
        bit0: bool,
        /// Unable to send recessive bit
        bit1: bool,
        /// Bus overload
        overload: bool,
        /// Active error announcement
        active: bool,
        /// Transmission error
        tx: bool,
        /// Location
        location: enum(u8) {
            /// No error
            no_error = 0x00,
            /// Start of frame
            sof = 0x03,
            /// ID bits 28 - 21 (SFF: 10 - 3)
            id28_21 = 0x02,
            /// ID bits 20 - 18 (SFF: 2 - 0)
            id20_18 = 0x02,
            /// Substitute RTR (SFF: RTR)
            srtr = 0x04,
            /// Identifier extension
            ide = 0x05,
            /// ID bits 17-13
            id17_13 = 0x07,
            /// ID bits 12-5
            id12_05 = 0x0F,
            /// ID bits 4-0
            id04_00 = 0x0E,
            /// RTR
            rtr = 0x0C,
            /// Reserved bit 1
            res1 = 0x0D,
            /// Reserved bit 0
            res0 = 0x09,
            /// Data length code
            dlc = 0x0B,
            /// Data section
            data = 0x0A,
            /// CRC sequence
            crc_seq = 0x08,
            /// CRC delimiter
            crc_del = 0x18,
            /// ACK slot
            ack = 0x19,
            /// ACK delimiter
            ack_del = 0x1B,
            /// End of frame
            eof = 0x1A,
            /// Intermission
            interm = 0x12,
        },

        pub fn from(raw: [2]u8) Controller {
            return @bitCast(std.mem.readInt(u16, &raw, .little));
        }
    };
    pub const Transceiver = packed struct(u8) {
        pub const Error = enum(u3) {
            /// No error
            no_error = 0x00,
            /// No wire
            no_wire = 0x04,
            /// Shot circuited to battery voltage
            short_to_bat = 0x05,
            /// Shot circuited to supply voltage
            short_to_vcc = 0x06,
            /// Shot circuited to ground
            short_to_gnd = 0x07,
        };

        can_high: Transceiver.Error,
        _pad: bool,
        can_low: Transceiver.Error,
        low_short_to_high: bool,

        pub fn from(raw: u8) Transceiver {
            return @bitCast(raw);
        }
    };
    pub const Counter = enum(u8) {
        _,

        pub fn from(raw: u8) Counter {
            return @enumFromInt(raw);
        }

        pub const State = enum { error_active, error_warning, error_passive };
        pub fn state(self: Counter) State {
            return switch (@intFromEnum(self)) {
                0...95 => .error_active,
                96...127 => .error_warning,
                128...255 => .error_passive,
            };
        }
    };

    class: Class,
    _pad: u32,
    data: [8]u8 align(8),

    pub fn controller(self: *const Error) Controller {
        return .from(self.data[1]);
    }
    pub fn protocol(self: *const Error) Error.Protocol {
        return .from(self.data[2..3]);
    }
    pub fn transceiver(self: *const Error) Transceiver {
        return .from(self.data[4]);
    }
    pub fn tx_error_counter(self: *const Error) Counter {
        return .from(self.data[6]);
    }
    pub fn rx_error_counter(self: *const Error) Counter {
        return .from(self.data[7]);
    }
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
            .ifrn = .{ .name = .{0} ** linux.IFNAMESIZE },
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

    pub const ReadError = error{Unexpected};
    pub fn read(self: *Bus) ReadError!Message {
        _ = &self;

        unreachable;
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

            _ = try posix.write(self.handle, asBytes(frame));
        } else {
            var frame: CanFrame = .{
                .can_id = message.id,
                .len = .{ .len = message.len },
                .data = undefined,
            };
            @memcpy(&frame.data, message.data[0..8]);

            _ = try posix.write(self.handle, asBytes(&frame));
        }
    }

    pub const SetError = posix.SetSockOptError;
    pub fn set(
        self: *const Bus,
        comptime option: Option,
        value: OptionType(option),
    ) SetError!void {
        try posix.setsockopt(
            self,
            SOL.CAN_RAW,
            @intFromEnum(option),
            asBytes(&value),
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
const Message = zano.Message;
