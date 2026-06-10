/// Input validation rules for Odoo model and field definitions.
library odoo_model_generator.validators;

import 'exceptions.dart';
import '../core/field_types.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Regex constants
// ─────────────────────────────────────────────────────────────────────────────

/// Valid characters for custom model names.
const _kModelNamePattern = r'^x_[a-z][a-z0-9_]{0,61}$';

/// Valid characters for field names.
const _kFieldNamePattern = r'^[a-z][a-z0-9_]{0,63}$';

/// Valid Python module / Odoo module identifier.
const _kModuleNamePattern = r'^[a-z][a-z0-9_]*$';

// ─────────────────────────────────────────────────────────────────────────────
//  Public validator
// ─────────────────────────────────────────────────────────────────────────────

/// Stateless validator for all model definitions.
///
/// Every public method either returns silently (valid) or throws a
/// [GeneratorException] subtype (invalid).
abstract final class Validators {
  Validators._();

  // ── Model-level ───────────────────────────────────────────────────────────

  /// Validates the Odoo `_name` value.
  ///
  /// Rules:
  /// * Must start with `x_` (custom models prefix).
  /// * Lowercase alphanumerics and underscores only.
  /// * Maximum length: 64 characters.
  static void modelName(String name) {
    if (name.isEmpty) {
      throw const ValidationException(
        'Model name cannot be empty.',
        hint: 'Provide a name like "x_my_model".',
      );
    }

    if (!RegExp(_kModelNamePattern).hasMatch(name)) {
      throw ValidationException(
        'Invalid model name: "$name".',
        hint: 'Must start with "x_", use only lowercase letters, digits, '
            'underscores, and be ≤ 64 characters.',
      );
    }
  }

  /// Validates a module / dependency name.
  static void moduleName(String name) {
    if (!RegExp(_kModuleNamePattern).hasMatch(name)) {
      throw ValidationException(
        'Invalid module name: "$name".',
        hint: 'Use only lowercase letters, digits, and underscores.',
      );
    }
  }

  /// Validates that [recName] is present in [fieldNames].
  static void recNameExists(String recName, Iterable<String> fieldNames) {
    if (!fieldNames.contains(recName)) {
      throw ValidationException(
        '_rec_name "$recName" does not match any declared field.',
        hint: 'Add a field named "$recName" or change stringField.',
      );
    }
  }

  // ── Field-level ───────────────────────────────────────────────────────────

  /// Validates a single field name.
  static void fieldName(String name) {
    if (name.isEmpty) {
      throw const ValidationException('Field name cannot be empty.');
    }

    if (kReservedOdooFieldNames.contains(name)) {
      throw ReservedFieldException(name);
    }

    if (!RegExp(_kFieldNamePattern).hasMatch(name)) {
      throw ValidationException(
        'Invalid field name: "$name".',
        hint: 'Use only lowercase letters, digits, and underscores '
            '(max 64 chars, must start with a letter).',
      );
    }
  }

  /// Validates a complete ordered list of fields for duplicates and reserved
  /// names.
  static void fieldList(List<OdooField> fields) {
    final seen = <String>{};
    for (final f in fields) {
      fieldName(f.name); // individual validation
      if (!seen.add(f.name)) {
        throw DuplicateFieldException(f.name);
      }
    }
  }

  // ── Relational ────────────────────────────────────────────────────────────

  /// Validates a relation target (e.g. `'res.partner'`).
  static void relationTarget(String relation) {
    if (!RegExp(r'^[a-z][a-z0-9_.]*[a-z0-9]$').hasMatch(relation)) {
      throw ValidationException(
        'Invalid relation target: "$relation".',
        hint: 'Use the Odoo model technical name, e.g. "res.partner".',
      );
    }
  }

  // ── Selection ─────────────────────────────────────────────────────────────

  /// Validates that [options] is non-empty.
  static void selectionOptions(List<String> options) {
    if (options.isEmpty) {
      throw const ValidationException(
        'Selection field must have at least one option.',
      );
    }
  }

  // ── Full model ────────────────────────────────────────────────────────────

  /// Runs all model-level validations in one call.
  ///
  /// Called by [OdooGenerator.validate] before any file is written.
  static void fullModel({
    required String name,
    required String stringField,
    required List<OdooField> fields,
    required List<String> dependencies,
  }) {
    modelName(name);
    for (final dep in dependencies) {
      moduleName(dep);
    }
    fieldList(fields);
    recNameExists(stringField, fields.map((f) => f.name));
  }
}
