/// String manipulation utilities.
library odoo_model_generator.string_utils;

/// Collection of pure-function string helpers used across the package.
abstract final class StringUtils {
  StringUtils._();

  /// Escapes single quotes inside a Python string literal.
  static String escapeSingle(String s) => s.replaceAll("'", "\\'");

  /// Escapes double quotes inside an XML attribute.
  static String escapeXml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  /// Repeats [s] by [n] (indentation helper).
  static String indent(String s, int spaces) {
    final pad = ' ' * spaces;
    return s
        .split('\n')
        .map((line) => line.isEmpty ? line : '$pad$line')
        .join('\n');
  }

  /// Trims trailing whitespace from every line.
  static String trimLines(String s) =>
      s.split('\n').map((l) => l.trimRight()).join('\n');

  /// Returns `true` when [s] is a valid Python / Odoo identifier.
  static bool isValidIdentifier(String s) =>
      RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(s);

  /// Pads [s] on the right so all lines in a column are aligned.
  static String padRight(String s, int width) =>
      s.length >= width ? s : s + (' ' * (width - s.length));

  /// Wraps [text] at [maxWidth], preserving existing newlines.
  static String wordWrap(String text, {int maxWidth = 88}) {
    final words = text.split(' ');
    final lines = <String>[];
    var current = '';
    for (final word in words) {
      if (current.isEmpty) {
        current = word;
      } else if (current.length + 1 + word.length <= maxWidth) {
        current += ' $word';
      } else {
        lines.add(current);
        current = word;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines.join('\n');
  }
}
