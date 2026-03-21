/// Utility for handling shell-related operations
class ShellUtils {
  /// Splits a command string into a list of arguments, respecting double and single quotes.
  /// Example: 'fastp -i "input file.fastq" -o out.fq' -> ["fastp", "-i", "input file.fastq", "-o", "out.fq"]
  static List<String> splitArguments(String command) {
    final List<String> args = [];
    final StringBuffer current = StringBuffer();
    bool inDoubleQuotes = false;
    bool inSingleQuotes = false;
    bool escaped = false;

    for (int i = 0; i < command.length; i++) {
      final char = command[i];

      if (escaped) {
        current.write(char);
        escaped = false;
        continue;
      }

      if (char == '\\') {
        escaped = true;
        continue;
      }

      if (char == '"' && !inSingleQuotes) {
        inDoubleQuotes = !inDoubleQuotes;
        continue;
      }

      if (char == "'" && !inDoubleQuotes) {
        inSingleQuotes = !inSingleQuotes;
        continue;
      }

      if (char == ' ' && !inDoubleQuotes && !inSingleQuotes) {
        if (current.isNotEmpty) {
          args.add(current.toString());
          current.clear();
        }
        continue;
      }

      current.write(char);
    }

    if (current.isNotEmpty) {
      args.add(current.toString());
    }

    return args;
  }
}
