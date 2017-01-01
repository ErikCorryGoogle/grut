#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct GrutState {
  char* start_of_string;
  // TODO: We need to handle the correct sizing of this.
  char* captures_and_registers[32];
};

extern "C" int grut(GrutState* state, const char* s);

static void dump(GrutState* state, int capturePairs) {
  *state->captures_and_registers[1] = '\0';
  printf("«%s»\n", state->captures_and_registers[0]);
  for (int i = 2; i < capturePairs; i += 2) {
    if (state->captures_and_registers[i] == nullptr) {
      printf("%d: «null»\n", i >> 1);
    } else {
      char* end = state->captures_and_registers[i + 1];
      char saved = *end;
      *end = '\0';
      printf("%d: «%s»\n", i >> 1, state->captures_and_registers[i]);
      *end = saved;
    }
  }
}

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
  int capturePairs = grut(nullptr, nullptr);
  if (multiline) {
    while (true) {
      char* newline = const_cast<char*>(strchr(input, '\n'));
      if (newline != nullptr) *newline = '\0';
      if (grut(&state, input)) {
	dump(&state, capturePairs);
      } else {
	printf("\n");
      }
      if (newline == nullptr) break;
      input = newline + 1;
    }
  } else {
    if (grut(&state, input)) {
      dump(&state, capturePairs);
    }
  }
  return 0;
}
