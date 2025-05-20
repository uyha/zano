pub const TimerFd = struct {
    handle: posix.fd_t,

    pub const ClockId = enum(c_int) {
        realtime = linux.CLOCK_REALTIME,
        monotonic = linux.CLOCK_MONOTONIC,
        boottime = linux.CLOCK_BOOTTIME,
        realtime_alarm = linux.CLOCK_REALTIME_ALARM,
        boottime_alarm = linux.CLOCK_BOOTTIME_ALARM,
    };
    pub const InitFlags = packed struct(c_int) {
        _pad0: u11 = 0,
        non_block: bool = false,
        _pad1: u7 = 0,
        close_on_exec: bool = false,
        _pad2: u12 = 0,

        pub const none: InitFlags = .{};
        pub const nonblock: InitFlags = .{ .non_block = true };
        pub const cloexec: InitFlags = .{ .close_on_exec = true };
        pub const all: InitFlags = .{
            .non_block = true,
            .close_on_exec = true,
        };

        comptime {
            checkValues(InitFlags, .{
                .{ "non_block", "TFD_NONBLOCK" },
                .{ "close_on_exec", "TFD_CLOEXEC" },
            });
        }
    };
    pub const InitError = posix.TimerFdCreateError;
    pub fn init(clock_id: ClockId, flags: InitFlags) InitError!TimerFd {
        return .{
            .handle = try posix.timerfd_create(
                @enumFromInt(@intFromEnum(clock_id)),
                @bitCast(flags),
            ),
        };
    }

    pub fn deinit(self: *TimerFd) void {
        posix.close(self.handle);

        self.handle = undefined;
    }

    pub const ReadError = posix.ReadError;
    pub fn read(self: *TimerFd) ReadError!usize {
        var result: usize = undefined;

        _ = try posix.read(self.handle, std.mem.asBytes(&result));

        return result;
    }

    pub const TimeSpec = extern struct {
        // https://github.com/ziglang/zig/issues/4726#issuecomment-2190337877
        const Size = if (native_arch == .riscv32) i64 else isize;

        seconds: Size,
        nanoseconds: Size,

        pub const zero: TimeSpec = .{ .sec = 0, .nsec = 0 };
        pub fn sec(seconds: Size) TimeSpec {
            return .init(seconds, 0);
        }
        pub fn nsec(nanoseconds: Size) TimeSpec {
            return .init(0, nanoseconds);
        }
        pub fn init(seconds: Size, nanoseconds: Size) TimeSpec {
            return .{
                .seconds = seconds,
                .nanoseconds = nanoseconds,
            };
        }
    };
    pub const TimerSpec = union(enum) {
        abstime: struct {
            interval: posix.system.timespec,
            value: posix.system.timespec,
            cancel_on_set: bool,
        },
        reltime: posix.system.itimerspec,

        pub fn at(value: TimeSpec) TimerSpec {
            return abs(.{ .sec = 0, .nsec = 0 }, value, false);
        }
        pub fn abs(
            interval: TimeSpec,
            value: TimeSpec,
            cancel_on_set: bool,
        ) TimerSpec {
            return .{ .abstime = .{
                .interval = @bitCast(interval),
                .value = @bitCast(value),
                .cancel_on_set = cancel_on_set,
            } };
        }

        pub fn every(interval: TimeSpec) TimerSpec {
            return rel(interval, interval);
        }
        pub fn once(value: TimeSpec) TimerSpec {
            return rel(.{ .sec = 0, .nsec = 0 }, value);
        }
        pub fn rel(interval: TimeSpec, value: TimeSpec) TimerSpec {
            return .{ .reltime = .{
                .it_interval = @bitCast(interval),
                .it_value = @bitCast(value),
            } };
        }
    };
    pub const SetError = posix.TimerFdSetError;
    pub fn set(
        self: *TimerFd,
        new: TimerSpec,
    ) SetError!void {
        return self.setImpl(new, null);
    }
    pub fn exchange(
        self: *TimerFd,
        new: TimerSpec,
    ) SetError!TimerSpec {
        var result: posix.system.itimerspec = undefined;

        try self.setImpl(new, &result);

        return result;
    }

    fn setImpl(
        self: *TimerFd,
        new: TimerSpec,
        old: ?*posix.system.itimerspec,
    ) SetError!void {
        var flags = std.mem.zeroes(posix.system.TFD.TIMER);
        var spec: posix.system.itimerspec = undefined;

        switch (new) {
            .abstime => |*value| {
                flags = .{
                    .ABSTIME = true,
                    .CANCEL_ON_SET = value.cancel_on_set,
                };
                spec = .{
                    .it_interval = @bitCast(value.interval),
                    .it_value = @bitCast(value.value),
                };
            },
            .reltime => |*value| {
                spec = value.*;
            },
        }

        try posix.timerfd_settime(self.handle, flags, &spec, old);
    }

    pub const GetError = posix.TimerFdGetError;
    pub fn get(self: *TimerFd) GetError!posix.system.itimerspec {
        return posix.timerfd_gettime(self.handle);
    }
};

const std = @import("std");
const posix = std.posix;

const native_arch = @import("builtin").cpu.arch;

const linux = @import("linux");
const checkValues = @import("utils.zig").checkValues;
