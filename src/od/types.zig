pub const TimeOfDay = packed struct(u32) {
    ms: u28,
    _pad: u4 = 0,
    days: u16,
};

pub const TimeDifference = packed struct(u32) {
    ms: u28,
    _pad: u4 = 0,
    days: u16,
};

pub const PdoCommParam = struct {
    cob_id: u32,
    transmission_type: Transmission,
    inhibit_time: u16,
    event_timer: u16,
    sync_start_value: u8,
};
pub const Transmission = enum(u8) {
    /// A PDO message will be sent after a SYNC message but only if
    /// something has changed.
    acylic_sync = 0,
    /// Manufacturer specific
    event_driven_manufacturer = 0xFE,
    /// Device profile and application profile specifc
    event_driven_profile = 0xFF,

    _,

    /// If 1 <= transmission type <= 240, this function returns how many SYNC
    /// messages until a PDO message is sent.
    pub fn interval(self: Transmission) ?u8 {
        const raw = @intFromEnum(self);
        return if (1 <= raw and raw <= 240) raw else null;
    }
};

pub const PdoMapping = struct {
    len: u8,
    objects: [64]Address,
};
pub const Address = struct {
    index: u16,
    sub: ?u8 = null,
};

pub const SdoParam = struct {
    /// Client to server COB-ID
    cob_id_ctos: u32,
    /// Server to client COB-ID
    cob_id_stoc: u32,
    node_id: u8,
};

pub const Identity = struct {
    vendor_id: u32,
    product_code: u32,
    revision_number: u32,
    serial_number: u32,
};

pub const Device = packed struct(u32) {
    profile_number: u16,
    additional_info: u16,
};

pub const Error = packed struct(u8) {
    generic_error: bool,
    current: bool,
    voltage: bool,
    temperature: bool,
    communication_error: bool,
    device_profile_specific: bool,
    _pad: u1 = 0,
    manufacturer_specific: bool,
};

// TODO: Implement this
pub const ErrorHistory = struct {};

pub const SyncCobId = packed struct(u32) {
    /// The ID of the SYNC message
    id: u29,
    /// Whether SYNC message is an extended frame
    ext: bool = false,
    /// Whether the CANopen device generates SYNC messages
    gen: bool,
    _pad: u1 = 0,
};

pub const TimeCobId = packed struct(u32) {
    /// The ID of the TIME message
    id: u29,

    /// Whether TIME message is exteneded frame
    ext: bool = false,

    /// Whether the CANopen device produces TIME messages
    produce: bool = false,
    /// Whether the CANopen device consumes TIME messages
    consume: bool = false,
};

pub const EmcyCobId = packed struct(u32) {
    /// The ID of the TIME message
    id: u29,
    /// Whether SYNC message is an extended frame
    ext: bool = false,
    _pad: u1 = 0,
    /// Whether EMCY exists / is valid
    valid: bool,
};
