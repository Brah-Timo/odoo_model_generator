/// Odoo field type definitions.
///
/// Every concrete field class implements [OdooField] and is responsible
/// for rendering its own Python declaration and its XML view element.
library odoo_model_generator.field_types;

import 'package:meta/meta.dart';

import '../utils/naming_conventions.dart';
import '../utils/string_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Reserved Odoo field names that must NOT be re-declared by the user.
// ─────────────────────────────────────────────────────────────────────────────
const Set<String> kReservedOdooFieldNames = {
  'id',
  'create_date',
  'write_date',
  'create_uid',
  'write_uid',
  'display_name',
  '__last_update',
};

// ─────────────────────────────────────────────────────────────────────────────
//  Abstract base class
// ─────────────────────────────────────────────────────────────────────────────

/// Abstract base for every Odoo field type.
///
/// Subclasses must implement [toPython] (Python field declaration) and
/// [toXML] (view `<field>` element).
abstract class OdooField {
  /// Technical field name (snake_case, lowercase).
  final String name;

  /// Human-readable label shown in the Odoo UI.
  final String? string;

  /// Whether `required=True` should be added to the Python declaration.
  final bool required;

  /// Default value emitted as `default=…` in Python.
  final dynamic defaultValue;

  /// Tooltip text shown when the user hovers over the field.
  final String? help;

  /// Whether the field should appear in the tree (list) view.
  final bool inTree;

  /// Whether the field should appear in the search view.
  final bool inSearch;

  /// Whether the field is read-only in views.
  final bool readonly;

  /// CSS classes applied in the form view `<field>` element.
  final String? cssClass;

  /// Extra arbitrary keyword arguments appended verbatim to the Python call.
  final Map<String, String> extra;

  const OdooField(
    this.name, {
    this.string,
    this.required = false,
    this.defaultValue,
    this.help,
    this.inTree = false,
    this.inSearch = false,
    this.readonly = false,
    this.cssClass,
    this.extra = const {},
  });

  // ── abstract surface ──────────────────────────────────────────────────────

  /// Returns the Python right-hand side declaration, e.g.
  /// `fields.Char('name', string='Name', required=True)`.
  String toPython();

  /// Returns the `<field …/>` XML element used in the form view.
  String toFormXML();

  /// Returns the `<field …/>` XML element used in the tree view.
  String toTreeXML() => '<field name="$name"/>';

  /// Returns the `<field …/>` XML element used in the search view.
  String toSearchXML() => '<field name="$name"/>';

  // ── helpers ───────────────────────────────────────────────────────────────

  /// Resolved display label: explicit [string] or auto-formatted [name].
  String get label => string ?? NamingConventions.toLabel(name);

  /// Builds a Python `fields.XType(…)` call from parts.
  @protected
  String buildPythonCall(
    String fieldType,
    List<String> positional, {
    Map<String, String> kwargs = const {},
  }) {
    final buf = StringBuffer('fields.$fieldType(');

    // positional args
    for (final p in positional) {
      buf.write("$p, ");
    }

    // standard kwargs
    buf.write("string='$label', ");
    if (required) buf.write('required=True, ');
    if (readonly) buf.write('readonly=True, ');
    if (help != null) buf.write("help='${StringUtils.escapeSingle(help!)}', ");

    // default value
    if (defaultValue != null) {
      buf.write('default=${_pythonLiteral(defaultValue)}, ');
    }

    // extra kwargs (field-specific)
    for (final entry in kwargs.entries) {
      buf.write('${entry.key}=${entry.value}, ');
    }

    // user-supplied extra kwargs
    for (final entry in extra.entries) {
      buf.write('${entry.key}=${entry.value}, ');
    }

    // strip trailing comma+space
    var result = buf.toString();
    if (result.endsWith(', ')) {
      result = result.substring(0, result.length - 2);
    }
    return '$result)';
  }

  /// Converts a Dart value to a Python literal.
  String _pythonLiteral(dynamic value) {
    if (value is String) return "'${StringUtils.escapeSingle(value)}'";
    if (value is bool) return value ? 'True' : 'False';
    if (value is num) return value.toString();
    if (value is List) {
      final items = value.map(_pythonLiteral).join(', ');
      return '[$items]';
    }
    return "'$value'";
  }

  /// Builds a `<field name="…" …/>` XML attribute string.
  @protected
  String buildFormXMLElement({
    Map<String, String> attrs = const {},
    String? widget,
    bool nolabel = false,
  }) {
    final buf = StringBuffer('<field name="$name"');
    if (widget != null) buf.write(' widget="$widget"');
    if (nolabel) buf.write(' nolabel="1"');
    if (readonly) buf.write(' readonly="1"');
    if (cssClass != null) buf.write(' class="$cssClass"');
    for (final e in attrs.entries) {
      buf.write(' ${e.key}="${e.value}"');
    }
    buf.write('/>');
    return buf.toString();
  }

  @override
  String toString() => 'OdooField($name: ${runtimeType.toString()})';
}

// ─────────────────────────────────────────────────────────────────────────────
//  Scalar / simple fields
// ─────────────────────────────────────────────────────────────────────────────

/// `fields.Char` — short text (VARCHAR).
class Char extends OdooField {
  /// Maximum number of characters. `null` → unlimited.
  final int? size;

  /// Whether Odoo should store translations for this field.
  final bool translate;

  const Char(
    String name, {
    String? string,
    bool required = false,
    this.size,
    this.translate = false,
    dynamic defaultValue,
    String? help,
    bool inTree = false,
    bool inSearch = false,
    bool readonly = false,
    String? cssClass,
    Map<String, String> extra = const {},
  }) : super(
          name,
          string: string,
          required: required,
          defaultValue: defaultValue,
          help: help,
          inTree: inTree,
          inSearch: inSearch,
          readonly: readonly,
          cssClass: cssClass,
          extra: extra,
        );

  @override
  String toPython() {
    return buildPythonCall('Char', [], kwargs: {
      if (size != null) 'size': '$size',
      if (translate) 'translate': 'True',
    });
  }

  @override
  String toFormXML() => buildFormXMLElement();
}

// ─────────────────────────────────────────────────────────────────────────────

/// `fields.Text` — long text (TEXT column).
class Text extends OdooField {
  final bool translate;

  const Text(
    String name, {
    String? string,
    bool required = false,
    this.translate = false,
    dynamic defaultValue,
    String? help,
    bool inTree = false,
    bool inSearch = false,
    bool readonly = false,
    String? cssClass,
    Map<String, String> extra = const {},
  }) : super(
          name,
          string: string,
          required: required,
          defaultValue: defaultValue,
          help: help,
          inTree: inTree,
          inSearch: inSearch,
          readonly: readonly,
          cssClass: cssClass,
          extra: extra,
        );

  @override
  String toPython() => buildPythonCall('Text', [], kwargs: {
        if (translate) 'translate': 'True',
      });

  @override
  String toFormXML() => buildFormXMLElement(nolabel: true);
}

// ─────────────────────────────────────────────────────────────────────────────

/// `fields.Html` — rich-text HTML field.
class Html extends OdooField {
  final bool sanitize;

  const Html(
    String name, {
    String? string,
    bool required = false,
    this.sanitize = true,
    dynamic defaultValue,
    String? help,
    bool inTree = false,
    bool inSearch = false,
    bool readonly = false,
    String? cssClass,
    Map<String, String> extra = const {},
  }) : super(
          name,
          string: string,
          required: required,
          defaultValue: defaultValue,
          help: help,
          inTree: inTree,
          inSearch: inSearch,
          readonly: readonly,
          cssClass: cssClass,
          extra: extra,
        );

  @override
  String toPython() => buildPythonCall('Html', [], kwargs: {
        if (!sanitize) 'sanitize': 'False',
      });

  @override
  String toFormXML() => buildFormXMLElement(nolabel: true);
}

// ─────────────────────────────────────────────────────────────────────────────

/// `fields.Integer` — 32-bit integer.
class Integer extends OdooField {
  const Integer(
    String name, {
    String? string,
    bool required = false,
    dynamic defaultValue,
    String? help,
    bool inTree = false,
    bool inSearch = false,
    bool readonly = false,
    String? cssClass,
    Map<String, String> extra = const {},
  }) : super(
          name,
          string: string,
          required: required,
          defaultValue: defaultValue,
          help: help,
          inTree: inTree,
          inSearch: inSearch,
          readonly: readonly,
          cssClass: cssClass,
          extra: extra,
        );

  @override
  String toPython() => buildPythonCall('Integer', []);

  @override
  String toFormXML() => buildFormXMLElement();
}

// ─────────────────────────────────────────────────────────────────────────────

/// `fields.Float` — double-precision float with optional digit precision.
///
/// [digits] is rendered as `digits=(precision, scale)`.
class Float extends OdooField {
  /// Tuple `(total_digits, decimal_digits)`, e.g. `(10, 2)`.
  final (int, int)? digits;

  const Float(
    String name, {
    String? string,
    bool required = false,
    this.digits,
    dynamic defaultValue,
    String? help,
    bool inTree = false,
    bool inSearch = false,
    bool readonly = false,
    String? cssClass,
    Map<String, String> extra = const {},
  }) : super(
          name,
          string: string,
          required: required,
          defaultValue: defaultValue,
          help: help,
          inTree: inTree,
          inSearch: inSearch,
          readonly: readonly,
          cssClass: cssClass,
          extra: extra,
        );

  @override
  String toPython() => buildPythonCall('Float', [], kwargs: {
        if (digits != null) 'digits': '(${digits!.$1}, ${digits!.$2})',
      });

  @override
  String toFormXML() => buildFormXMLElement();
}

// ─────────────────────────────────────────────────────────────────────────────

/// `fields.Monetary` — currency-aware monetary field.
///
/// Requires a `currency_field` (defaults to `currency_id`) to be present
/// in the same model.
class Monetary extends OdooField {
  final String currencyField;

  const Monetary(
    String name, {
    String? string,
    bool required = false,
    this.currencyField = 'currency_id',
    dynamic defaultValue,
    String? help,
    bool inTree = false,
    bool inSearch = false,
    bool readonly = false,
    String? cssClass,
    Map<String, String> extra = const {},
  }) : super(
          name,
          string: string,
          required: required,
          defaultValue: defaultValue,
          help: help,
          inTree: inTree,
          inSearch: inSearch,
          readonly: readonly,
          cssClass: cssClass,
          extra: extra,
        );

  @override
  String toPython() => buildPythonCall('Monetary', [], kwargs: {
        'currency_field': "'$currencyField'",
      });

  @override
  String toFormXML() => buildFormXMLElement();
}

// ─────────────────────────────────────────────────────────────────────────────

/// `fields.Boolean` — checkbox.
class Boolean extends OdooField {
  const Boolean(
    String name, {
    String? string,
    bool required = false,
    dynamic defaultValue,
    String? help,
    bool inTree = false,
    bool inSearch = false,
    bool readonly = false,
    String? cssClass,
    Map<String, String> extra = const {},
  }) : super(
          name,
          string: string,
          required: required,
          defaultValue: defaultValue,
          help: help,
          inTree: inTree,
          inSearch: inSearch,
          readonly: readonly,
          cssClass: cssClass,
          extra: extra,
        );

  @override
  String toPython() => buildPythonCall('Boolean', []);

  @override
  String toFormXML() => buildFormXMLElement();
}

// ─────────────────────────────────────────────────────────────────────────────

/// `fields.Date` — calendar date (no time component).
class Date extends OdooField {
  const Date(
    String name, {
    String? string,
    bool required = false,
    dynamic defaultValue,
    String? help,
    bool inTree = false,
    bool inSearch = false,
    bool readonly = false,
    String? cssClass,
    Map<String, String> extra = const {},
  }) : super(
          name,
          string: string,
          required: required,
          defaultValue: defaultValue,
          help: help,
          inTree: inTree,
          inSearch: inSearch,
          readonly: readonly,
          cssClass: cssClass,
          extra: extra,
        );

  @override
  String toPython() => buildPythonCall('Date', []);

  @override
  String toFormXML() => buildFormXMLElement();
}

// ─────────────────────────────────────────────────────────────────────────────

/// `fields.Datetime` — date + time (UTC stored).
class Datetime extends OdooField {
  const Datetime(
    String name, {
    String? string,
    bool required = false,
    dynamic defaultValue,
    String? help,
    bool inTree = false,
    bool inSearch = false,
    bool readonly = false,
    String? cssClass,
    Map<String, String> extra = const {},
  }) : super(
          name,
          string: string,
          required: required,
          defaultValue: defaultValue,
          help: help,
          inTree: inTree,
          inSearch: inSearch,
          readonly: readonly,
          cssClass: cssClass,
          extra: extra,
        );

  @override
  String toPython() => buildPythonCall('Datetime', []);

  @override
  String toFormXML() => buildFormXMLElement();
}

// ─────────────────────────────────────────────────────────────────────────────

/// `fields.Binary` — file attachment stored as base64.
class Binary extends OdooField {
  /// Whether Odoo stores the attachment in the IR attachment table.
  final bool attachment;

  const Binary(
    String name, {
    String? string,
    bool required = false,
    this.attachment = true,
    String? help,
    bool inTree = false,
    bool inSearch = false,
    bool readonly = false,
    String? cssClass,
    Map<String, String> extra = const {},
  }) : super(
          name,
          string: string,
          required: required,
          help: help,
          inTree: inTree,
          inSearch: inSearch,
          readonly: readonly,
          cssClass: cssClass,
          extra: extra,
        );

  @override
  String toPython() => buildPythonCall('Binary', [], kwargs: {
        if (!attachment) 'attachment': 'False',
      });

  @override
  String toFormXML() => buildFormXMLElement(widget: 'binary');
}

// ─────────────────────────────────────────────────────────────────────────────

/// `fields.Image` — image stored as base64.
class Image extends OdooField {
  final int maxWidth;
  final int maxHeight;

  const Image(
    String name, {
    String? string,
    bool required = false,
    this.maxWidth = 1920,
    this.maxHeight = 1920,
    String? help,
    bool inTree = false,
    bool inSearch = false,
    bool readonly = false,
    String? cssClass,
    Map<String, String> extra = const {},
  }) : super(
          name,
          string: string,
          required: required,
          help: help,
          inTree: inTree,
          inSearch: inSearch,
          readonly: readonly,
          cssClass: cssClass,
          extra: extra,
        );

  @override
  String toPython() => buildPythonCall('Image', [], kwargs: {
        'max_width': '$maxWidth',
        'max_height': '$maxHeight',
      });

  @override
  String toFormXML() => buildFormXMLElement(widget: 'image');
}

// ─────────────────────────────────────────────────────────────────────────────

/// `fields.Selection` — drop-down list.
///
/// [options] can be plain strings (used as both key and display value)
/// or `(key, label)` pairs via [rawOptions].
class Selection extends OdooField {
  /// Simple list of option values; label is auto-capitalized.
  final List<String> options;

  /// Explicit `[(key, label), …]` pairs — takes precedence over [options].
  final List<(String, String)>? rawOptions;

  const Selection(
    String name,
    this.options, {
    this.rawOptions,
    String? string,
    bool required = false,
    dynamic defaultValue,
    String? help,
    bool inTree = false,
    bool inSearch = false,
    bool readonly = false,
    String? cssClass,
    Map<String, String> extra = const {},
  }) : super(
          name,
          string: string,
          required: required,
          defaultValue: defaultValue,
          help: help,
          inTree: inTree,
          inSearch: inSearch,
          readonly: readonly,
          cssClass: cssClass,
          extra: extra,
        );

  /// Resolves the final list of `(key, label)` tuples.
  List<(String, String)> get resolvedOptions {
    if (rawOptions != null) return rawOptions!;
    return options.map((o) => (o, NamingConventions.toLabel(o))).toList();
  }

  @override
  String toPython() {
    final pairs =
        resolvedOptions.map((p) => "('${p.$1}', '${p.$2}')").join(', ');
    return buildPythonCall('Selection', ['[$pairs]']);
  }

  @override
  String toFormXML() => buildFormXMLElement(widget: 'statusbar');

  @override
  String toSearchXML() =>
      '<filter name="filter_${name}_${options.first}" '
      'string="${NamingConventions.toLabel(options.first)}" '
      'domain="[(\'$name\', \'=\', \'${options.first}\')]"/>';
}

// ─────────────────────────────────────────────────────────────────────────────
//  Relational fields
// ─────────────────────────────────────────────────────────────────────────────

/// `fields.Many2one` — foreign key to another model.
class Many2one extends OdooField {
  /// The target model technical name, e.g. `'res.partner'`.
  final String relation;

  /// `ondelete` policy: `'set null'`, `'restrict'`, or `'cascade'`.
  final String ondelete;

  /// Emit `@api.onchange` stub for this field.
  final bool onchange;

  /// Domain filter applied in the UI picker.
  final String? domain;

  const Many2one(
    String name, {
    required this.relation,
    String? string,
    bool required = false,
    this.ondelete = 'set null',
    this.onchange = false,
    this.domain,
    dynamic defaultValue,
    String? help,
    bool inTree = false,
    bool inSearch = false,
    bool readonly = false,
    String? cssClass,
    Map<String, String> extra = const {},
  }) : super(
          name,
          string: string,
          required: required,
          defaultValue: defaultValue,
          help: help,
          inTree: inTree,
          inSearch: inSearch,
          readonly: readonly,
          cssClass: cssClass,
          extra: extra,
        );

  @override
  String toPython() => buildPythonCall("Many2one", ["'$relation'"], kwargs: {
        "ondelete": "'$ondelete'",
        if (domain != null) 'domain': "'$domain'",
      });

  @override
  String toFormXML() {
    final domainAttr = domain != null ? ' domain="$domain"' : '';
    return '<field name="$name"$domainAttr${readonly ? ' readonly="1"' : ''}/>';
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// `fields.One2many` — inverse of a Many2one on the target model.
class One2many extends OdooField {
  final String relation;
  final String inverseField;

  const One2many(
    String name, {
    required this.relation,
    required this.inverseField,
    String? string,
    bool required = false,
    String? help,
    bool inTree = false,
    bool inSearch = false,
    bool readonly = false,
    String? cssClass,
    Map<String, String> extra = const {},
  }) : super(
          name,
          string: string,
          required: required,
          help: help,
          inTree: inTree,
          inSearch: inSearch,
          readonly: readonly,
          cssClass: cssClass,
          extra: extra,
        );

  @override
  String toPython() =>
      buildPythonCall('One2many', ["'$relation'", "'$inverseField'"]);

  @override
  String toFormXML() =>
      '<field name="$name" widget="one2many_list"${readonly ? ' readonly="1"' : ''}/>';
}

// ─────────────────────────────────────────────────────────────────────────────

/// `fields.Many2many` — many-to-many relation through a pivot table.
class Many2many extends OdooField {
  final String relation;

  /// Explicit pivot table name. Auto-generated when `null`.
  final String? relationTable;
  final String column1;
  final String column2;

  const Many2many(
    String name, {
    required this.relation,
    this.relationTable,
    this.column1 = 'left_id',
    this.column2 = 'right_id',
    String? string,
    bool required = false,
    String? help,
    bool inTree = false,
    bool inSearch = false,
    bool readonly = false,
    String? cssClass,
    Map<String, String> extra = const {},
  }) : super(
          name,
          string: string,
          required: required,
          help: help,
          inTree: inTree,
          inSearch: inSearch,
          readonly: readonly,
          cssClass: cssClass,
          extra: extra,
        );

  @override
  String toPython() {
    final table = relationTable ?? 'rel_${name}';
    return '${buildPythonCall('Many2many', ["'$relation'", "'$table'", "'$column1'", "'$column2'"])}  # View widget: many2many_tags';
  }

  @override
  String toFormXML() =>
      '<field name="$name" widget="many2many_tags"${readonly ? ' readonly="1"' : ''}/>';
}

// ─────────────────────────────────────────────────────────────────────────────
//  Computed / special fields
// ─────────────────────────────────────────────────────────────────────────────

/// `fields.Float / Integer / Char / …` with `compute=…`.
///
/// [fieldType] is the Odoo Python type name, e.g. `'Float'`.
class ComputedField extends OdooField {
  final String fieldType;
  final String computeMethod;
  final bool store;
  final List<String> depends;

  /// Optional digit precision — only meaningful for Float computed fields.
  final (int, int)? digits;

  const ComputedField(
    String name, {
    this.fieldType = 'Float',
    required this.computeMethod,
    this.store = false,
    this.depends = const [],
    this.digits,
    String? string,
    bool required = false,
    String? help,
    bool inTree = false,
    bool inSearch = false,
    bool readonly = true,
    String? cssClass,
    Map<String, String> extra = const {},
  }) : super(
          name,
          string: string,
          required: required,
          help: help,
          inTree: inTree,
          inSearch: inSearch,
          readonly: readonly,
          cssClass: cssClass,
          extra: extra,
        );

  @override
  String toPython() => buildPythonCall(fieldType, [], kwargs: {
        'compute': "'$computeMethod'",
        if (store) 'store': 'True',
        if (digits != null) 'digits': '(${digits!.$1}, ${digits!.$2})',
      });

  @override
  String toFormXML() => buildFormXMLElement();
}

// ─────────────────────────────────────────────────────────────────────────────

/// A pseudo-field that emits `_rec_name`-compatible Char used as display name.
///
/// Convenience wrapper: equivalent to `Char('name', required: true)`.
class NameField extends Char {
  const NameField({
    String fieldName = 'name',
    String string = 'Name',
    bool translate = false,
  }) : super(
          fieldName,
          string: string,
          required: true,
          translate: translate,
          inTree: true,
          inSearch: true,
        );
}

// ─────────────────────────────────────────────────────────────────────────────

/// `fields.Reference` — dynamic relation pointing to any model.
class Reference extends OdooField {
  final List<String> allowedModels;

  const Reference(
    String name, {
    required this.allowedModels,
    String? string,
    bool required = false,
    String? help,
    bool inTree = false,
    bool inSearch = false,
    bool readonly = false,
    Map<String, String> extra = const {},
  }) : super(
          name,
          string: string,
          required: required,
          help: help,
          inTree: inTree,
          inSearch: inSearch,
          readonly: readonly,
          extra: extra,
        );

  @override
  String toPython() {
    final sel =
        allowedModels.map((m) => "('$m', '${NamingConventions.toLabel(m)}')").join(', ');
    return buildPythonCall('Reference', ['[$sel]']);
  }

  @override
  String toFormXML() => buildFormXMLElement();
}
