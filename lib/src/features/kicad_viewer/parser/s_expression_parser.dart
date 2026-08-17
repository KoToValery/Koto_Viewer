/// Represents an S-Expression (Lisp AST node) in KiCad file formats.
class SExpNode {
  final String name;
  final List<String> values;
  final List<SExpNode> children;

  const SExpNode({
    required this.name,
    this.values = const [],
    this.children = const [],
  });

  /// Finds the first child node with the matching [name].
  SExpNode? findChild(String name) {
    for (final child in children) {
      if (child.name == name) return child;
    }
    return null;
  }

  /// Finds all child nodes with the matching [name].
  List<SExpNode> findAllChildren(String name) {
    return children.where((c) => c.name == name).toList();
  }

  /// Gets string value at [index].
  String? getValue(int index) {
    if (index >= 0 && index < values.length) {
      return values[index];
    }
    return null;
  }

  /// Gets double value at [index].
  double? getDouble(int index) {
    final str = getValue(index);
    if (str == null) return null;
    return double.tryParse(str);
  }
}

/// Pure-Dart S-Expression (Lisp) Tokenizer & Parser for KiCad (.kicad_pcb, .kicad_sch).
class SExpressionParser {
  /// Parses S-Expression text into a root [SExpNode].
  static SExpNode parse(String input) {
    final tokens = _tokenize(input);
    if (tokens.isEmpty) {
      return const SExpNode(name: 'empty');
    }

    int index = 0;

    SExpNode parseNode() {
      if (index >= tokens.length) return const SExpNode(name: '');

      if (tokens[index] == '(') {
        index++; // Consume '('
        if (index >= tokens.length) return const SExpNode(name: '');

        final nodeName = tokens[index++];
        final List<String> values = [];
        final List<SExpNode> children = [];

        while (index < tokens.length && tokens[index] != ')') {
          if (tokens[index] == '(') {
            children.add(parseNode());
          } else {
            values.add(tokens[index++]);
          }
        }

        if (index < tokens.length && tokens[index] == ')') {
          index++; // Consume ')'
        }

        return SExpNode(name: nodeName, values: values, children: children);
      } else {
        return SExpNode(name: tokens[index++]);
      }
    }

    return parseNode();
  }

  static List<String> _tokenize(String input) {
    final List<String> tokens = [];
    final length = input.length;
    int i = 0;

    while (i < length) {
      final char = input[i];

      // Skip whitespace
      if (char == ' ' || char == '\t' || char == '\r' || char == '\n') {
        i++;
        continue;
      }

      // Parentheses
      if (char == '(' || char == ')') {
        tokens.add(char);
        i++;
        continue;
      }

      // Double-quoted string
      if (char == '"') {
        i++;
        final sb = StringBuffer();
        while (i < length && input[i] != '"') {
          if (input[i] == '\\' && i + 1 < length) {
            i++;
            sb.write(input[i]);
          } else {
            sb.write(input[i]);
          }
          i++;
        }
        if (i < length && input[i] == '"') {
          i++; // Consume closing quote
        }
        tokens.add(sb.toString());
        continue;
      }

      // Unquoted symbol / literal
      final sb = StringBuffer();
      while (i < length &&
          input[i] != ' ' &&
          input[i] != '\t' &&
          input[i] != '\r' &&
          input[i] != '\n' &&
          input[i] != '(' &&
          input[i] != ')') {
        sb.write(input[i]);
        i++;
      }
      tokens.add(sb.toString());
    }

    return tokens;
  }
}
