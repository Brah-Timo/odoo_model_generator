/// Parallel generation of multiple Odoo modules.
library odoo_model_generator.parallel_generator;

import 'dart:async';

import 'package:logging/logging.dart';

import 'core/model_builder.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ParallelGenerationResult
// ─────────────────────────────────────────────────────────────────────────────

/// Aggregated result of a multi-model generation run.
class ParallelGenerationResult {
  final List<GenerationResult> successful;
  final List<({String modelName, Object error, StackTrace stackTrace})> failed;

  const ParallelGenerationResult({
    required this.successful,
    required this.failed,
  });

  bool get hasErrors => failed.isNotEmpty;
  int get totalFiles =>
      successful.fold(0, (acc, r) => acc + r.writtenFiles.length);

  @override
  String toString() =>
      'ParallelGenerationResult('
      'success=${successful.length}, '
      'failed=${failed.length}, '
      'totalFiles=$totalFiles)';
}

// ─────────────────────────────────────────────────────────────────────────────
//  ParallelGenerator
// ─────────────────────────────────────────────────────────────────────────────

/// Generates multiple [OdooModel]s concurrently using [Future.wait].
///
/// Each model is generated independently; failures do NOT abort sibling tasks.
class ParallelGenerator {
  static final Logger _log = Logger('ParallelGenerator');

  final GeneratorConfig config;

  /// Maximum number of concurrent generation tasks.
  /// `null` means no limit (all models start simultaneously).
  final int? concurrency;

  const ParallelGenerator({
    this.config = const GeneratorConfig(),
    this.concurrency,
  });

  // ── generate ──────────────────────────────────────────────────────────────

  /// Generates all [models] in parallel, each into [outputPath].
  ///
  /// Each model gets its own sub-directory:
  /// `<outputPath>/<modelName>/`
  Future<ParallelGenerationResult> generateAll(
    List<OdooModel> models, {
    required String outputPath,
  }) async {
    _log.info('Starting parallel generation for ${models.length} models…');

    final successful = <GenerationResult>[];
    final failed =
        <({String modelName, Object error, StackTrace stackTrace})>[];

    if (concurrency == null) {
      final futures = models.map((m) => _safeGenerate(m, outputPath));
      final results = await Future.wait(futures, eagerError: false);
      _collect(results, successful, failed);
    } else {
      for (var i = 0; i < models.length; i += concurrency!) {
        final end = (i + concurrency!) > models.length
            ? models.length
            : i + concurrency!;
        final chunk = models.sublist(i, end);
        final futures = chunk.map((m) => _safeGenerate(m, outputPath));
        final results = await Future.wait(futures, eagerError: false);
        _collect(results, successful, failed);
      }
    }

    final result = ParallelGenerationResult(
      successful: List.unmodifiable(successful),
      failed: List.unmodifiable(failed),
    );

    _log.info('Parallel generation complete: $result');
    return result;
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  void _collect(
    List<Object> results,
    List<GenerationResult> successful,
    List<({String modelName, Object error, StackTrace stackTrace})> failed,
  ) {
    for (final r in results) {
      if (r is GenerationResult) {
        successful.add(r);
      } else if (r is _FailedGeneration) {
        failed.add((
          modelName: r.modelName,
          error: r.error,
          stackTrace: r.stackTrace,
        ));
      }
    }
  }

  Future<Object> _safeGenerate(OdooModel model, String outputPath) async {
    try {
      return await model.generate(
        outputPath: '$outputPath/${model.modelName}',
        config: config,
      );
    } catch (e, st) {
      _log.warning('Generation failed for "${model.modelName}": $e', e, st);
      return _FailedGeneration(model.modelName, e, st);
    }
  }
}

class _FailedGeneration {
  final String modelName;
  final Object error;
  final StackTrace stackTrace;
  const _FailedGeneration(this.modelName, this.error, this.stackTrace);
}
