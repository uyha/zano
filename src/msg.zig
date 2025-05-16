pub const CanId = packed struct(u32) {
    id: u29,
    err: bool = false,
    remote: bool = false,
    extended: bool = false,

    pub fn std(id: u16) CanId {
        return .{ .id = id & 0x7FF };
    }
    pub fn stdRemote(id: u16) CanId {
        return .{
            .id = id & 0x7FF,
            .remote = true,
        };
    }
    pub fn ext(id: u32) CanId {
        return .{
            .id = @intCast(id & 0x1F_FF_FF_FF),
            .extended = true,
        };
    }
    pub fn extRemote(id: u32) CanId {
        return .{
            .id = @intCast(id & 0x1F_FF_FF_FF),
            .remote = true,
            .extended = true,
        };
    }
};

const max_data_len = if (conf.can_fd) 64 else 8;
pub const Message = extern struct {
    id: CanId,
    len: u8,
    data: [max_data_len]u8 align(8),

    pub fn std(id: u16, data: []const u8) Message {
        const len: u8 = @intCast(if (data.len > 8) 8 else data.len);

        var message: Message = .{
            .id = .std(id),
            .len = len,
            .data = undefined,
        };

        @memcpy(message.data[0..len], data[0..len]);

        return message;
    }

    pub fn stdRemote(id: u16) Message {
        return .{ .id = .stdRemote(id), .len = 0, .data = undefined };
    }

    pub fn ext(id: u16, data: []const u8) Message {
        const len: u8 = @intCast(if (data.len > 8) 8 else data.len);

        var message: Message = .{
            .id = .ext(id),
            .len = len,
            .data = undefined,
        };

        @memcpy(message.data[0..len], data[0..len]);

        return message;
    }

    pub fn extRemote(id: u16) Message {
        return .{ .id = .extRemote(id), .len = 0, .data = undefined };
    }
};

/// Error from <linux/can/error.h>
pub const Error = extern struct {
    pub const Class = packed struct(u32) {
        /// TX timeout
        tx_timeout: bool = false,
        /// Lost arbitration: data[0]
        lostarb: bool = false,
        /// Controller problem: data[1]
        ctrl: bool = false,
        /// Protocol violations: data[2..4]
        prot: bool = false,
        // Transceiver status: data[4]
        trx: bool = false,
        /// No ACK received on transmission
        ack: bool = false,
        /// Bus off
        bus_off: bool = false,
        /// Bus error (may flood)
        bus_error: bool = false,
        /// Controller restarted
        restarted: bool = false,
        /// TX counter error: data[6]
        /// RX counter error: data[7]
        cnt: bool = false,
        _pad: u22 = 0,

        pub const all: Class = .{
            .tx_timeout = true,
            .lostarb = true,
            .ctrl = true,
            .prot = true,
            .trx = true,
            .ack = true,
            .bus_off = true,
            .bus_error = true,
            .restarted = true,
            .cnt = true,
        };
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
    _pad: u8,
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
    pub fn txErrCounter(self: *const Error) Counter {
        return .from(self.data[6]);
    }
    pub fn rxErrCounter(self: *const Error) Counter {
        return .from(self.data[7]);
    }
};

const std = @import("std");

const conf = @import("conf");
