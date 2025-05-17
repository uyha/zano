const parse = @import("dcf/parse.zig");
const eval = @import("dcf/eval.zig");

comptime {
    const t = @import("std").testing;

    t.refAllDecls(parse);
    t.refAllDecls(eval);
}
