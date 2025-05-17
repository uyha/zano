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
pub fn line(content: []const u8, row: usize) Line {
    return comment(content, row);
}
fn comment(content: []const u8, row: usize) Line {
    if (content.len >= 1 and content[0] == ';') {
        return .{
            .raw = content,
            .row = row,
            .content = .comment,
        };
    }
    return section(content, row);
}
fn section(content: []const u8, row: usize) Line {
    if (content.len < 2 or content[0] != '[') {
        return entry(content, row);
    }
    if (content[1] == ']') {
        return .{
            .raw = content,
            .row = row,
            .content = .{ .err = .section_empty },
        };
    }

    var end: ?usize = null;
    for (content[1..], 1..) |c, i| {
        if (end == null) {
            switch (c) {
                ']' => end = i,
                else => {},
            }
        } else {
            if (c != ' ' and c != '\t') {
                return entry(content, row);
            }
        }
    }

    if (end) |i| {
        return .{
            .raw = content,
            .row = row,
            .content = .{ .section = content[1..i] },
        };
    }

    return entry(content, row);
}
fn entry(content: []const u8, row: usize) Line {
    if (content.len > 0 and content[0] == '=') {
        return empty(content, row);
    }

    const key, const value = blk: {
        for (content, 0..) |c, i| {
            switch (c) {
                '=' => break :blk .{ content[0..i], content[i + 1 ..] },
                '0'...'9', 'A'...'Z', 'a'...'z', '_' => {},
                else => return empty(content, row),
            }
        }
        return empty(content, row);
    };

    return .{
        .raw = content,
        .row = row,
        .content = .{ .entry = .{
            .key = key,
            .value = trim(u8, value, " \t"),
        } },
    };
}
fn empty(content: []const u8, row: usize) Line {
    for (content) |c| {
        switch (c) {
            ' ', '\t' => {},
            else => return err(content, row),
        }
    }

    return .{ .raw = content, .row = row, .content = .empty };
}
fn err(content: []const u8, row: usize) Line {
    assert(content.len > 0);

    // Check for leading spaces in comment like lines
    {
        const slice = trimLeft(u8, content, " \t");
        if (slice[0] == ';') {
            return .{
                .raw = content,
                .row = row,
                .content = .{ .err = .{
                    .comment_leading_space = content.len - slice.len,
                } },
            };
        }
    }

    // Check for leading spaces in section like lines
    section_leading_space: {
        if (content[0] == '[') {
            break :section_leading_space;
        }

        const slice = trimLeft(u8, content, " \t");
        if (slice.len > 0 and slice[0] == '[') {
            return .{
                .raw = content,
                .row = row,
                .content = .{ .err = .{
                    .section_leading_space = content.len - slice.len,
                } },
            };
        }
    }

    // Check for trailing characters in secion like lines
    {
        var start_found = false;
        var end_found = false;

        for (content, 0..) |c, i| {
            if (!start_found) {
                start_found = c == '[';
            } else if (!end_found) {
                end_found = c == ']';
            } else if (c != ' ' and c != '\t') {
                return .{
                    .raw = content,
                    .row = row,
                    .content = .{ .err = .{
                        .section_trailing_character = i,
                    } },
                };
            }
        }
    }

    // Check for non alphanumeric keys
    entry_key_invalid: {
        for (content, 0..) |c, i| {
            switch (c) {
                '=' => break :entry_key_invalid,
                else => if (!ascii.isAlphanumeric(c) and c != '_') return .{
                    .raw = content,
                    .row = row,
                    .content = .{ .err = .{
                        .entry_key_invalid = i,
                    } },
                },
            }
        }
    }

    return .{
        .raw = content,
        .row = row,
        .content = .{ .err = .{
            .entry_missing_equal = content.len,
        } },
    };
}

pub const Line = struct {
    raw: []const u8,
    row: usize,
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

    pub const ParseError = std.fmt.ParseIntError || error{ValueInvalid};
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
            u8, u16, u32, u64, i8, i16, i32, i64 => return std.fmt.parseInt(T, self.value, 0),
            else => {},
        }

        const info = @typeInfo(T);

        switch (info) {
            .array => |array| {
                if (self.value.len != array.len) {
                    return ParseError.ValueInvalid;
                }
                return self.value[0..array.len].*;
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

    try t.expect(.comment == line("; This is a comment ", 1).content);
}

test section {
    const t = std.testing;

    try t.expectEqualStrings(
        "section name",
        line("[section name] ", 1).content.section,
    );
    try t.expectEqualStrings(
        " spaces ",
        line("[ spaces ]  ", 1).content.section,
    );
    try t.expectEqualStrings(
        ";spaces;",
        line("[;spaces;]  ", 1).content.section,
    );
}

test entry {
    const t = std.testing;

    {
        const actual = line("2kEy1=value ", 1);

        try t.expectEqualStrings("2kEy1", actual.content.entry.key);
        try t.expectEqualStrings("value", actual.content.entry.value);
    }
    {
        const actual = line("key=\t  \tvalue value \t ", 1);

        try t.expectEqualStrings("key", actual.content.entry.key);
        try t.expectEqualStrings("value value", actual.content.entry.value);
    }
    {
        const actual = line("key=", 1);

        try t.expectEqualStrings("key", actual.content.entry.key);
        try t.expectEqualStrings("", actual.content.entry.value);
    }
    {
        const actual = line("key=0xasdj", 1);

        try t.expectEqualStrings("key", actual.content.entry.key);
        try t.expectEqualStrings("0xasdj", actual.content.entry.value);
    }
}

test empty {
    const t = std.testing;

    try t.expect(.empty == line("", 1).content);
    try t.expect(.empty == line(" \t ", 1).content);
}

test err {
    const t = std.testing;

    try t.expectEqual(
        Error{ .comment_leading_space = 4 },
        line(" \t \t;", 1).content.err,
    );
    try t.expect(.entry_missing_equal == line("asfd", 1).content.err);
    try t.expectEqual(
        Error{ .section_leading_space = 3 },
        line(" \t [section]", 1).content.err,
    );
    try t.expectEqual(
        Error{ .section_trailing_character = 11 },
        line("[section] \tasdf", 1).content.err,
    );
    try t.expect(.section_empty == line("[]", 1).content.err);
    try t.expectEqual(
        Error{ .entry_key_invalid = 0 },
        line(" =", 1).content.err,
    );
    try t.expectEqual(
        Error{ .entry_key_invalid = 1 },
        line("1 =", 1).content.err,
    );
    try t.expectEqual(
        Error{ .entry_missing_equal = 1 },
        line("1", 1).content.err,
    );
}

const std = @import("std");
const ascii = std.ascii;
const trim = std.mem.trim;
const trimLeft = std.mem.trimLeft;
const assert = std.debug.assert;
