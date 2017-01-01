import "dart:io";

int main(List<String> args) {
  bool multiline = false;
  int arg = 0;
  if (args[arg] == '-m') {
    multiline = true;
    arg++;
  }
  String source = new File(args[arg]).readAsStringSync();
  String input = new File(args[arg + 1]).readAsStringSync();
  File dest = new File(args[arg + 2]);
  if (source.endsWith("\n")) source = source.substring(0, source.length - 1);
  if (input.endsWith("\n")) input = input.substring(0, input.length - 1);
  List<String> lines = <String>[input];
  List<String> output = <String>[];
  if (multiline) lines = input.split("\n").toList();
  RegExp re = new RegExp(source);
  for (String line in lines) {
    Match m = re.firstMatch(line);
    if (m == null) {
      output.add("");
    } else {
      output.add("«${m[0]}»");
      for (int i = 1; i < m.groupCount + 1; i++)
	output.add("$i: «${m[i]}»");
    }
  }
  String out = output.join("\n");
  if (multiline || (output.length > 0 && output[0] != "")) out += "\n";
  dest.writeAsStringSync(out);
  return 0;
}
