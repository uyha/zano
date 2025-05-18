//! This provides the tools to parse a EDS/DCF file.
//!
//! The EBNF grammar:
//!
//! dcf = (line newline)* ;
//!
//! line = comment ;
//!
//! comment = ( ";" (character | space)* )
//!         | section ;
//!
//! section = ( "[" alphanum+ "]" space* )
//!         | entry ;
//!
//! entry = ( key "=" space* value space* )
//!       | empty ;
//! key   = alphanum+ ;
//! value = ""
//!       | (character ( character | space)* character)
//!       ;
//!
//! empty = space* ;
//!
//! character = letter | number | symbol ;
//! alphanum = letter | number ;
//! letter = "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" | "J" | "K"
//!        | "L" | "M" | "N" | "O" | "P" | "Q" | "R" | "S" | "T" | "U" | "V"
//!        | "W" | "X" | "Y" | "Z" | "a" | "b" | "c" | "d" | "e" | "f" | "g"
//!        | "h" | "i" | "j" | "k" | "l" | "m" | "n" | "o" | "p" | "q" | "r"
//!        | "s" | "t" | "u" | "v" | "w" | "x" | "y" | "z"
//!        ;
//! number = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" ;
//! symbol = "!" | '"' | "#" | "$" | "%" | "&" | "'" | "(" | ")" | "*" | "+"
//!        | "," | "-" | "." | "/" | ":" | ";" | "<" | "=" | ">" | "?" | "@"
//!        | "[" | "\" | "]" | "^" | "_" | "`" | "{" | "|" | "}" | "~"
//!        ;
//! space = " " | "\t" ;
//! newline = "\n" | "\r\n" ;

/// This assumes the `content` parameter contains no newline character (neither
/// '\r' nor '\n')
pub fn line(raw: []const u8) Line {
    return comment(raw);
}
fn comment(raw: []const u8) Line {
    if (raw.len >= 1 and raw[0] == ';') {
        return .{
            .raw = raw,
            .content = .comment,
        };
    }
    return section(raw);
}
fn section(raw: []const u8) Line {
    if (raw.len < 2 or raw[0] != '[') {
        return entry(raw);
    }
    if (raw[1] == ']') {
        return .{
            .raw = raw,
            .content = .{ .err = .section_empty },
        };
    }

    var end: ?usize = null;
    for (raw[1..], 1..) |c, i| {
        if (end == null) {
            switch (c) {
                ']' => end = i,
                else => {},
            }
        } else {
            if (c != ' ' and c != '\t') {
                return entry(raw);
            }
        }
    }

    if (end) |i| {
        return .{
            .raw = raw,
            .content = .{ .section = raw[1..i] },
        };
    }

    return entry(raw);
}
fn entry(content: []const u8) Line {
    if (content.len > 0 and content[0] == '=') {
        return empty(content);
    }

    const key, const value = blk: {
        for (content, 0..) |c, i| {
            switch (c) {
                '=' => break :blk .{ content[0..i], content[i + 1 ..] },
                '0'...'9', 'A'...'Z', 'a'...'z', '_' => {},
                else => return empty(content),
            }
        }
        return empty(content);
    };

    return .{
        .raw = content,
        .content = .{ .entry = .{
            .key = key,
            .value = trim(u8, value, " \t"),
        } },
    };
}
fn empty(raw: []const u8) Line {
    for (raw) |c| {
        switch (c) {
            ' ', '\t' => {},
            else => return err(raw),
        }
    }

    return .{ .raw = raw, .content = .empty };
}
fn err(raw: []const u8) Line {
    assert(raw.len > 0);

    // Check for leading spaces in comment like lines
    {
        const slice = trimLeft(u8, raw, " \t");
        if (slice[0] == ';') {
            return .{
                .raw = raw,
                .content = .{ .err = .{
                    .comment_leading_space = raw.len - slice.len,
                } },
            };
        }
    }

    // Check for leading spaces in section like lines
    section_leading_space: {
        if (raw[0] == '[') {
            break :section_leading_space;
        }

        const slice = trimLeft(u8, raw, " \t");
        if (slice.len > 0 and slice[0] == '[') {
            return .{
                .raw = raw,
                .content = .{ .err = .{
                    .section_leading_space = raw.len - slice.len,
                } },
            };
        }
    }

    // Check for trailing characters in secion like lines
    {
        var start_found = false;
        var end_found = false;

        for (raw, 0..) |c, i| {
            if (!start_found) {
                start_found = c == '[';
            } else if (!end_found) {
                end_found = c == ']';
            } else if (c != ' ' and c != '\t') {
                return .{
                    .raw = raw,
                    .content = .{ .err = .{
                        .section_trailing_character = i,
                    } },
                };
            }
        }
    }

    // Check for non alphanumeric keys
    entry_key_invalid: {
        for (raw, 0..) |c, i| {
            switch (c) {
                '=' => break :entry_key_invalid,
                else => if (!ascii.isAlphanumeric(c) and c != '_') return .{
                    .raw = raw,
                    .content = .{ .err = .{
                        .entry_key_invalid = i,
                    } },
                },
            }
        }
    }

    return .{
        .raw = raw,
        .content = .{ .err = .{
            .entry_missing_equal = raw.len,
        } },
    };
}

pub const Line = struct {
    raw: []const u8,
    content: Content,
};
pub const Content = union(enum) {
    comment: void,
    /// Section name is case insensitive
    section: []const u8,
    entry: Entry,
    empty: void,
    err: Error,
};
pub const Entry = struct {
    /// Entry key is case insensitive
    key: []const u8,
    value: []const u8,

    pub const ParseError = error{ValueInvalid};
    pub fn as(self: *const Entry, comptime T: type) ParseError!T {
        switch (T) {
            bool => {
                if (self.value.len != 1) {
                    return ParseError.ValueInvalid;
                }
                switch (self.value[0]) {
                    '0' => return false,
                    '1' => return true,
                    else => return ParseError.ValueInvalid,
                }
            },
            []const u8 => return self.value,
            u8, u16, u32, u64, i8, i16, i32, i64 => return std.fmt.parseInt(T, self.value, 0) catch {
                return ParseError.ValueInvalid;
            },
            else => {},
        }

        switch (@typeInfo(T)) {
            .array => |info| {
                if (self.value.len != info.len) {
                    return ParseError.ValueInvalid;
                }
                return self.value[0..info.len].*;
            },
            .@"enum" => |info| {
                // Taken from `std.enums.fromInt`
                if (std.fmt.parseInt(info.tag_type, self.value, 0)) |int| {
                    if (!info.is_exhaustive) {
                        return @enumFromInt(int);
                    }
                    for (std.enums.values(T)) |value| {
                        if (@intFromEnum(value) == int) {
                            return @enumFromInt(int);
                        }
                    }
                    return ParseError.ValueInvalid;
                } else |_| {
                    return std.meta.stringToEnum(T, self.value) orelse
                        return ParseError.ValueInvalid;
                }
            },
            .@"struct" => |info| {
                _ = &info;
                return ParseError.ValueInvalid;
            },
            else => @compileError(@typeName(T) ++ " is not supported"),
        }
    }
};
pub const Error = union(enum) {
    /// Point to the position of the first ";"
    comment_leading_space: usize,

    /// Point to the position of the first "["
    section_leading_space: usize,
    /// Point to the position of the first non-space character after "]"
    section_trailing_character: usize,
    section_empty: void,

    /// Point to the position of the first non alphanumeric character
    entry_key_invalid: usize,
    /// Point to the expected position for the equal symbol
    entry_missing_equal: usize,
};

test comment {
    const t = std.testing;

    try t.expect(.comment == line("; This is a comment ").content);
}

test section {
    const t = std.testing;

    try t.expectEqualStrings(
        "section name",
        line("[section name] ").content.section,
    );
    try t.expectEqualStrings(
        " spaces ",
        line("[ spaces ]  ").content.section,
    );
    try t.expectEqualStrings(
        ";spaces;",
        line("[;spaces;]  ").content.section,
    );
}

test entry {
    const t = std.testing;

    {
        const actual = line("2kEy1=value ");

        try t.expectEqualStrings("2kEy1", actual.content.entry.key);
        try t.expectEqualStrings("value", actual.content.entry.value);
    }
    {
        const actual = line("key=\t  \tvalue value \t ");

        try t.expectEqualStrings("key", actual.content.entry.key);
        try t.expectEqualStrings("value value", actual.content.entry.value);
    }
    {
        const actual = line("key=");

        try t.expectEqualStrings("key", actual.content.entry.key);
        try t.expectEqualStrings("", actual.content.entry.value);
    }
    {
        const actual = line("key=0xasdj");

        try t.expectEqualStrings("key", actual.content.entry.key);
        try t.expectEqualStrings("0xasdj", actual.content.entry.value);
    }
}

test empty {
    const t = std.testing;

    try t.expect(.empty == line("").content);
    try t.expect(.empty == line(" \t ").content);
}

test err {
    const t = std.testing;

    try t.expectEqual(
        Error{ .comment_leading_space = 4 },
        line(" \t \t;").content.err,
    );
    try t.expect(.entry_missing_equal == line("asfd").content.err);
    try t.expectEqual(
        Error{ .section_leading_space = 3 },
        line(" \t [section]").content.err,
    );
    try t.expectEqual(
        Error{ .section_trailing_character = 11 },
        line("[section] \tasdf").content.err,
    );
    try t.expect(.section_empty == line("[]").content.err);
    try t.expectEqual(
        Error{ .entry_key_invalid = 0 },
        line(" =").content.err,
    );
    try t.expectEqual(
        Error{ .entry_key_invalid = 1 },
        line("1 =").content.err,
    );
    try t.expectEqual(
        Error{ .entry_missing_equal = 1 },
        line("1").content.err,
    );
}

const std = @import("std");
const ascii = std.ascii;
const trim = std.mem.trim;
const trimLeft = std.mem.trimLeft;
const assert = std.debug.assert;
