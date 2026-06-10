/// Python code generator — orchestrates model_template + manifest_template.
library odoo_model_generator.codegen.python_generator;

import '../core/model_builder.dart';
import '../templates/model_template.dart';
import '../templates/manifest_template.dart';
import 'formatter.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PythonGenerator
// ─────────────────────────────────────────────────────────────────────────────

/// Produces all Python text (models.py + __manifest__.py) for one [OdooModel].
///
/// Design: delegates to [ModelTemplate] and [ManifestTemplate] for content,
/// then applies [CodeFormatter] to normalise indentation and line endings.
class PythonGenerator {
  final OdooModel model;
  final GeneratorConfig config;

  const PythonGenerator(this.model, {this.config = const GeneratorConfig()});

  // ── models/<name>.py ──────────────────────────────────────────────────────

  /// Generates the complete Python model source.
  String generate() {
    final raw = ModelTemplate.render(model);
    return CodeFormatter.formatPython(raw);
  }

  // ── __manifest__.py ───────────────────────────────────────────────────────

  /// Generates the Odoo manifest dictionary.
  String generateManifest() {
    final raw = ManifestTemplate.render(model, config);
    return CodeFormatter.formatPython(raw);
  }

  // ── Quick single-field preview ────────────────────────────────────────────

  /// Returns the Python declaration for a named field (useful for tests).
  String fieldDeclaration(String fieldName) {
    final f = model.fields.firstWhere((f) => f.name == fieldName);
    return '    $fieldName = ${f.toPython()}';
  }
}
