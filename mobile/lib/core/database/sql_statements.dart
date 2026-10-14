/// Splits a SQL script into single statements, because sqflite on Android
/// only runs the first statement passed to `execute`.
///
/// Handles `--` line comments, `/* */` block comments and quoted strings or
/// identifiers ('...', "...", `...`, [...]) so semicolons inside them do not
/// split. `CREATE TRIGGER ... BEGIN ... END;` bodies are kept whole.
List<String> splitSqlStatements(String script) {
  final statements = <String>[];
  final current = StringBuffer();
  var i = 0;
  var inTrigger = false;

  void flush() {
    final stmt = current.toString().trim();
    if (stmt.isNotEmpty) statements.add(stmt);
    current.clear();
    inTrigger = false;
  }

  while (i < script.length) {
    final c = script[i];
    final next = i + 1 < script.length ? script[i + 1] : '';

    if (c == '-' && next == '-') {
      final end = script.indexOf('\n', i);
      i = end == -1 ? script.length : end + 1;
      current.write('\n');
      continue;
    }
    if (c == '/' && next == '*') {
      final end = script.indexOf('*/', i + 2);
      i = end == -1 ? script.length : end + 2;
      current.write(' ');
      continue;
    }
    if (c == "'" || c == '"' || c == '`' || c == '[') {
      final close = c == '[' ? ']' : c;
      var j = i + 1;
      while (j < script.length) {
        if (script[j] == close) {
          // A doubled quote is an escaped quote inside the literal.
          if (close != ']' && j + 1 < script.length && script[j + 1] == close) {
            j += 2;
            continue;
          }
          break;
        }
        j++;
      }
      current.write(script.substring(i, j < script.length ? j + 1 : script.length));
      i = j + 1;
      continue;
    }
    if (c == ';') {
      if (inTrigger && !_endsWithEnd(current.toString())) {
        current.write(c);
        i++;
        continue;
      }
      flush();
      i++;
      continue;
    }
    current.write(c);
    if (!inTrigger && RegExp(r'^\s*CREATE\s+(TEMP\s+|TEMPORARY\s+)?TRIGGER\b', caseSensitive: false)
        .hasMatch(current.toString())) {
      inTrigger = true;
    }
    i++;
  }
  flush();
  return statements;
}

bool _endsWithEnd(String sql) => RegExp(r'\bEND\s*$', caseSensitive: false).hasMatch(sql);
