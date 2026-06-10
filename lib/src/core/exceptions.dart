/// Custom exceptions for odoo_model_generator.
library odoo_model_generator.exceptions;

// ─────────────────────────────────────────────────────────────────────────────
//  Base exception
// ─────────────────────────────────────────────────────────────────────────────

/// Root exception type for all errors thrown by this package.
sealed class GeneratorException implements Exception {
  const GeneratorException(this.message, {this.hint});

  final String message;

  /// Optional actionable hint shown to the developer.
  final String? hint;

  @override
  String toString() {
    final hintPart = hint != null ? '\n  Hint: $hint' : '';
    return '[${runtimeType}] $message$hintPart';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Concrete exceptions
// ─────────────────────────────────────────────────────────────────────────────

/// Thrown when a model or field definition violates a business rule.
final class ValidationException extends GeneratorException {
  const ValidationException(super.message, {super.hint});
}

/// Thrown when a field name collides with a reserved Odoo field.
final class ReservedFieldException extends GeneratorException {
  const ReservedFieldException(String fieldName)
      : super(
          'Field "$fieldName" is a reserved Odoo field name.',
          hint:
              'Remove it — Odoo already defines this field automatically.',
        );
}

/// Thrown when two fields share the same name within a model.
final class DuplicateFieldException extends GeneratorException {
  const DuplicateFieldException(String fieldName)
      : super(
          'A field named "$fieldName" has already been added to this model.',
          hint: 'Each field name must be unique within a model.',
        );
}

/// Thrown when any file-system operation fails during output.
final class GenerationException extends GeneratorException {
  const GenerationException(super.message, {super.hint});
}

/// Thrown when the resolved output path is not writable.
final class OutputPathException extends GeneratorException {
  const OutputPathException(String path)
      : super(
          'Cannot write to output path "$path".',
          hint: 'Check directory permissions or provide a different path.',
        );
}
