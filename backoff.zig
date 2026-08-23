const std = @import("std");

pub const Backoff = struct {
    base_ms: u64,
    cap_ms: u64,
    rand: std.Random,

    pub fn next(self: *Backoff, attempt: u6) u64 {
        _ = attempt;
        return self.base_ms;
    }
};
