/// OOMG — Odoo Model Generator CLI
///
/// Usage:
///   dart run oomg generate --model x_product_custom --output ./out
///   dart run oomg validate --model x_product_custom
///   dart run oomg dry-run  --model x_product_custom
///   dart run oomg export   --module ./out/x_product_custom --zip ./module.zip
///   dart run oomg version
library oomg_cli;

import 'dart:io';
import 'dart:convert';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:logging/logging.dart';
import 'package:odoo_model_generator/odoo_model_generator.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Entry point
// ─────────────────────────────────────────────────────────────────────────────

Future<void> main(List<String> arguments) async {
  _setupLogging();

  final runner = CommandRunner<int>(
    'oomg',
    'Odoo Model Generator CLI — generate production-ready Odoo modules.',
  )
    ..addCommand(GenerateCommand())
    ..addCommand(ValidateCommand())
    ..addCommand(DryRunCommand())
    ..addCommand(ExportCommand())
    ..addCommand(VersionCommand());

  try {
    final exitCode = await runner.run(arguments) ?? 0;
    exit(exitCode);
  } catch (e, st) {
    if (e is UsageException) {
      stderr.writeln('Error: ${e.message}\n');
      stderr.writeln(e.usage);
      exit(64); // EX_USAGE
    } else {
      // Covers GeneratorException and all other unexpected errors.
      stderr.writeln('❌ $e');
      stderr.writeln(st);
      exit(1);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Logging setup
// ─────────────────────────────────────────────────────────────────────────────

void _setupLogging() {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((LogRecord r) {
    final prefix = switch (r.level) {
      Level.WARNING => '⚠️ ',
      Level.SEVERE => '❌ ',
      Level.INFO => 'ℹ️  ',
      _ => '',
    };
    stderr.writeln('$prefix${r.loggerName}: ${r.message}');
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared option builder
// ─────────────────────────────────────────────────────────────────────────────

/// Adds the common --schema flag to any [ArgParser].
void _addSchemaOption(ArgParser parser) {
  parser
    ..addOption(
      'schema',
      abbr: 's',
      help:
          'Path to a JSON schema file describing the model. '
          'If omitted, a minimal model is generated using --model.',
      valueHelp: 'FILE',
    )
    ..addOption(
      'model',
      abbr: 'm',
      help: 'Odoo model name (e.g. x_product_custom).',
      valueHelp: 'MODEL_NAME',
    )
    ..addOption(
      'output',
      abbr: 'o',
      defaultsTo: './generated',
      help: 'Output directory for the generated module.',
      valueHelp: 'DIR',
    )
    ..addFlag(
      'open',
      help: 'Open the output folder after generation.',
      defaultsTo: false,
      negatable: false,
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      help: 'Enable verbose logging.',
      defaultsTo: false,
      negatable: false,
    );
}

// ─────────────────────────────────────────────────────────────────────────────
//  JSON schema → OdooModel builder
// ─────────────────────────────────────────────────────────────────────────────

/// Loads a JSON schema and builds an [OdooModel] from it.
///
/// Schema shape:
/// ```json
/// {
///   "modelName": "x_product_custom",
///   "docstring": "Custom product",
///   "stringField": "name",
///   "dependencies": ["sale", "stock"],
///   "inherits": ["mail.thread"],
///   "fields": [
///     { "type": "Char",    "name": "name",        "required": true  },
///     { "type": "Float",   "name": "price",       "digits": [10, 2] },
///     { "type": "Many2one","name": "supplier_id", "relation": "res.partner" },
///     { "type": "Selection","name": "state",
///       "options": ["draft","confirmed","paid"] }
///   ]
/// }
/// ```
OdooModel _buildFromSchema(Map<String, dynamic> schema) {
  final modelName = schema['modelName'] as String;
  final docstring = schema['docstring'] as String?;
  final stringField = (schema['stringField'] as String?) ?? 'name';

  final model = OdooModel(
    modelName,
    docstring: docstring,
    stringField: stringField,
  );

  // Dependencies
  for (final dep in (schema['dependencies'] as List? ?? [])) {
    model.dependency(dep as String);
  }

  // Inherits
  for (final inh in (schema['inherits'] as List? ?? [])) {
    model.inherit(inh as String);
  }

  // Fields
  for (final fd in (schema['fields'] as List? ?? [])) {
    final f = fd as Map<String, dynamic>;
    final field = _buildField(f);
    if (field != null) model.field(field);
  }

  return model;
}

OdooField? _buildField(Map<String, dynamic> f) {
  final type = (f['type'] as String).toLowerCase();
  final name = f['name'] as String;
  final string = f['string'] as String?;
  final required = (f['required'] as bool?) ?? false;
  final help = f['help'] as String?;
  final inTree = (f['inTree'] as bool?) ?? false;
  final inSearch = (f['inSearch'] as bool?) ?? false;

  return switch (type) {
    'char' => Char(name,
        string: string,
        required: required,
        help: help,
        inTree: inTree,
        inSearch: inSearch,
        size: f['size'] as int?),
    'text' => Text(name, string: string, required: required, help: help),
    'html' => Html(name, string: string),
    'integer' => Integer(name,
        string: string, required: required, help: help, inTree: inTree),
    'float' => Float(
        name,
        string: string,
        required: required,
        help: help,
        digits: f['digits'] != null
            ? ((f['digits'] as List).first as int,
                (f['digits'] as List).last as int)
            : null,
      ),
    'monetary' => Monetary(name, string: string),
    'boolean' => Boolean(name, string: string),
    'date' => Date(name, string: string, required: required),
    'datetime' => Datetime(name, string: string, required: required),
    'binary' => Binary(name, string: string),
    'image' => Image(name, string: string),
    'selection' => Selection(
        name,
        (f['options'] as List).cast<String>(),
        string: string,
        required: required,
      ),
    'many2one' => Many2one(
        name,
        relation: f['relation'] as String,
        string: string,
        required: required,
        ondelete: (f['ondelete'] as String?) ?? 'set null',
        inTree: inTree,
        inSearch: inSearch,
      ),
    'one2many' => One2many(
        name,
        relation: f['relation'] as String,
        inverseField: f['inverseField'] as String,
        string: string,
      ),
    'many2many' => Many2many(
        name,
        relation: f['relation'] as String,
        string: string,
      ),
    _ => null,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
//  generate command
// ─────────────────────────────────────────────────────────────────────────────

class GenerateCommand extends Command<int> {
  String get name => 'generate';
  String get description => 'Generate a full Odoo module from a model definition.';
  List<String> get aliases => ['gen', 'g'];

  GenerateCommand() {
    _addSchemaOption(argParser);
    argParser
      ..addOption('author', defaultsTo: 'Your Company')
      ..addOption('version', defaultsTo: '1.0.0')
      ..addOption('license', defaultsTo: 'LGPL-3')
      ..addFlag('no-security', defaultsTo: false, negatable: false,
          help: 'Skip generating security/ir.model.access.csv')
      ..addFlag('demo', defaultsTo: false, negatable: false,
          help: 'Generate a data/demo.xml stub');
  }

  Future<int> run() async {
    if (argResults!['verbose'] as bool) {
      Logger.root.level = Level.ALL;
    }

    final model = _resolveModel();
    final output = argResults!['output'] as String;
    final config = GeneratorConfig(
      author: argResults!['author'] as String,
      version: argResults!['version'] as String,
      license: argResults!['license'] as String,
      generateSecurity: !(argResults!['no-security'] as bool),
      generateDemoStub: argResults!['demo'] as bool,
      openFolder: argResults!['open'] as bool,
    );

    final stopwatch = Stopwatch()..start();
    final result = await model.generate(outputPath: output, config: config);
    stopwatch.stop();

    final report = GenerationReport(
      modelName: result.modelName,
      outputPath: result.outputPath,
      writtenFiles: result.writtenFiles,
      elapsed: stopwatch.elapsed,
    );

    stdout.writeln(report.render());
    return 0;
  }

  OdooModel _resolveModel() {
    final schemaPath = argResults!['schema'] as String?;
    if (schemaPath != null) {
      final raw = File(schemaPath).readAsStringSync();
      final schema = jsonDecode(raw) as Map<String, dynamic>;
      return _buildFromSchema(schema);
    }

    final modelName = argResults!['model'] as String?;
    if (modelName == null) {
      throw UsageException(
        'Provide --schema FILE or --model MODEL_NAME.',
        usage,
      );
    }

    return OdooModel(modelName).field(NameField());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  validate command
// ─────────────────────────────────────────────────────────────────────────────

class ValidateCommand extends Command<int> {
  String get name => 'validate';
  String get description => 'Validate a model definition without writing files.';
  List<String> get aliases => ['check'];

  ValidateCommand() {
    _addSchemaOption(argParser);
  }

  Future<int> run() async {
    final schemaPath = argResults!['schema'] as String?;
    final modelName = argResults!['model'] as String?;

    try {
      if (schemaPath != null) {
        final raw = File(schemaPath).readAsStringSync();
        final schema = jsonDecode(raw) as Map<String, dynamic>;
        final model = _buildFromSchema(schema);
        Validators.fullModel(
          name: model.modelName,
          stringField: model.stringField,
          fields: model.fields,
          dependencies: model.dependencies,
        );
      } else if (modelName != null) {
        Validators.modelName(modelName);
      } else {
        throw UsageException(
          'Provide --schema FILE or --model MODEL_NAME.',
          usage,
        );
      }

      stdout.writeln('✅ Validation passed.');
      return 0;
    } catch (e) {
      stderr.writeln('❌ Validation failed: $e');
      return 1;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  dry-run command
// ─────────────────────────────────────────────────────────────────────────────

class DryRunCommand extends Command<int> {
  String get name => 'dry-run';
  String get description =>
      'Validate and preview generated content WITHOUT writing files.';
  List<String> get aliases => ['preview'];

  DryRunCommand() {
    _addSchemaOption(argParser);
    argParser.addOption(
      'file',
      abbr: 'f',
      help: 'Show only a specific file (models, manifest, views, security).',
      allowed: ['models', 'manifest', 'views', 'security', 'all'],
      defaultsTo: 'all',
    );
  }

  Future<int> run() async {
    final model = _resolveModel();
    final generator = OdooGenerator(model);
    final files = generator.dryRun();

    final target = argResults!['file'] as String;

    for (final entry in files.entries) {
      if (target != 'all') {
        final key = entry.key;
        if (target == 'models' && !key.contains('models/')) continue;
        if (target == 'manifest' && !key.contains('manifest')) continue;
        if (target == 'views' && !key.contains('views/')) continue;
        if (target == 'security' && !key.contains('security')) continue;
      }

      stdout.writeln('\n${'═' * 60}');
      stdout.writeln('FILE: ${entry.key}');
      stdout.writeln('═' * 60);
      stdout.writeln(entry.value);
    }

    return 0;
  }

  OdooModel _resolveModel() {
    final schemaPath = argResults!['schema'] as String?;
    if (schemaPath != null) {
      final raw = File(schemaPath).readAsStringSync();
      return _buildFromSchema(jsonDecode(raw) as Map<String, dynamic>);
    }
    final modelName = argResults!['model'] as String?;
    if (modelName == null) {
      throw UsageException('Provide --schema or --model.', usage);
    }
    return OdooModel(modelName).field(NameField());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  export command
// ─────────────────────────────────────────────────────────────────────────────

class ExportCommand extends Command<int> {
  String get name => 'export';
  String get description => 'Package a generated module directory into a ZIP archive.';

  ExportCommand() {
    argParser
      ..addOption(
        'module',
        abbr: 'm',
        mandatory: true,
        help: 'Path to the generated module directory.',
        valueHelp: 'DIR',
      )
      ..addOption(
        'zip',
        abbr: 'z',
        mandatory: true,
        help: 'Output ZIP file path.',
        valueHelp: 'FILE',
      )
      ..addOption(
        'format',
        defaultsTo: 'zip',
        allowed: ['zip', 'tar'],
        help: 'Archive format.',
      );
  }

  Future<int> run() async {
    final modulePath = argResults!['module'] as String;
    final outputFile = argResults!['zip'] as String;
    final format = argResults!['format'] == 'tar'
        ? ExportFormat.tar
        : ExportFormat.zip;

    final exporter = ModuleExporter();
    final file = await exporter.export(
      modulePath,
      outputFile: outputFile,
      format: format,
    );

    stdout.writeln('✅ Module exported → ${file.path}');
    return 0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  version command
// ─────────────────────────────────────────────────────────────────────────────

class VersionCommand extends Command<int> {
  String get name => 'version';
  String get description => 'Print the installed package version.';
  List<String> get aliases => ['--version', '-V'];

  Future<int> run() async {
    stdout.writeln('odoo_model_generator v2.0.0');
    stdout.writeln('Dart SDK: ${Platform.version}');
    return 0;
  }
}
