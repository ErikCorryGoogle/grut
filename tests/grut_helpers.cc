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
