pub fn checkValues(comptime T: type, comptime map: anytype) void {
    const Value = @typeInfo(T).@"struct".backing_integer.?;

    for (map) |entry| {
        const field, const macro = entry;

        var events: T = std.mem.zeroes(T);
        @field(events, field) = true;
        const raw: Value = @bitCast(events);

        const linux_value = @field(linux, macro);
        if (raw != linux_value) {
            @compileError(std.fmt.comptimePrint(
                "Mismatched between {s} and {s}: {X} != {X}",
                .{ field, macro, raw, linux_value },
            ));
        }
    }
}

const std = @import("std");
const linux = @import("linux");
