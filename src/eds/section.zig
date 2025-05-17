pub const FeedError = fmt.ParseIntError || error{
    KeyUnrecognized,
    ValueInvalid,
};

pub const Section = union(enum) {
    file_info: FileInfo,
    device_info: DeviceInfo,

    pub fn feed(self: *Section, entry: parse.Entry) FeedError!void {
        return switch (self.*) {
            inline else => |*section| section.feed(entry),
        };
    }
};

pub const FileInfo = struct {
    pub const map = .{
        .{ "FileName", "file_name" },
        .{ "FileVersion", "file_version" },
        .{ "FileRevision", "file_revision" },
        .{ "EDSVersion", "eds_version" },
        .{ "Description", "description" },
        .{ "CreationTime", "creation_time" },
        .{ "CreationDate", "creation_date" },
        .{ "CreatedBy", "created_by" },
        .{ "ModificationTime", "modification_time" },
        .{ "ModificationDate", "modification_date" },
        .{ "ModifiedBy", "modified_by" },
    };

    file_name: ?[]const u8 = null,
    file_version: ?u8 = null,
    file_revision: ?u8 = null,
    eds_version: ?[3]u8 = null,
    description: ?[]const u8 = null,
    /// Format: hh:mm(AM|PM)
    creation_time: ?[7]u8 = null,
    /// Format: mm-dd-yyyy
    creation_date: ?[10]u8 = null,
    created_by: ?[]const u8 = null,
    /// Format: hh:mm(AM|PM)
    modification_time: ?[7]u8 = null,
    /// Format: mm-dd-yyyy
    modification_date: ?[10]u8 = null,
    modified_by: ?[]const u8 = null,

    pub fn feed(self: *FileInfo, entry: parse.Entry) FeedError!void {
        inline for (map) |map_entry| {
            const key, const field = map_entry;
            if (ieql(key, entry.key)) {
                @field(self, field) = try entry.as(StripOptional(
                    @FieldType(FileInfo, field),
                ));
                return;
            }
        }

        return FeedError.KeyUnrecognized;
    }
};

pub const DeviceInfo = struct {
    pub const map = .{
        .{ "VendorName", "vendor_name" },
        .{ "VendorNumber", "vendor_number" },
        .{ "ProductName", "product_name" },
        .{ "ProductNumber", "product_number" },
        .{ "RevisionNumber", "revision_number" },
        .{ "OrderCode", "order_code" },
        .{ "BaudRate_10", "baud_rate_10" },
        .{ "BaudRate_20", "baud_rate_20" },
        .{ "BaudRate_50", "baud_rate_50" },
        .{ "BaudRate_125", "baud_rate_125" },
        .{ "BaudRate_250", "baud_rate_250" },
        .{ "BaudRate_500", "baud_rate_500" },
        .{ "BaudRate_800", "baud_rate_800" },
        .{ "BaudRate_1000", "baud_rate_1000" },
        .{ "SimpleBootUpMaster", "simple_boot_up_master" },
        .{ "SimpleBootUpSlave", "simple_boot_up_slave" },
        .{ "Granularity", "granularity" },
        .{ "DynamicChannelSupported", "dynamic_channel_supported" },
        .{ "GroupMessaging", "group_messaging" },
        .{ "NrOfRxPdo", "number_of_rx_pdo" },
        .{ "NrOfTxPdo", "number_of_tx_pdo" },
        .{ "LSS_Supported", "lss_supported" },
    };

    vendor_name: ?[]const u8 = null,
    vendor_number: ?u32 = null,
    product_name: ?[]const u8 = null,
    product_number: ?u32 = null,
    revision_number: ?u32 = null,
    order_code: ?[]const u8 = null,
    baud_rate_10: ?bool = null,
    baud_rate_20: ?bool = null,
    baud_rate_50: ?bool = null,
    baud_rate_125: ?bool = null,
    baud_rate_250: ?bool = null,
    baud_rate_500: ?bool = null,
    baud_rate_800: ?bool = null,
    baud_rate_1000: ?bool = null,
    simple_boot_up_master: ?bool = null,
    simple_boot_up_slave: ?bool = null,
    granularity: ?u8 = null,
    dynamic_channel_supported: ?bool = null,
    group_messaging: ?bool = null,
    number_of_rx_pdo: ?u16 = null,
    number_of_tx_pdo: ?u16 = null,
    lss_supported: ?bool = null,

    pub fn feed(self: *DeviceInfo, entry: parse.Entry) FeedError!void {
        inline for (map) |map_entry| {
            const key, const field = map_entry;
            if (ieql(key, entry.key)) {
                @field(self, field) = try entry.as(StripOptional(
                    @FieldType(DeviceInfo, field),
                ));
                return;
            }
        }

        return FeedError.KeyUnrecognized;
    }
};

pub const DummyUsage = struct {
    bool: ?bool = null,

    i8: ?bool = null,
    i16: ?bool = null,
    i32: ?bool = null,

    u8: ?bool = null,
    u16: ?bool = null,
    u32: ?bool = null,

    i24: ?bool = null,

    i40: ?bool = null,
    i48: ?bool = null,
    i56: ?bool = null,
    i64: ?bool = null,

    u24: ?bool = null,

    u40: ?bool = null,
    u48: ?bool = null,
    u56: ?bool = null,
    u64: ?bool = null,
};

pub fn Entry(T: type) type {
    return struct {
        entry: parse.Entry,
        value: T,
    };
}
fn StripOptional(T: type) type {
    return switch (@typeInfo(T)) {
        .optional => |info| info.child,
        else => T,
    };
}

fn ieql(lhs: []const u8, rhs: []const u8) bool {
    if (lhs.len != rhs.len) {
        return false;
    }

    for (lhs, rhs) |l, r| {
        if (ascii.toLower(l) != ascii.toLower(r)) {
            return false;
        }
    }
    return true;
}

test FileInfo {
    const t = std.testing;

    const content =
        \\[FileInfo]
        \\FileName=vendor1.eds
        \\FileVersion=1
        \\FileRevision=2
        \\EDSVersion=4.0
        \\Description=EDS for simple I/O-device
        \\CreationTime=09:45AM
        \\CreationDate=05-15-1995
        \\CreatedBy=Zaphod Beeblebrox
        \\ModificationTime=11:30PM
        \\ModificationDate=08-21-1995
        \\ModifiedBy=Zaphod Beeblebrox
    ;

    var iter = std.mem.tokenizeAny(u8, content, "\r\n");

    {
        const line = parse.line(iter.next().?);
        try t.expectEqualStrings("FileInfo", line.content.section);
    }

    var section: FileInfo = .{};

    while (iter.next()) |raw| {
        const line = parse.line(raw).content.entry;
        section.feed(line) catch |err| {
            std.debug.print("{s} is not recognized\n", .{line.key});
            return err;
        };
    }

    try t.expectEqualStrings("vendor1.eds", section.file_name.?);
    try t.expectEqual(1, section.file_version.?);
    try t.expectEqual(2, section.file_revision.?);
    try t.expectEqualStrings("4.0", &section.eds_version.?);
    try t.expectEqualStrings("EDS for simple I/O-device", section.description.?);
    try t.expectEqualStrings("09:45AM", &section.creation_time.?);
    try t.expectEqualStrings("05-15-1995", &section.creation_date.?);
    try t.expectEqualStrings("Zaphod Beeblebrox", section.created_by.?);
    try t.expectEqualStrings("11:30PM", &section.modification_time.?);
    try t.expectEqualStrings("08-21-1995", &section.modification_date.?);
    try t.expectEqualStrings("Zaphod Beeblebrox", section.modified_by.?);
}

test DeviceInfo {
    const t = std.testing;

    const content =
        \\[DeviceInfo]
        \\VendorName=Nepp Ltd.
        \\VendorNumber=156678
        \\ProductName=E/A 64
        \\ProductNumber=45570
        \\RevisionNumber=1
        \\OrderCode=BUY ME - 177/65/0815
        \\LSS_Supported=0
        \\BaudRate_50=1
        \\BaudRate_250=1
        \\BaudRate_500=1
        \\BaudRate_1000=1
        \\SimpleBootUpSlave=1
        \\SimpleBootUpMaster=0
        \\NrOfRxPdo=1
        \\NrOfTxPdo=2
    ;

    var iter = std.mem.tokenizeAny(u8, content, "\r\n");
    {
        const line = parse.line(iter.next().?);
        try t.expectEqualStrings("DeviceInfo", line.content.section);
    }

    var section: DeviceInfo = .{};
    while (iter.next()) |raw| {
        const line: parse.Content = parse.line(raw).content;
        switch (line) {
            .entry => |entry| section.feed(entry) catch |err| {
                std.debug.print("{s} is not recognized\n", .{entry.key});
                return err;
            },
            .err => |err| {
                std.debug.print("{any}\n", .{err});
                std.debug.print("{s}\n", .{raw});
                return error.ValueInvalid;
            },
            else => {},
        }
    }

    try t.expectEqualStrings("Nepp Ltd.", section.vendor_name.?);
    try t.expectEqual(156678, section.vendor_number.?);
    try t.expectEqualStrings("E/A 64", section.product_name.?);
    try t.expectEqual(45570, section.product_number.?);
    try t.expectEqual(1, section.revision_number.?);
    try t.expectEqualStrings("BUY ME - 177/65/0815", section.order_code.?);
    try t.expect(!section.lss_supported.?);
    try t.expect(section.baud_rate_50.?);
    try t.expect(section.baud_rate_250.?);
    try t.expect(section.baud_rate_500.?);
    try t.expectEqual(null, section.baud_rate_800);
    try t.expect(section.baud_rate_1000.?);
    try t.expect(section.simple_boot_up_slave.?);
    try t.expect(!section.simple_boot_up_master.?);
    try t.expectEqual(1, section.number_of_rx_pdo.?);
    try t.expectEqual(2, section.number_of_tx_pdo.?);
}

const std = @import("std");
const ascii = std.ascii;
const fmt = std.fmt;

const parse = @import("parse.zig");
