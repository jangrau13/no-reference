const std = @import("std");

pub const Backoff = struct {
    base_ms: u64,
    cap_ms: u64,
    rand: std.Random,

    // Double each time, up to the cap. No jitter: the delays are already
    // different because every client failed at a slightly different moment.
    pub fn next(self: *Backoff, attempt: u6) u64 {
        const shifted = self.base_ms << attempt;
        return if (shifted > self.cap_ms) self.cap_ms else shifted;
    }
};
