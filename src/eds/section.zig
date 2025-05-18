pub const FeedError = Allocator.Error || error{
    KeyUnrecognized,
    ValueInvalid,
    EntryOutOfOrder,
    KeyDuplicated,
};

fn assign(
    out: anytype,
    entry: parse.Entry,
) error{ ValueInvalid, KeyDuplicated }!void {
    const Target = StripOptional(@typeInfo(@TypeOf(out)).pointer.child);

    if (out.* != null) {
        return error.KeyDuplicated;
    }
    out.* = entry.as(Target) catch return error.ValueInvalid;
}

pub const Section = union(enum) {
    file_info: FileInfo,
    device_info: DeviceInfo,
    dummy_usage: DummyUsage,
    mandatory_objects: MandatoryObjects,
    optional_objects: OptionalObjects,
    manufacturer_objects: ManufacturerObjects,

    pub fn feed(
        self: *Section,
        entry: parse.Entry,
        allocator: Allocator,
    ) FeedError!void {
        return switch (self.*) {
            .manufacturer_objects, .optional_objects => |*section| section.feed(allocator, entry),
            inline else => |*section| section.feed(entry),
        };
    }

    pub fn deinit(self: *Section, allocator: Allocator) void {
        switch (self.*) {
            .mandatory_objects, .optional_objects => |*obj| obj.deinit(allocator),
            else => {},
        }
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
    // Format: x.y
    // Default: 3.0
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

    pub const empty: FileInfo = .{};

    pub fn feed(self: *FileInfo, entry: parse.Entry) FeedError!void {
        inline for (map) |map_entry| {
            const key, const field = map_entry;
            if (ieql(key, entry.key)) {
                return assign(&@field(self, field), entry);
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
    dynamic_channel_supported: ?u8 = null,
    group_messaging: ?bool = null,
    number_of_rx_pdo: ?u16 = null,
    number_of_tx_pdo: ?u16 = null,
    lss_supported: ?bool = null,

    pub const empty: DeviceInfo = .{};

    pub fn feed(self: *DeviceInfo, entry: parse.Entry) FeedError!void {
        inline for (map) |map_entry| {
            const key, const field = map_entry;
            if (ieql(key, entry.key)) {
                return assign(&@field(self, field), entry);
            }
        }

        return FeedError.KeyUnrecognized;
    }
};

pub const DummyUsage = struct {
    pub const map = .{
        .{ "Dummy0001", "bool" },
        .{ "Dummy0002", "i8" },
        .{ "Dummy0003", "i16" },
        .{ "Dummy0004", "i32" },
        .{ "Dummy0005", "u8" },
        .{ "Dummy0006", "u16" },
        .{ "Dummy0007", "u32" },
        .{ "Dummy0010", "i24" },
        .{ "Dummy0012", "i40" },
        .{ "Dummy0013", "i48" },
        .{ "Dummy0014", "i56" },
        .{ "Dummy0015", "i64" },
        .{ "Dummy0016", "u24" },
        .{ "Dummy0018", "u40" },
        .{ "Dummy0019", "u48" },
        .{ "Dummy001A", "u56" },
        .{ "Dummy001B", "u64" },
    };

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

    pub const empty: DummyUsage = .{};

    pub fn feed(self: *DummyUsage, entry: parse.Entry) FeedError!void {
        inline for (map) |map_entry| {
            const key, const field = map_entry;
            if (ieql(key, entry.key)) {
                return assign(&@field(self, field), entry);
            }
        }

        return FeedError.KeyUnrecognized;
    }
};

pub const MandatoryObjects = struct {
    supported_objects: ?u16 = null,
    @"1000": ?void = null,
    @"1001": ?void = null,
    @"1018": ?void = null,

    count: u16 = 0,

    pub const empty: MandatoryObjects = .{};

    pub fn feed(
        self: *MandatoryObjects,
        entry: parse.Entry,
    ) FeedError!void {
        if (ieql("SupportedObjects", entry.key)) {
            if (self.supported_objects != null) {
                return FeedError.KeyDuplicated;
            }

            self.supported_objects = fmt.parseInt(u16, entry.value, 0) catch
                return FeedError.ValueInvalid;
            return;
        }

        if (self.supported_objects == null) {
            return FeedError.EntryOutOfOrder;
        }

        const i = fmt.parseInt(u16, entry.key, 10) catch {
            return FeedError.KeyUnrecognized;
        };
        if (i > self.supported_objects.?) {
            return FeedError.KeyUnrecognized;
        }
        if (i != self.count + 1) {
            return FeedError.EntryOutOfOrder;
        }

        const index = fmt.parseInt(u16, entry.value, 0) catch {
            return FeedError.ValueInvalid;
        };

        switch (index) {
            0x1000 => if (self.@"1000" != null) {
                return FeedError.KeyDuplicated;
            } else {
                self.@"1000" = {};
            },
            0x1001 => if (self.@"1001" != null) {
                return FeedError.KeyDuplicated;
            } else {
                self.@"1001" = {};
            },
            0x1018 => if (self.@"1018" != null) {
                return FeedError.KeyDuplicated;
            } else {
                self.@"1018" = {};
            },
            else => return FeedError.ValueInvalid,
        }

        self.count += 1;
    }
};
pub const OptionalObjects = struct {
    supported_objects: ?u16 = null,
    objects: ObjectList = .empty,

    pub const empty: OptionalObjects = .{};

    pub fn deinit(self: *OptionalObjects, allocator: Allocator) void {
        self.objects.deinit(allocator);
    }

    pub fn feed(
        self: *OptionalObjects,
        allocator: Allocator,
        entry: parse.Entry,
    ) FeedError!void {
        if (ieql("SupportedObjects", entry.key)) {
            self.supported_objects = fmt.parseInt(u16, entry.value, 0) catch
                return FeedError.ValueInvalid;
            return;
        }

        if (self.supported_objects == null) {
            return FeedError.EntryOutOfOrder;
        }

        const i = fmt.parseInt(u16, entry.key, 10) catch
            return FeedError.KeyUnrecognized;
        if (i > self.supported_objects.?) {
            return FeedError.KeyUnrecognized;
        }
        if (i != self.objects.count() + 1) {
            return FeedError.EntryOutOfOrder;
        }

        const index = fmt.parseInt(u16, entry.value, 0) catch
            return FeedError.ValueInvalid;

        if ((index < 0x1000 or 0x1FFF < index) and
            (index < 0x6000 or 0xFFFF < index))
        {
            return FeedError.ValueInvalid;
        }

        try self.objects.put(allocator, index, {});
    }
};
pub const ManufacturerObjects = struct {
    supported_objects: ?u16 = null,
    objects: ObjectList = .empty,

    pub const empty: ManufacturerObjects = .{};

    pub fn deinit(self: *ManufacturerObjects, allocator: Allocator) void {
        self.objects.deinit(allocator);
    }

    pub fn feed(
        self: *ManufacturerObjects,
        allocator: Allocator,
        entry: parse.Entry,
    ) FeedError!void {
        if (ieql("SupportedObjects", entry.key)) {
            self.supported_objects = fmt.parseInt(u16, entry.value, 0) catch
                return FeedError.ValueInvalid;
            return;
        }

        if (self.supported_objects == null) {
            return FeedError.EntryOutOfOrder;
        }

        const i = fmt.parseInt(u16, entry.key, 10) catch
            return FeedError.KeyUnrecognized;
        if (i > self.supported_objects.?) {
            return FeedError.KeyUnrecognized;
        }
        if (i != self.objects.count() + 1) {
            return FeedError.EntryOutOfOrder;
        }

        const index = fmt.parseInt(u16, entry.value, 0) catch
            return FeedError.ValueInvalid;

        if (index < 0x2000 or 0x5FFF < index) {
            return FeedError.ValueInvalid;
        }

        try self.objects.put(allocator, index, {});
    }
};

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

    var section: FileInfo = .empty;

    var iter = std.mem.tokenizeAny(u8, content, "\r\n");
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
    try t.expectEqual(
        FeedError.KeyDuplicated,
        section.feed(parse.line("ModifiedBy=Zaphod Beeblebrox").content.entry),
    );
}

test DeviceInfo {
    const t = std.testing;

    const content =
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

    var section: DeviceInfo = .empty;

    var iter = std.mem.tokenizeAny(u8, content, "\r\n");
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
    try t.expectEqual(
        FeedError.KeyDuplicated,
        section.feed(parse.line("NrOfTxPdo=").content.entry),
    );
}

test DummyUsage {
    const t = std.testing;

    const content =
        \\Dummy0001=0
        \\Dummy0002=1
        \\Dummy0003=1
        \\Dummy0004=1
        \\Dummy0005=1
        \\Dummy0006=1
        \\Dummy0007=1
    ;

    var section: DummyUsage = .empty;

    var iter = std.mem.tokenizeAny(u8, content, "\r\n");
    while (iter.next()) |raw| {
        const line: parse.Content = parse.line(raw).content;
        switch (line) {
            .entry => |entry| section.feed(entry) catch |err| {
                std.debug.print("{}: {s}\n", .{ err, entry.key });
                return err;
            },
            .err => |err| {
                std.debug.print("{any}: {s}\n", .{ err, raw });
                return error.ValueInvalid;
            },
            else => {},
        }
    }

    try t.expect(!section.bool.?);
    try t.expect(section.u8.?);
    try t.expect(section.u16.?);
    try t.expect(section.u32.?);
    try t.expect(section.i8.?);
    try t.expect(section.i16.?);
    try t.expect(section.i32.?);
    try t.expectEqual(null, section.i64);
    try t.expectEqual(
        FeedError.KeyDuplicated,
        section.feed(parse.line("Dummy0007=").content.entry),
    );
}

test MandatoryObjects {
    const t = std.testing;

    const content =
        \\SupportedObjects=2
        \\1=0x1000
        \\2=0x1001
    ;

    var section: MandatoryObjects = .empty;

    var iter = std.mem.tokenizeAny(u8, content, "\r\n");
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

    try t.expectEqual(2, section.supported_objects.?);
    try t.expect({} == section.@"1000");
    try t.expect({} == section.@"1001");
    try t.expect(null == section.@"1018");
}

test OptionalObjects {
    const t = std.testing;
    const allocator = t.allocator;

    const content =
        \\SupportedObjects=11
        \\1=0x1003
        \\2=0x1004
        \\3=0x1005
        \\4=0x1008
        \\5=0x1009
        \\6=0x100A
        \\7=0x100C
        \\8=0x100D
        \\9=0x1010
        \\10=0x1011
    ;

    var section: OptionalObjects = .empty;
    defer section.deinit(allocator);

    var iter = std.mem.tokenizeAny(u8, content, "\r\n");
    while (iter.next()) |raw| {
        const line: parse.Content = parse.line(raw).content;
        switch (line) {
            .entry => |entry| section.feed(allocator, entry) catch |err| {
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

    try t.expectEqual(11, section.supported_objects.?);
    try t.expectEqual(10, section.objects.count());
    try t.expect(section.objects.contains(0x1003));
    try t.expect(section.objects.contains(0x1011));
    try t.expect(!section.objects.contains(0x1012));

    try t.expectEqual(
        FeedError.ValueInvalid,
        section.feed(allocator, parse.line("11=0x2000").content.entry),
    );
}

test ManufacturerObjects {
    const t = std.testing;
    const allocator = t.allocator;

    const content =
        \\SupportedObjects=11
        \\1=0x2000
        \\2=0x2001
        \\3=0x2002
        \\4=0x2003
        \\5=0x2004
        \\6=0x2005
        \\7=0x2006
        \\8=0x2007
        \\9=0x2008
        \\10=0x2009
    ;

    var section: ManufacturerObjects = .empty;
    defer section.deinit(allocator);

    var iter = std.mem.tokenizeAny(u8, content, "\r\n");
    while (iter.next()) |raw| {
        const line: parse.Content = parse.line(raw).content;
        switch (line) {
            .entry => |entry| section.feed(allocator, entry) catch |err| {
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

    try t.expectEqual(11, section.supported_objects.?);
    try t.expectEqual(10, section.objects.count());
    try t.expect(section.objects.contains(0x2000));
    try t.expect(section.objects.contains(0x2009));
    try t.expect(!section.objects.contains(0x200A));

    try t.expectEqual(
        FeedError.ValueInvalid,
        section.feed(allocator, parse.line("11=0x6000").content.entry),
    );
}

const std = @import("std");
const ascii = std.ascii;
const fmt = std.fmt;
const Allocator = std.mem.Allocator;

const ObjectList = std.AutoArrayHashMapUnmanaged(u16, void);

const parse = @import("parse.zig");
