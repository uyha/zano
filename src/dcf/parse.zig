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

pub const Error = error{InvalidInput};
/// This assumes the `content` parameter contains no newline character (neither
/// '\r' nor '\n')
pub fn line(content: []const u8, row: usize) Error!Line {
    return comment(content, row);
}
fn comment(content: []const u8, row: usize) Error!Line {
    if (content.len >= 1 and content[0] == ';') {
        return .{ .comment = .{
            .content = content,
            .row = row,
        } };
    }
    return section(content, row);
}
fn section(content: []const u8, row: usize) Error!Line {
    if (content.len < 3 or content[0] != '[' or content[1] == ']') {
        return entry(content, row);
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
        return .{ .section = .{
            .content = content,
            .name = content[1..i],
            .row = row,
        } };
    }

    return entry(content, row);
}
fn entry(content: []const u8, row: usize) Error!Line {
    if (content.len > 0 and content[0] == '=') {
        return empty(content, row);
    }

    const key, const value = blk: {
        for (content, 0..) |c, i| {
            switch (c) {
                '=' => break :blk .{ content[0..i], content[i + 1 ..] },
                '0'...'9', 'A'...'Z', 'a'...'z' => {},
                else => return empty(content, row),
            }
        }
        return empty(content, row);
    };

    return .{ .entry = .{
        .content = content,
        .key = key,
        .value = trim(u8, value, " \t"),
        .row = row,
    } };
}
fn empty(content: []const u8, row: usize) Error!Line {
    for (content) |c| {
        switch (c) {
            ' ', '\t' => {},
            else => return Error.InvalidInput,
        }
    }

    return .{ .empty = .{ .content = content, .row = row } };
}

pub const Line = union(enum) {
    comment: Comment,
    section: Section,
    entry: Entry,
    empty: Empty,
};
pub const Comment = struct {
    content: []const u8,
    row: usize,
};
pub const Section = struct {
    content: []const u8,
    /// Section name is case insensitive
    name: []const u8,
    row: usize,
};
pub const Entry = struct {
    content: []const u8,
    /// Entry key is case insensitive
    key: []const u8,
    value: []const u8,
    row: usize,
};

pub const Empty = struct {
    content: []const u8,
    row: usize,
};

test comment {
    const t = std.testing;

    {
        const content = "; This is a comment ";
        const row: usize = 1;

        const actual = try line(content, row);

        try t.expectEqualStrings(content, actual.comment.content);
        try t.expectEqual(row, actual.comment.row);
    }
}

test section {
    const t = std.testing;

    {
        const content = "[section name] ";
        const row: usize = 1;

        const actual = try line(content, row);

        try t.expectEqualStrings(content, actual.section.content);
        try t.expectEqualStrings("section name", actual.section.name);
        try t.expectEqual(row, actual.section.row);
    }

    {
        const content = "[ spaces ]  ";
        const row: usize = 1;

        const actual = try line(content, row);

        try t.expectEqualStrings(content, actual.section.content);
        try t.expectEqualStrings(" spaces ", actual.section.name);
        try t.expectEqual(row, actual.section.row);
    }
}

test entry {
    const t = std.testing;

    {
        const content = "2kEy1=value ";
        const row: usize = 1;

        const actual = try line(content, row);

        try t.expectEqualStrings(content, actual.entry.content);
        try t.expectEqualStrings("2kEy1", actual.entry.key);
        try t.expectEqualStrings("value", actual.entry.value);
        try t.expectEqual(row, actual.entry.row);
    }
    {
        const content = "key=\t  \tvalue value \t ";
        const row: usize = 1;

        const actual = try line(content, row);

        try t.expectEqualStrings(content, actual.entry.content);
        try t.expectEqualStrings("key", actual.entry.key);
        try t.expectEqualStrings("value value", actual.entry.value);
        try t.expectEqual(row, actual.entry.row);
    }
    {
        const content = "key=";
        const row: usize = 1;

        const actual = try line(content, row);

        try t.expectEqualStrings(content, actual.entry.content);
        try t.expectEqualStrings("key", actual.entry.key);
        try t.expectEqualStrings("", actual.entry.value);
        try t.expectEqual(row, actual.entry.row);
    }
    {
        const content = "key=0xasdj";
        const row: usize = 1;

        const actual = try line(content, row);

        try t.expectEqualStrings(content, actual.entry.content);
        try t.expectEqualStrings("key", actual.entry.key);
        try t.expectEqualStrings("0xasdj", actual.entry.value);
        try t.expectEqual(row, actual.entry.row);
    }
}

test empty {
    const t = std.testing;

    {
        const content = "";
        const row: usize = 1;

        const actual = try line(content, row);

        try t.expectEqualStrings(content, actual.empty.content);
        try t.expectEqual(row, actual.empty.row);
    }
    {
        const content = " \t ";
        const row: usize = 1;

        const actual = try line(content, row);

        try t.expectEqualStrings(content, actual.empty.content);
        try t.expectEqual(row, actual.empty.row);
    }
}

test "Invalid lines" {
    const t = std.testing;

    try t.expectEqual(Error.InvalidInput, line("asfd", 1));
    try t.expectEqual(Error.InvalidInput, line("[]", 1));
    try t.expectEqual(Error.InvalidInput, line(" [section]a", 1));
    try t.expectEqual(Error.InvalidInput, line("[section]a", 1));
    try t.expectEqual(Error.InvalidInput, line(" ;a", 1));
    try t.expectEqual(Error.InvalidInput, line("asdf;asdf=", 1));
    try t.expectEqual(Error.InvalidInput, line(" =", 1));
}

const std = @import("std");
const trim = std.mem.trim;
