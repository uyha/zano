const parse = @import("eds/parse.zig");
const eval = @import("eds/eval.zig");

comptime {
    const t = @import("std").testing;

    t.refAllDecls(parse);
    t.refAllDecls(eval);
}
