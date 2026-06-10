/// XML code generator — orchestrates view_template.
library odoo_model_generator.codegen.xml_generator;

import '../core/model_builder.dart';
import '../templates/view_template.dart';
import 'formatter.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  XmlGenerator
// ─────────────────────────────────────────────────────────────────────────────

/// Produces the views XML file for one [OdooModel].
class XmlGenerator {
  final OdooModel model;
  final GeneratorConfig config;

  const XmlGenerator(this.model, {this.config = const GeneratorConfig()});

  // ── views/<name>_view.xml ─────────────────────────────────────────────────

  /// Generates the complete views XML string.
  String generateViews() {
    final raw = ViewTemplate.render(model);
    return CodeFormatter.formatXml(raw);
  }

  // ── Partial view snippets (useful for tests / previews) ───────────────────

  /// Returns only the form view `<record>` block.
  String formViewSnippet() {
    final full = generateViews();
    return _extractBlock(full, '<!-- ═══ Form View', '<!-- ═══ Tree View');
  }

  /// Returns only the tree view `<record>` block.
  String treeViewSnippet() {
    final full = generateViews();
    return _extractBlock(full, '<!-- ═══ Tree View', '<!-- ═══ Search View');
  }

  /// Returns only the search view `<record>` block.
  String searchViewSnippet() {
    final full = generateViews();
    return _extractBlock(
        full, '<!-- ═══ Search View', '<!-- ═══ Window Action');
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  String _extractBlock(String source, String startMarker, String endMarker) {
    final start = source.indexOf(startMarker);
    final end = source.indexOf(endMarker);
    if (start == -1 || end == -1) return source;
    return source.substring(start, end).trim();
  }
}
