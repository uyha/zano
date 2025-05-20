pub const Epoll = struct {
    handle: usize,

    pub const InitFlags = packed struct(u32) {
        _pad0: u19 = 0,
        close_on_exec: bool = false,
        _pad1: u12 = 0,

        pub const none: InitFlags = .{};
        pub const all: InitFlags = .{ .close_on_exec = true };

        comptime {
            checkValues(InitFlags, .{
                .{ "close_on_exec", "EPOLL_CLOEXEC" },
            });
        }
    };
    pub fn init(flags: InitFlags) posix.EpollCreateError!Epoll {
        return .{
            .handle = @intCast(try posix.epoll_create1(@bitCast(flags))),
        };
    }
    pub fn deinit(self: *Epoll) void {
        posix.close(@intCast(self.handle));

        self.handle = undefined;
    }

    pub const Data = extern union {
        pointer: ?*anyopaque,
        file_descriptor: c_int,
        u32: u32,
        u64: u64,

        pub fn ptr(value: ?*anyopaque) Data {
            return .{ .pointer = value };
        }
        pub fn fd(value: c_int) Data {
            return .{ .file_descriptor = value };
        }
        pub fn uint32(value: u32) Data {
            return .{ .u32 = value };
        }
        pub fn uint64(value: u64) Data {
            return .{ .u64 = value };
        }
    };

    pub const InputEvents = packed struct(u32) {
        epoll_in: bool = false,
        epoll_pri: bool = false,
        epoll_out: bool = false,
        epoll_err: bool = false,
        epoll_hup: bool = false,
        _pad0: u8 = 0,
        epoll_rdhup: bool = false,
        _pad1: u14 = 0,
        exclusive: bool = false,
        wakeup: bool = false,
        oneshot: bool = false,
        edge_trigger: bool = false,

        pub const none: InputEvents = .{};
        pub const in: InputEvents = .{ .epoll_in = true };
        pub const ierr: InputEvents = .{ .epoll_in = true, .epoll_err = true };
        pub const out: InputEvents = .{ .epoll_out = true };
        pub const err: InputEvents = .{ .epoll_err = true };
        pub const inout: InputEvents = .{ .epoll_in = true, .epoll_out = true };
        pub const all: InputEvents = .{
            .epoll_in = true,
            .epoll_pri = true,
            .epoll_out = true,
            .epoll_err = true,
            .epoll_hup = true,
            .epoll_rdhup = true,
        };

        comptime {
            checkValues(InputEvents, .{
                .{ "epoll_in", "EPOLLIN" },
                .{ "epoll_pri", "EPOLLPRI" },
                .{ "epoll_out", "EPOLLOUT" },
                .{ "epoll_err", "EPOLLERR" },
                .{ "epoll_hup", "EPOLLHUP" },
                .{ "epoll_rdhup", "EPOLLRDHUP" },
                .{ "exclusive", "EPOLLEXCLUSIVE" },
                .{ "wakeup", "EPOLLWAKEUP" },
                .{ "oneshot", "EPOLLONESHOT" },
                .{ "edge_trigger", "EPOLLET" },
            });
        }
    };
    pub const InputEvent = extern struct {
        events: InputEvents,
        data: Data,

        pub fn ptr(events: InputEvents, value: ?*anyopaque) InputEvent {
            return .{ .events = events, .data = .ptr(value) };
        }
        pub fn fd(events: InputEvents, value: c_int) InputEvent {
            return .{ .events = events, .data = .fd(value) };
        }
        pub fn uint32(events: InputEvents, value: u32) InputEvent {
            return .{ .events = events, .data = .unint32(value) };
        }
        pub fn uint64(events: InputEvents, value: u64) InputEvent {
            return .{ .events = events, .data = .uint64(value) };
        }
    };

    pub fn add(
        self: *Epoll,
        fd: posix.fd_t,
        event: InputEvent,
    ) posix.EpollCtlError!void {
        return posix.epoll_ctl(
            @intCast(self.handle),
            linux.EPOLL_CTL_ADD,
            fd,
            @constCast(@ptrCast(&event)),
        );
    }
    pub fn del(self: *Epoll, fd: posix.fd_t) posix.EpollCtlError!void {
        return posix.epoll_ctl(
            @intCast(self.handle),
            linux.EPOLL_CTL_DEL,
            fd,
            null,
        );
    }
    pub fn modify(
        self: *Epoll,
        fd: posix.fd_t,
        event: InputEvent,
    ) posix.EpollCtlError!void {
        return posix.epoll_ctl(
            @intCast(self.handle),
            linux.EPOLL_CTL_MOD,
            fd,
            @constCast(@ptrCast(&event)),
        );
    }

    pub const WaitEvents = packed struct(u32) {
        epoll_in: bool = false,
        epoll_pri: bool = false,
        epoll_out: bool = false,
        epoll_err: bool = false,
        epoll_hup: bool = false,
        _pad0: u8 = 0,
        epoll_rdhup: bool = false,
        _pad1: u18 = 0,

        comptime {
            checkValues(WaitEvents, .{
                .{ "epoll_in", "EPOLLIN" },
                .{ "epoll_pri", "EPOLLPRI" },
                .{ "epoll_out", "EPOLLOUT" },
                .{ "epoll_err", "EPOLLERR" },
                .{ "epoll_hup", "EPOLLHUP" },
                .{ "epoll_rdhup", "EPOLLRDHUP" },
            });
        }
    };
    pub const WaitEvent = extern struct {
        event: WaitEvents,
        data: Data,
    };

    pub fn wait(
        self: *Epoll,
        events: []WaitEvent,
        /// milliseconds
        timeout: c_int,
    ) []WaitEvent {
        const ptr: [*]posix.system.epoll_event = @ptrCast(events.ptr);
        const count = posix.epoll_wait(
            @intCast(self.handle),
            ptr[0..events.len],
            timeout,
        );
        return events[0..count];
    }
};

const std = @import("std");
const posix = std.posix;

const linux = @import("linux");
const checkValues = @import("utils.zig").checkValues;
