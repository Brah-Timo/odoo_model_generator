/// File-system abstraction for writing generated module files.
library odoo_model_generator.file_handler;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/exceptions.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Standard Odoo module sub-directories
// ─────────────────────────────────────────────────────────────────────────────

const List<String> _kModuleDirs = [
  'models',
  'views',
  'security',
  'data',
  'static/description',
  'wizards',
  'reports',
  'controllers',
];

// ─────────────────────────────────────────────────────────────────────────────
//  FileHandler
// ─────────────────────────────────────────────────────────────────────────────

/// Manages all file-system I/O for a single generation run.
///
/// [basePath] is the root directory of the module being generated.
/// Every path passed to public methods is treated as relative to [basePath].
class FileHandler {
  final String basePath;

  FileHandler(this.basePath);

  // ── directory setup ───────────────────────────────────────────────────────

  /// Creates the standard Odoo module directory tree under [basePath].
  Future<void> createModuleStructure(String modelName) async {
    // Module root
    await _mkdirp(basePath);

    for (final sub in _kModuleDirs) {
      await _mkdirp(p.join(basePath, sub));
    }
  }

  // ── file writing ──────────────────────────────────────────────────────────

  /// Writes [content] to [relativePath] (relative to [basePath]).
  ///
  /// Parent directories are created automatically.
  /// Throws [OutputPathException] if write fails.
  Future<void> writeFile(String relativePath, String content) async {
    final full = p.join(basePath, relativePath);
    try {
      final file = File(full);
      await file.parent.create(recursive: true);
      await file.writeAsString(content, flush: true);
    } on FileSystemException {
      throw OutputPathException(full);
    }
  }

  /// Returns the resolved absolute path for [relativePath].
  String resolve(String relativePath) => p.join(basePath, relativePath);

  // ── helpers ───────────────────────────────────────────────────────────────

  Future<void> _mkdirp(String path) async {
    try {
      await Directory(path).create(recursive: true);
    } on FileSystemException {
      throw OutputPathException(path);
    }
  }
}
