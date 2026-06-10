/// Main generation engine — thin orchestration layer.
///
/// Prefer using [OdooModel.generate] directly.
/// [OdooGenerator] exists for advanced use-cases where you need
/// programmatic control over the generation pipeline.
library odoo_model_generator.generator;

import 'dart:async';

import 'package:logging/logging.dart';

import 'model_builder.dart';
import 'validators.dart';
import '../codegen/python_generator.dart';
import '../codegen/xml_generator.dart';
import '../utils/naming_conventions.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  OdooGenerator
// ─────────────────────────────────────────────────────────────────────────────

/// Full code-generation pipeline for a single [OdooModel].
///
/// This class exists for advanced use-cases (e.g. dry-run, custom output
/// routing). For everyday usage, call `model.generate(outputPath: …)` instead.
class OdooGenerator {
  static final Logger _log = Logger('OdooGenerator');

  final OdooModel model;
  final String outputPath;
  final GeneratorConfig config;

  const OdooGenerator(
    this.model, {
    this.outputPath = './generated',
    this.config = const GeneratorConfig(),
  });

  // ── dry-run ───────────────────────────────────────────────────────────────

  /// Validates the model and returns the would-be file contents WITHOUT
  /// writing to disk.
  ///
  /// Returns a map of `relativePath → content`.
  Map<String, String> dryRun() {
    _log.info('Dry-run for "${model.modelName}"…');

    Validators.fullModel(
      name: model.modelName,
      stringField: model.stringField,
      fields: model.fields,
      dependencies: model.dependencies,
    );

    final pythonGen = PythonGenerator(model, config: config);
    final xmlGen = XmlGenerator(model, config: config);

    final results = <String, String>{};

    results['__init__.py'] = 'from . import models\n';

    // models/<name>.py inserted BEFORE models/__init__.py so that
    // firstWhere((e) => e.key.contains('models/')) finds the model file first.
    final pyFile = model.modelName.replaceAll('.', '_');
    results['models/$pyFile.py'] = pythonGen.generate();

    if (config.generateModelsInit) {
      results['models/__init__.py'] =
          'from . import ${model.modelName.replaceAll(".", "_")}\n';
    }

    results['__manifest__.py'] = pythonGen.generateManifest();

    results['views/${NamingConventions.viewFileName(model.modelName)}'] =
        xmlGen.generateViews();

    if (config.generateSecurity) {
      results['security/ir.model.access.csv'] = _buildSecurity();
    }

    if (config.generateDemoStub) {
      results['data/demo.xml'] =
          '<?xml version="1.0" encoding="utf-8"?>\n<odoo/>\n';
    }

    return Map.unmodifiable(results);
  }

  // ── full generate (delegates to OdooModel) ────────────────────────────────

  /// Executes the full generation pipeline and writes files to [outputPath].
  Future<GenerationResult> generate() => model.generate(
        outputPath: outputPath,
        config: config,
      );

  // ── helpers ───────────────────────────────────────────────────────────────

  String _buildSecurity() {
    final modelRef = NamingConventions.modelRefId(model.modelName);
    final baseId = NamingConventions.accessId(model.modelName);
    return 'id,name,model_id:id,group_id:id,'
            'perm_read,perm_write,perm_create,perm_unlink\n'
        '${baseId}_user,${NamingConventions.toLabel(model.modelName)},'
            '$modelRef,base.group_user,1,1,1,0\n'
        '${baseId}_manager,${NamingConventions.toLabel(model.modelName)} Manager,'
            '$modelRef,base.group_system,1,1,1,1\n';
  }
}
