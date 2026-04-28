const std = @import("std");

const dictionary = @embedFile("nynorsk_words.txt");

const plural_suffixes = [_][]const u8{
    "ane",
    "ene",
    "ar",
    "er",
    "or",
};

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

fn isValidWordForm(word: []const u8) bool {
    if (isWordInDict(word)) return true;
    return isPluralForm(word);
}

fn isPluralForm(word: []const u8) bool {
    for (plural_suffixes) |suffix| {
        if (tryPluralStem(word, suffix)) return true;
    }
    return false;
}

fn tryPluralStem(word: []const u8, suffix: []const u8) bool {
    if (!std.mem.endsWith(u8, word, suffix) or word.len <= suffix.len) return false;

    const stem = word[0 .. word.len - suffix.len];
    if (isWordInDict(stem)) return true;
    return isWordWithTrailingE(stem);
}

fn isWordWithTrailingE(stem: []const u8) bool {
    var candidate_buf: [256]u8 = undefined;
    if (stem.len + 1 > candidate_buf.len) return false;

    @memcpy(candidate_buf[0..stem.len], stem);
    candidate_buf[stem.len] = 'e';
    return isWordInDict(candidate_buf[0 .. stem.len + 1]);
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
            if (!isValidWordForm(segment_buf[0..seg_len])) return false;
            seg_len = 0;
        } else if (snake) {
            // snake_case boundary
            if (seg_len > 0) {
                if (!isValidWordForm(segment_buf[0..seg_len])) return false;
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
        if (!isValidWordForm(segment_buf[0..seg_len])) return false;
    }

    return true;
}
