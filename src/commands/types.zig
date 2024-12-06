pub const MAX_NAME_LEN = 16;
pub const MAX_HELP_LEN = 64;
pub const MAX_OUTPUT_SIZE = 1024;

pub const CommandContext = struct {
    args: []const u8,
    output_buffer: *CommandBuffer,
};

pub const CommandResult = enum {
    Success,
    Error,
};

pub const CommandBuffer = struct {
    data: [MAX_OUTPUT_SIZE]u8 = undefined,
    len: usize = 0,

    pub fn init() CommandBuffer {
        return .{};
    }

    pub fn write(self: *CommandBuffer, text: []const u8) bool {
        if (self.len + text.len > MAX_OUTPUT_SIZE) {
            return false;
        }
        @memcpy(self.data[self.len .. self.len + text.len], text);
        self.len += text.len;
        return true;
    }

    pub fn getOutput(self: *const CommandBuffer) []const u8 {
        return self.data[0..self.len];
    }
};
