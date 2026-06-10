/// Core model builder — the primary public-facing API of the package.
library odoo_model_generator.model_builder;

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import 'exceptions.dart';
import 'field_types.dart';
import 'validators.dart';
import '../codegen/python_generator.dart';
import '../codegen/xml_generator.dart';
import '../utils/file_handler.dart';
import '../utils/naming_conventions.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Generator configuration value-object
// ─────────────────────────────────────────────────────────────────────────────

/// Immutable configuration passed to [OdooModel.generate].
@immutable
class GeneratorConfig {
  /// Odoo module version string (SemVer).
  final String version;

  /// Author name written into `__manifest__.py`.
  final String author;

  /// Author website written into `__manifest__.py`.
  final String website;

  /// License identifier (LGPL-3, OPL-1, etc.).
  final String license;

  /// Category in the Odoo App Store.
  final String category;

  /// Whether to mark the module as an application in the manifest.
  final bool isApplication;

  /// Whether to auto-open the output folder after generation (macOS/Linux).
  final bool openFolder;

  /// Whether to generate `__init__.py` file inside `models/`.
  final bool generateModelsInit;

  /// Whether to generate the `security/ir.model.access.csv` file.
  final bool generateSecurity;

  /// Whether to generate a `data/` demo XML file stub.
  final bool generateDemoStub;

  /// Extra Odoo module names appended to the `depends` list.
  final List<String> extraDependencies;

  const GeneratorConfig({
    this.version = '1.0.0',
    this.author = 'Your Company',
    this.website = 'https://yourcompany.com',
    this.license = 'LGPL-3',
    this.category = 'Custom',
    this.isApplication = false,
    this.openFolder = false,
    this.generateModelsInit = true,
    this.generateSecurity = true,
    this.generateDemoStub = false,
    this.extraDependencies = const [],
  });

  /// Creates a copy with overridden fields.
  GeneratorConfig copyWith({
    String? version,
    String? author,
    String? website,
    String? license,
    String? category,
    bool? isApplication,
    bool? openFolder,
    bool? generateModelsInit,
    bool? generateSecurity,
    bool? generateDemoStub,
    List<String>? extraDependencies,
  }) {
    return GeneratorConfig(
      version: version ?? this.version,
      author: author ?? this.author,
      website: website ?? this.website,
      license: license ?? this.license,
      category: category ?? this.category,
      isApplication: isApplication ?? this.isApplication,
      openFolder: openFolder ?? this.openFolder,
      generateModelsInit: generateModelsInit ?? this.generateModelsInit,
      generateSecurity: generateSecurity ?? this.generateSecurity,
      generateDemoStub: generateDemoStub ?? this.generateDemoStub,
      extraDependencies: extraDependencies ?? this.extraDependencies,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  OnchangeDefinition — metadata for @api.onchange stubs
// ─────────────────────────────────────────────────────────────────────────────

/// Describes a single `@api.onchange` method to emit in `models.py`.
@immutable
class OnchangeDefinition {
  /// Fields that trigger this onchange.
  final List<String> triggerFields;

  /// Name of the method, e.g. `'_onchange_partner_id'`.
  final String methodName;

  /// Optional body lines inserted verbatim (each indented 8 spaces).
  final List<String> bodyLines;

  const OnchangeDefinition({
    required this.triggerFields,
    required this.methodName,
    this.bodyLines = const ['pass'],
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  ConstraintDefinition — metadata for @api.constrains stubs
// ─────────────────────────────────────────────────────────────────────────────

/// Describes a single `@api.constrains` method to emit in `models.py`.
@immutable
class ConstraintDefinition {
  final List<String> constrainedFields;
  final String methodName;
  final String errorMessage;
  final List<String> bodyLines;

  const ConstraintDefinition({
    required this.constrainedFields,
    required this.methodName,
    required this.errorMessage,
    this.bodyLines = const [],
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  ComputeDefinition — metadata for @api.depends compute methods
// ─────────────────────────────────────────────────────────────────────────────

/// Describes the compute method body for a [ComputedField].
@immutable
class ComputeDefinition {
  /// Must match [ComputedField.computeMethod].
  final String methodName;
  final List<String> dependsOn;
  final List<String> bodyLines;

  const ComputeDefinition({
    required this.methodName,
    required this.dependsOn,
    this.bodyLines = const ['pass'],
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  InheritMode
// ─────────────────────────────────────────────────────────────────────────────

/// How the generated model inherits from Odoo built-ins.
enum InheritMode {
  /// `_inherit = ['mail.thread', …]` — classic mixin.
  mixin,

  /// `_inherit = 'res.partner'` — extension of an existing model (no `_name`).
  extension,
}

// ─────────────────────────────────────────────────────────────────────────────
//  OdooModel — the fluent builder
// ─────────────────────────────────────────────────────────────────────────────

/// Fluent builder for a single Odoo custom model.
///
/// ### Basic usage
/// ```dart
/// await OdooModel('x_product_custom')
///   .field(NameField())
///   .field(Float('price'))
///   .field(Many2one('supplier_id', relation: 'res.partner'))
///   .generate(outputPath: './output');
/// ```
///
/// ### Advanced usage — see `example/` folder.
class OdooModel {
  static final Logger _log = Logger('OdooModel');

  // ── identity ──────────────────────────────────────────────────────────────

  /// Odoo `_name` value, e.g. `'x_invoice_system'`.
  final String modelName;

  /// Short human description used as `_description`.
  final String? docstring;

  /// The field used as `_rec_name` (display name). Defaults to `'name'`.
  final String stringField;

  // ── fields registry ───────────────────────────────────────────────────────

  /// Ordered map of fields keyed by technical name.
  final Map<String, OdooField> _fields = {};

  // ── inheritance ───────────────────────────────────────────────────────────

  final List<String> _inherits = [];
  InheritMode _inheritMode = InheritMode.mixin;

  // ── dependencies ─────────────────────────────────────────────────────────

  final List<String> _dependencies = [];

  // ── advanced method definitions ───────────────────────────────────────────

  final List<OnchangeDefinition> _onchanges = [];
  final List<ConstraintDefinition> _constraints = [];
  final List<ComputeDefinition> _computes = [];

  // ── timestamps & sequence ─────────────────────────────────────────────────

  /// Whether to add read-only `create_date` / `write_date` shadow fields.
  final bool createTimestamp;

  /// Whether to add a `sequence` integer field and auto-assign in `create()`.
  final bool createSequence;

  // ── order ─────────────────────────────────────────────────────────────────

  /// Python `_order` value, e.g. `'create_date desc'`.
  final String? order;

  // ── SQL constraints ───────────────────────────────────────────────────────

  final List<(String, String, String)> _sqlConstraints = [];

  // ── constructor ───────────────────────────────────────────────────────────

  OdooModel(
    this.modelName, {
    this.docstring,
    this.stringField = 'name',
    this.createTimestamp = true,
    this.createSequence = false,
    this.order,
  });

  // ── field builder ─────────────────────────────────────────────────────────

  /// Adds [fieldDef] to the model.
  ///
  /// Throws [DuplicateFieldException] if a field with the same name already
  /// exists.
  OdooModel field(OdooField fieldDef) {
    if (_fields.containsKey(fieldDef.name)) {
      throw DuplicateFieldException(fieldDef.name);
    }
    Validators.fieldName(fieldDef.name);
    _fields[fieldDef.name] = fieldDef;
    return this;
  }

  // ── inheritance builder ───────────────────────────────────────────────────

  /// Adds a mixin parent, e.g. `inherit('mail.thread')`.
  OdooModel inherit(String parentModel, {InheritMode mode = InheritMode.mixin}) {
    _inherits.add(parentModel);
    _inheritMode = mode;
    return this;
  }

  // ── dependency builder ────────────────────────────────────────────────────

  /// Adds an Odoo module dependency.
  OdooModel dependency(String moduleName) {
    if (!_dependencies.contains(moduleName)) {
      _dependencies.add(moduleName);
    }
    return this;
  }

  // ── onchange builder ──────────────────────────────────────────────────────

  /// Registers an `@api.onchange` method stub.
  OdooModel onchange(OnchangeDefinition definition) {
    _onchanges.add(definition);
    return this;
  }

  // ── constraint builder ────────────────────────────────────────────────────

  /// Registers an `@api.constrains` method stub.
  OdooModel constraint(ConstraintDefinition definition) {
    _constraints.add(definition);
    return this;
  }

  // ── compute builder ───────────────────────────────────────────────────────

  /// Registers a `@api.depends` compute method body for a [ComputedField].
  OdooModel compute(ComputeDefinition definition) {
    _computes.add(definition);
    return this;
  }

  // ── SQL constraint builder ────────────────────────────────────────────────

  /// Adds a PostgreSQL-level `UNIQUE` / `CHECK` constraint.
  ///
  /// [id] — unique Python identifier, [expression] — SQL expression,
  /// [message] — user-facing error message.
  OdooModel sqlConstraint(String id, String expression, String message) {
    _sqlConstraints.add((id, expression, message));
    return this;
  }

  // ── read-only accessors ───────────────────────────────────────────────────

  /// All declared fields in insertion order.
  List<OdooField> get fields => List.unmodifiable(_fields.values.toList());

  /// Inherited mixin names.
  List<String> get inherits => List.unmodifiable(_inherits);

  /// Declared module dependencies (excluding `'base'` which is always added).
  List<String> get dependencies => List.unmodifiable(_dependencies);

  /// Onchange stubs.
  List<OnchangeDefinition> get onchanges => List.unmodifiable(_onchanges);

  /// Constraint stubs.
  List<ConstraintDefinition> get constraints =>
      List.unmodifiable(_constraints);

  /// Compute method stubs.
  List<ComputeDefinition> get computes => List.unmodifiable(_computes);

  /// SQL constraints.
  List<(String, String, String)> get sqlConstraints =>
      List.unmodifiable(_sqlConstraints);

  InheritMode get inheritMode => _inheritMode;

  // ── generate ──────────────────────────────────────────────────────────────

  /// Validates the model definition and writes all output files.
  ///
  /// ```dart
  /// await model.generate(outputPath: './my_module');
  /// ```
  Future<GenerationResult> generate({
    String outputPath = './generated',
    GeneratorConfig config = const GeneratorConfig(),
  }) async {
    _log.info('Validating model "$modelName"…');

    // Validate
    Validators.fullModel(
      name: modelName,
      stringField: stringField,
      fields: _fields.values.toList(),
      dependencies: _dependencies,
    );

    _log.info('Generating files for "$modelName" → $outputPath');

    final pythonGen = PythonGenerator(this, config: config);
    final xmlGen = XmlGenerator(this, config: config);
    final handler = FileHandler(outputPath);

    // Create module directory structure
    await handler.createModuleStructure(modelName);

    final writtenFiles = <String>[];

    // __init__.py (root)
    final rootInit = handler.resolve('__init__.py');
    await handler.writeFile('__init__.py', "from . import models\n");
    writtenFiles.add(rootInit);

    // models/__init__.py
    if (config.generateModelsInit) {
      final modInit = handler.resolve('models/__init__.py');
      await handler.writeFile(
        'models/__init__.py',
        "from . import ${modelName.replaceAll('.', '_')}\n",
      );
      writtenFiles.add(modInit);
    }

    // models/<name>.py
    final modelFilePath = 'models/${modelName.replaceAll('.', '_')}.py';
    final modelFile = handler.resolve(modelFilePath);
    await handler.writeFile(modelFilePath, pythonGen.generate());
    writtenFiles.add(modelFile);

    // __manifest__.py
    final manifestFile = handler.resolve('__manifest__.py');
    await handler.writeFile('__manifest__.py', pythonGen.generateManifest());
    writtenFiles.add(manifestFile);

    // views/<name>_view.xml
    final viewPath =
        'views/${NamingConventions.viewFileName(modelName)}';
    final viewFile = handler.resolve(viewPath);
    await handler.writeFile(viewPath, xmlGen.generateViews());
    writtenFiles.add(viewFile);

    // security/ir.model.access.csv
    if (config.generateSecurity) {
      const secPath = 'security/ir.model.access.csv';
      final secFile = handler.resolve(secPath);
      await handler.writeFile(secPath, _generateSecurity());
      writtenFiles.add(secFile);
    }

    // data/demo.xml stub
    if (config.generateDemoStub) {
      const demoPath = 'data/demo.xml';
      final demoFile = handler.resolve(demoPath);
      await handler.writeFile(demoPath, _generateDemoStub());
      writtenFiles.add(demoFile);
    }

    final result = GenerationResult(
      modelName: modelName,
      outputPath: outputPath,
      writtenFiles: List.unmodifiable(writtenFiles),
    );

    _log.info('✅ Generation complete: ${writtenFiles.length} files written.');

    if (config.openFolder) {
      _tryOpenFolder(outputPath);
    }

    return result;
  }

  // ── private helpers ───────────────────────────────────────────────────────

  String _generateSecurity() {
    final modelRef = NamingConventions.modelRefId(modelName);
    final baseId = NamingConventions.accessId(modelName);
    return 'id,name,model_id:id,group_id:id,'
            'perm_read,perm_write,perm_create,perm_unlink\n'
        '${baseId}_user,${NamingConventions.toLabel(modelName)},'
            '$modelRef,base.group_user,1,1,1,0\n'
        '${baseId}_manager,${NamingConventions.toLabel(modelName)} Manager,'
            '$modelRef,base.group_system,1,1,1,1\n';
  }

  String _generateDemoStub() {
    return '<?xml version="1.0" encoding="utf-8"?>\n'
        '<odoo>\n'
        '    <!-- Add demo records here -->\n'
        '</odoo>\n';
  }

  void _tryOpenFolder(String path) {
    try {
      if (Platform.isMacOS) {
        Process.runSync('open', [path]);
      } else if (Platform.isLinux) {
        Process.runSync('xdg-open', [path]);
      } else if (Platform.isWindows) {
        Process.runSync('explorer', [path]);
      }
    } catch (_) {
      // Non-fatal: folder opener is a convenience feature.
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  GenerationResult — value object returned by generate()
// ─────────────────────────────────────────────────────────────────────────────

/// Holds metadata about a completed generation run.
@immutable
class GenerationResult {
  final String modelName;
  final String outputPath;
  final List<String> writtenFiles;

  const GenerationResult({
    required this.modelName,
    required this.outputPath,
    required this.writtenFiles,
  });

  @override
  String toString() =>
      'GenerationResult(model: $modelName, files: ${writtenFiles.length})';
}
