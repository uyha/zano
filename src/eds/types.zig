pub const Object = enum(u8) {
    null = 0x00,
    domain = 0x02,
    deftype = 0x05,
    defstruct = 0x06,
    @"var" = 0x07,
    array = 0x08,
    record = 0x09,
};
pub const Data = enum(u16) {
    bool = 0x0001,

    integer8 = 0x0002,
    integer16 = 0x0003,
    integer32 = 0x0004,

    unsigned8 = 0x0005,
    unsigned16 = 0x0006,
    unsigned32 = 0x0007,

    real32 = 0x0008,

    visible_string = 0x0009,
    octet_string = 0x000A,
    unicode_string = 0x000B,

    time_of_day = 0x000C,
    time_difference = 0x000D,

    domain = 0x000F,

    integer24 = 0x0010,

    real64 = 0x0011,

    integer40 = 0x0012,
    integer48 = 0x0013,
    integer56 = 0x0014,
    integer64 = 0x0015,

    unsigned24 = 0x0016,

    unsigned40 = 0x0018,
    unsigned48 = 0x0019,
    unsigned56 = 0x001A,
    unsigned64 = 0x001B,

    pdo_comm_param = 0x0020,
    pdo_mapping = 0x0021,
    sdo_parameter = 0x0022,
    identity = 0x0023,

    _,
};
pub const Access = enum { ro, wo, rw, rwr, rww, @"const" };
