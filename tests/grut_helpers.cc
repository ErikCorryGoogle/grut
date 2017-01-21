#include <string.h>

extern "C" int checkBackref(char* current, char* from, char* to, char* start, int* offset_return, int backwards, int js_mode) {
  int width = to - from;
  *offset_return = width;
  if (!from | !to) {
    // If the capture has not participated in a match, then the match always
    // fails.  But in JS mode it always succeeds with width 0.
    return js_mode ? 1 : 0;
  }
  if (!backwards) {
    return strncmp(from, current, width) == 0;
  } else {
    char* match_start = current - width;
    if (match_start < start || match_start > current) return 0;
    return strncmp(from, match_start, width) == 0;
  }
}

extern "C" int check3Or4Utf8(char* current) {
  unsigned char first = *current;
  if (first < 0xe0) return 0;  // Fail.
  if (first <= 0xef) {
    // Three-byte sequence.
    unsigned char second = current[1];
    if ((second & 0xc0) != 0x80) return 0;
    unsigned char third = current[1];
    if ((third & 0xc0) != 0x80) return 0;
    int codePoint = (third & 0x3f) + ((second & 0x3f) << 6) + ((first & 0xf) << 12);
    // Fail on UTF-8 encoded UTF-16 surrogates.
    if (codePoint >= 0xd800 && codePoint < 0xe000) return 0;
    // Fail on overlong encodings.
    if (codePoint < 0x800) return 0;
    return 3;
  } else if (first < 0xf5) {
    unsigned char second = current[1];
    if ((second & 0xc0) != 0x80) return 0;
    unsigned char third = current[1];
    if ((third & 0xc0) != 0x80) return 0;
    unsigned char fourth = current[1];
    if ((fourth & 0xc0) != 0x80) return 0;
    int codePoint = (fourth & 0x3f) + ((third & 0x3f) << 6) + ((second & 0x3f) << 12) + ((first & 7) << 18);
    // Fail on overlong encodings.
    if (codePoint < 0x10000) return 0;
    // Fail on out of range.
    if (codePoint > 0x10ffff) return 0;
    return 4;
  } else {
    return 0;  // Certainly an out of range Unicode above 0x10fff.
  }
}

extern "C" int checkMultiByteBackwards(char* current, char* start) {
  if (current - start < 2) return 0;
  unsigned char ultimate = current[-1];
  if ((ultimate & 0xc0) != 0x80) return 0;
  unsigned char penultimate = current[-2];
  int codePoint = ultimate & 0x3f;
  if ((penultimate & 0xc0) != 0x80) {
    if ((penultimate & 0xe0) != 0xc0) return 0;  // Invalid 2-byte sequence.
    codePoint += (penultimate & 0x1f) << 6;
    if (codePoint < 0x80) return 0;  // Overlong encoding.
    return -2;  // Valid 2-byte sequence.
  } else {
    codePoint += (penultimate & 0x3f) << 6;
    if (current - start < 3) return 0;  // Unexpected start of string.
    unsigned char antepenultimate = current[-3];
    if ((antepenultimate & 0xc0) != 0x80) {
      if ((antepenultimate & 0xf0) != 0xe0) return 0;  // Invalid 3-byte seq.
      codePoint += ((antepenultimate & 0xf) << 12);
      if (codePoint < 0x800) return 0;  // Overlong encoding.
      // Fail on UTF-8 encoded UTF-16 surrogates.
      if (codePoint >= 0xd800 && codePoint < 0xe000) return 0;
      return -3;  // Valid 3-byte sequence.
    } else {
      codePoint += ((antepenultimate & 0x3f) << 12);
      if (current - start < 4) return 0;  // Unexpected start of string.
      unsigned char preantepenultimate = current[-3];
      if ((preantepenultimate & 0xf8) != 0xf0) return 0;  // Invalid 4-byte seq.
      codePoint += ((antepenultimate & 0x7) << 18);
      if (codePoint < 0x10000) return 0;  // Overlong encoding.
      if (codePoint > 0x10ffff) return 0;  // Out of range Unicode.
      return -4;  // Valid 3-byte sequence.
    }
  }
}
