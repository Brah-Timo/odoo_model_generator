/// Zip/tar exporter for generated Odoo modules.
library odoo_model_generator.module_exporter;

import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'core/exceptions.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ExportFormat
// ─────────────────────────────────────────────────────────────────────────────

/// Output archive format.
enum ExportFormat { zip, tar }

// ─────────────────────────────────────────────────────────────────────────────
//  ModuleExporter
// ─────────────────────────────────────────────────────────────────────────────

/// Archives a generated Odoo module directory into a ZIP or TAR.GZ file
/// ready for deployment.
class ModuleExporter {
  static final Logger _log = Logger('ModuleExporter');

  /// Packages [modulePath] into an archive file at [outputFile].
  ///
  /// [format] defaults to [ExportFormat.zip].
  /// [outputFile] should include the extension (`.zip` or `.tar.gz`).
  Future<File> export(
    String modulePath, {
    required String outputFile,
    ExportFormat format = ExportFormat.zip,
  }) async {
    final sourceDir = Directory(modulePath);
    if (!sourceDir.existsSync()) {
      throw OutputPathException(modulePath);
    }

    _log.info('Exporting "$modulePath" → "$outputFile" (${format.name})…');

    final archive = Archive();
    final baseName = p.basename(modulePath);

    await for (final entity
        in sourceDir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;

      final relativePath = p.join(
        baseName,
        p.relative(entity.path, from: modulePath),
      );

      final bytes = await entity.readAsBytes();
      archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
    }

    final outFile = File(outputFile);
    await outFile.parent.create(recursive: true);

    final encoded = switch (format) {
      ExportFormat.zip => ZipEncoder().encode(archive),
      ExportFormat.tar => TarEncoder().encode(archive),
    };

    if (encoded == null) {
      throw GenerationException('Archive encoding returned null.');
    }

    await outFile.writeAsBytes(encoded);
    _log.info('✅ Exported ${archive.files.length} files → "$outputFile"');
    return outFile;
  }
}
