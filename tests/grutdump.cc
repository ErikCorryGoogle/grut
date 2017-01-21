#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>

struct GrutState {
  char* start_of_string;
  // TODO: We need to handle the correct sizing of this.
  char* captures_and_registers[64];
};

extern "C" int grut(GrutState* state, const char* s);

static const intptr_t kBufSize = 4 << 20;
static const intptr_t kMargin = 64 << 10;  // 64k.

static char tmp[kBufSize];

static void dump(GrutState* state, int capturePairs) {
  int len = state->captures_and_registers[1] - state->captures_and_registers[0];
  memcpy(tmp, state->captures_and_registers[0], len);
  tmp[len] = '\0';
  printf("«%s»\n", tmp);
  for (int i = 2; i < capturePairs; i += 2) {
    if (state->captures_and_registers[i] == nullptr) {
      printf("%d: «null»\n", i >> 1);
    } else {
      char* start = state->captures_and_registers[i];
      char* end = state->captures_and_registers[i + 1];
      memcpy(tmp, start, end - start);
      tmp[end - start] = '\0';
      printf("%d: «%s»\n", i >> 1, tmp);
    }
  }
}

int main(int argc, const char* const* argv) {
  void* arena = mmap(nullptr, kBufSize, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
  if (arena == MAP_FAILED) {
    perror("mmap");
    exit(8);
  }
  char* start = reinterpret_cast<char*>(arena) + kMargin;
  char* end = reinterpret_cast<char*>(arena) + kBufSize - kMargin;
  if (mprotect(arena, kMargin, PROT_NONE)) {
    perror("mprotect1");
    exit(8);
  }
  if (mprotect(end, kMargin, PROT_NONE)) {
    perror("mprotect2");
    exit(8);
  }

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
  static char buffer[kBufSize];
  size_t bytes = fread(buffer, 1, kBufSize, fp);
  if (bytes == kBufSize) {
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
    bytes--;
  }
  int capturePairs = grut(nullptr, nullptr);
  if (multiline) {
    while (true) {
      bool done = false;
      char* newline = const_cast<char*>(strchr(input, '\n'));
      if (newline == nullptr) {
	done = true;
	newline = const_cast<char*>(input + strlen(input));
      } else {
	if (*newline != '\0') *newline = '\0';
      }
      int len = newline + 1 - input;
      memcpy(start, input, len);
      memcpy(end - len, input, len);
      if (mprotect(start, kBufSize - 2 * kMargin, PROT_READ)) {
	perror("mprotect3");
	exit(42);
      }
      if (grut(&state, start)) {
	dump(&state, capturePairs);
      } else {
	printf("\n");
      }
      grut(&state, end - len);  // Check if we hit the guard.
      if (mprotect(start, kBufSize - 2 * kMargin, PROT_READ | PROT_WRITE)) {
	perror("mprotect4");
	exit(103);
      }
      if (done) break;
      input = newline + 1;
    }
  } else {
    memcpy(start, input, bytes + 1);
    memcpy(end - bytes - 1, input, bytes + 1);
    if (mprotect(start, kBufSize - 2 * kMargin, PROT_READ)) {
      perror("mprotect3");
      exit(42);
    }
    if (grut(&state, start)) {
      dump(&state, capturePairs);
    }
    grut(&state, end - bytes - 1);  // Check if we hit the guard.
    if (mprotect(start, kBufSize - 2 * kMargin, PROT_READ | PROT_WRITE)) {
      perror("mprotect4");
      exit(103);
    }
  }
  return 0;
}
