const std = @import("std");

const dictionary = @embedFile("nynorsk_words.txt");

fn isWordInDict(word: []const u8) bool {
    var low: usize = 0;
    var high: usize = dictionary.len;

    while (low < high) {
        const mid = low + (high - low) / 2;
        
        var start = mid;
        while (start > 0 and dictionary[start - 1] != '\n') {
            start -= 1;
        }
        
        var end = mid;
        while (end < dictionary.len and dictionary[end] != '\n') {
            end += 1;
        }
        
        const line = dictionary[start..end];
        
        const cmp = std.mem.order(u8, word, line);
        switch (cmp) {
            .eq => return true,
            .lt => {
                if (start == 0) return false;
                high = start - 1;
            },
            .gt => {
                low = end + 1;
            },
        }
    }
    return false;
}

fn isUpper(cp: u21) bool {
    if (cp >= 'A' and cp <= 'Z') return true;
    if (cp == 0x00C6) return true; // Æ
    if (cp == 0x00D8) return true; // Ø
    if (cp == 0x00C5) return true; // Å
    return false;
}

fn toLower(cp: u21) u21 {
    if (isUpper(cp)) {
        return cp + 0x20;
    }
    return cp;
}

pub fn isValidIdentifier(ident: []const u8) bool {
    var utf8_view = std.unicode.Utf8View.init(ident) catch return true; // fallback to true if invalid utf8
    var iter = utf8_view.iterator();
    
    var segment_buf: [256]u8 = undefined;
    var seg_len: usize = 0;
    
    while (iter.nextCodepoint()) |cp| {
        const upper = isUpper(cp);
        const snake = cp == '_';
        const digit = cp >= '0' and cp <= '9';
        
        if (upper and seg_len > 0) {
            // camelCase boundary
            if (!isWordInDict(segment_buf[0..seg_len])) return false;
            seg_len = 0;
        } else if (snake) {
            // snake_case boundary
            if (seg_len > 0) {
                if (!isWordInDict(segment_buf[0..seg_len])) return false;
                seg_len = 0;
            }
            continue; // skip the '_'
        }
        
        if (!digit and !snake) {
            const lower_cp = toLower(cp);
            var byte_buf: [4]u8 = undefined;
            const bytes_written = std.unicode.utf8Encode(lower_cp, &byte_buf) catch 0;
            for (byte_buf[0..bytes_written]) |b| {
                if (seg_len < 256) {
                    segment_buf[seg_len] = b;
                    seg_len += 1;
                }
            }
        }
    }
    
    if (seg_len > 0) {
        if (!isWordInDict(segment_buf[0..seg_len])) return false;
    }
    
    return true;
}
