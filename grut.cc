#include <fstream>
#include <iostream>
#include <sstream>
#include <string>

extern "C" int grut(const char* s);

extern "C" int match(const char* s) {
  return 1;
}

int main(int argc, const char* const* argv) {
  while (--argc) {
    const char* fn = *++argv;
    std::ifstream input(fn);
    std::string line;
    while (std::getline(input, line)) {
      if (grut(line.c_str())) {
	std::cout << line << "\n";
      }
    }
  }
  return 0;
}
