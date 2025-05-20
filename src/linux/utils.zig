pub fn checkValues(comptime T: type, comptime map: anytype) void {
    const Value = @typeInfo(T).@"struct".backing_integer.?;

    for (map) |entry| {
        const field, const macro = entry;

        var events: T = @bitCast(@as(Value, 0));
        @field(events, field) = true;
        const raw: Value = @bitCast(events);

        const linux_value = @field(linux, macro);
        if (raw != linux_value) {
            @compileError(
                "Mismatched between " ++ field ++ " and " ++ macro,
            );
        }
    }
}

const linux = @import("linux");
