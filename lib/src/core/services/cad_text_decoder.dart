import 'universal_encoding_service.dart';

/// Shared text decoding for native DWG objects and DXF imports.
class CadTextDecoder {
  static String single(String text) => _cleanCadText(text);
  static String multiline(String text) => _cleanMText(text);
  static String _cleanCadText(String text) {
    var result = UniversalEncodingService.decodeCadString(text);

    // Clean any embedded MTEXT codes/leftovers if present
    if (result.contains('\\') ||
        result.contains(';') ||
        result.contains('ql;') ||
        result.contains('t0;')) {
      result = _stripMTextFormattingCodes(result);
    }

    return result;
  }

  /// Cleans MTEXT formatted string, stripping formatting codes, service tags (-ql;, t0;, etc.), and resolving newlines.
  static String _cleanMText(String text) {
    var result = text;

    // First decode unicode and Cyrillic
    result = _cleanCadText(result);

    // Strip all MTEXT formatting codes and service tags
    result = _stripMTextFormattingCodes(result);

    return result.trim();
  }

  /// Thoroughly strips AutoCAD MTEXT formatting sequences and residual service tokens.
  /// (e.g. \fArial...;, \C7;, \H0.25x;, \pxql,t0;, \pi-0.5,l0.5,t0;, -ql;, t0;, \S1/2;)
  static String _stripMTextFormattingCodes(String text) {
    var result = text;

    // 1. Replace paragraph breaks \P (or \p followed by non-letter), \N, ^J with real newlines FIRST.
    // Notice: \px, \pi, \pt, \ps are paragraph style definitions, not paragraph breaks.
    result = result.replaceAll(RegExp(r'\\P|\\p(?![a-zA-Z])'), '\n');
    result = result.replaceAll(RegExp(r'\\N|\\n(?![a-zA-Z])'), '\n');
    result = result.replaceAll(RegExp(r'\^J', caseSensitive: false), '\n');
    result = result.replaceAll(RegExp(r'\\~'), ' ');

    // 2. Simplify stacked fractions: \S1/2; or \S1^2; or \S1#2; -> 1/2 or 1^2
    result = result.replaceAllMapped(
      RegExp(r'\\[Ss]([^;]+);'),
      (match) => match.group(1)?.replaceAll('^', '') ?? '',
    );

    // 3. Repeatedly strip all standard AutoCAD backslash formatting sequences ending with semicolon:
    // e.g. \f...;, \F...;, \C...;, \c...;, \H...;, \W...;, \Q...;, \T...;, \A...;, \px...;, \pi...;, \pt...;, \ps...;
    // Repeat until fixed point to handle nested formatting blocks
    String prev;
    int iterations = 0;
    do {
      prev = result;
      // Strip backslash formatting codes ending in semicolon
      result = result.replaceAll(
        RegExp(r'\\[a-zA-Z0-9_\-]+[^;]*;', caseSensitive: false),
        '',
      );
      // Strip formatting toggles without semicolon: \L, \l, \O, \o, \K, \k, \X, \x
      result = result.replaceAll(RegExp(r'\\[LlOoKkXx]'), '');
      // Strip residual braces
      result = result.replaceAll('{', '').replaceAll('}', '');
      iterations++;
    } while (result != prev && iterations < 10);

    // 4. Strip leftover paragraph formatting tags from DWG/DXF converters
    // such as: -ql;, ql;, qc;, qr;, qj;, qd;, t0;, ,t0;, \pt0;, i0;, l0;, c0;, b0;, etc.
    // e.g. "-ql;,t0;Text" or ",t0;Text" or "Text -ql;,t0;"
    result = result.replaceAll(
      RegExp(
        r'(?:^|[\s,;\\])-?(?:ql|qc|qr|qj|qd|t\d+(?:\.\d+)?|i-?\d+(?:\.\d+)?|l\d+(?:\.\d+)?|c\d+|x\d+|b\d+|p\d+);',
        caseSensitive: false,
      ),
      '',
    );

    // Clean up any remaining leading/trailing commas or semicolons from stripped tags on individual lines,
    // and strip excessive trailing whitespace (e.g. 48-space padding in CAD blocks)
    result = result
        .split('\n')
        .map(
          (line) => line
              .replaceAll(RegExp(r'^[,\s;]+'), '')
              .replaceAll(RegExp(r'[ \t]{2,}$'), ''),
        )
        .join('\n');

    // Remove remaining escaped backslashes
    result = result.replaceAll(r'\\', r'\');

    return result.trim();
  }
}
