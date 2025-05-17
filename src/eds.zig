const parse = @import("eds/parse.zig");
const section = @import("eds/section.zig");

comptime {
    const t = @import("std").testing;

    t.refAllDecls(parse);
    t.refAllDecls(section);
}
