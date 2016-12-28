#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct GrutState {
  char* start_of_string;
  // TODO: We need to handle the correct sizing of this.
  int captures_and_registers[32];
};

extern "C" int grut(GrutState* state, const char* s);

int main(int argc, const char* const* argv) {
  bool multiline = false;
  if (argc >= 1 && !strcmp(argv[1], "-m")) {
    multiline = true;
    argc--;
    argv++;
  }
  if (argc != 2) {
    fprintf(stderr, "Usage: grutdump <inputfile> > outputfile\n");
    exit(5);
  }
  GrutState state;
  const char* fn = argv[1];
  FILE* fp = fopen(fn, "r");
  if (fp == NULL) {
    perror(fn);
    exit(1);
  }
#define BUF_SIZ (4 << 20)
  static char buffer[BUF_SIZ];
  size_t bytes = fread(buffer, 1, BUF_SIZ, fp);
  if (bytes == BUF_SIZ) {
    fprintf(stderr, "Input too large: %s\n", fn);
    exit(2);
  }
  const char* input = buffer;
  if (bytes == 0) {
    if(!feof(fp)) {
      perror(fn);
      exit(3);
    }
    input = "";
  } else {
    // Remove one trailing newline from the input because many editors like
    // to add a newline to the last line,
    if (buffer[bytes - 1] == '\n') buffer[bytes - 1] = '\0';
  }
  if (multiline) {
    while (true) {
      char* newline = strchr(input, '\n');
      if (newline != 0) *newline = '\0';
      if (grut(&state, input)) {
	// Successful regexp match.  We don't record captures yet, so assume the
	// whole string matched and that there are no captures.
	printf("«%s»\n", input);
      } else {
	printf("\n");
      }
      if (newline == 0) break;
      input = newline + 1;
    }
  } else {
    if (grut(&state, input)) {
      // Successful regexp match.  We don't record captures yet, so assume the
      // whole string matched and that there are no captures.
      printf("«%s»\n", input);
    }
  }
  return 0;
}
