/// Code formatter — normalises generated Python and XML output.
library odoo_model_generator.codegen.formatter;

import '../utils/string_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CodeFormatter
// ─────────────────────────────────────────────────────────────────────────────

/// Applies light post-processing to generated code to keep it clean.
///
/// This is intentionally lightweight — it does NOT parse the AST.
/// Heavy formatting (e.g., black-equivalent) is left to the developer's
/// toolchain.
abstract final class CodeFormatter {
  CodeFormatter._();

  // ── Python ────────────────────────────────────────────────────────────────

  /// Normalises generated Python source:
  /// * Unix line endings (`\n`).
  /// * Trailing whitespace stripped from each line.
  /// * Collapses >2 consecutive blank lines into exactly 2.
  /// * Ensures the file ends with a single newline.
  static String formatPython(String source) {
    // Normalise line endings
    var s = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Strip trailing spaces per line
    s = StringUtils.trimLines(s);

    // Collapse >2 blank lines
    s = _collapseBlankLines(s, maxConsecutive: 2);

    // Ensure single trailing newline
    s = s.trimRight() + '\n';

    return s;
  }

  // ── XML ───────────────────────────────────────────────────────────────────

  /// Normalises generated XML source:
  /// * Unix line endings.
  /// * Trailing whitespace stripped per line.
  /// * Collapses >1 consecutive blank lines.
  /// * Ensures single trailing newline.
  static String formatXml(String source) {
    var s = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    s = StringUtils.trimLines(s);
    s = _collapseBlankLines(s, maxConsecutive: 1);
    s = s.trimRight() + '\n';
    return s;
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  static String _collapseBlankLines(String s, {required int maxConsecutive}) {
    final lines = s.split('\n');
    final result = <String>[];
    var blankCount = 0;

    for (final line in lines) {
      if (line.isEmpty) {
        blankCount++;
        if (blankCount <= maxConsecutive) result.add('');
      } else {
        blankCount = 0;
        result.add(line);
      }
    }

    return result.join('\n');
  }
}
