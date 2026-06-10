/// Per-field template helpers (used for code-review and standalone renders).
library odoo_model_generator.templates.field_templates;

import '../core/field_types.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  FieldTemplates
// ─────────────────────────────────────────────────────────────────────────────

/// Provides rendering helpers for individual field types used in contexts
/// outside the main code generators (e.g. interactive previews, docs).
abstract final class FieldTemplates {
  FieldTemplates._();

  /// Renders a summary row for a field (used in READMEs / reports).
  static String summaryRow(OdooField field) {
    final type = field.runtimeType.toString();
    final required = field.required ? '✓' : '';
    final label = field.label;
    return '| `${field.name}` | $type | $label | $required |';
  }

  /// Renders a Markdown table for all fields.
  static String markdownTable(List<OdooField> fields) {
    final header =
        '| Field | Type | Label | Required |\n'
        '|-------|------|-------|----------|\n';
    final rows = fields.map(summaryRow).join('\n');
    return '$header$rows';
  }

  /// Produces a concise one-liner Python declaration preview.
  static String pythonPreview(OdooField field) {
    return '    ${field.name} = ${field.toPython()}';
  }

  /// Produces a form-view XML snippet preview.
  static String xmlPreview(OdooField field) => '    ${field.toFormXML()}';

  // ── Type-to-Python mapping (used for validation / docs) ───────────────────

  static String odooFieldType(OdooField field) => switch (field) {
        NameField() => 'fields.Char',
        Char() => 'fields.Char',
        Text() => 'fields.Text',
        Html() => 'fields.Html',
        Integer() => 'fields.Integer',
        Float() => 'fields.Float',
        Monetary() => 'fields.Monetary',
        Boolean() => 'fields.Boolean',
        Date() => 'fields.Date',
        Datetime() => 'fields.Datetime',
        Binary() => 'fields.Binary',
        Image() => 'fields.Image',
        Selection() => 'fields.Selection',
        Many2one() => 'fields.Many2one',
        One2many() => 'fields.One2many',
        Many2many() => 'fields.Many2many',
        ComputedField() => 'fields.${field.fieldType}',
        Reference() => 'fields.Reference',
        // OdooField is an abstract (non-sealed) class; wildcard covers any
        // future subclass added outside this package.
        _ => 'fields.${field.runtimeType}',
      };
}
