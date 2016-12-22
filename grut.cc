#include <fstream>
#include <iostream>
#include <sstream>
#include <string>

struct GrutState {
  char* start_of_string;
  // TODO: We need to handle the correct sizing of this.
  int captures_and_registers[32];
};

extern "C" int grut(GrutState* state, const char* s);

extern "C" int match(GrutState* state, const char* s) {
  return 1;
}

int main(int argc, const char* const* argv) {
  GrutState state;
  while (--argc) {
    const char* fn = *++argv;
    std::ifstream input(fn);
    std::string line;
    while (std::getline(input, line)) {
      if (grut(&state, line.c_str())) {
	std::cout << line << "\n";
      }
    }
  }
  return 0;
}
