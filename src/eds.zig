pub const parse = @import("eds/parse.zig");
pub const section = @import("eds/section.zig");
pub const types = @import("eds/types.zig");

comptime {
    const t = @import("std").testing;

    t.refAllDecls(parse);
    t.refAllDecls(section);
}
