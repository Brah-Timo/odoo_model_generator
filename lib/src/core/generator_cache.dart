/// In-memory cache for generated file contents.
///
/// Prevents redundant regeneration when the same model is used across
/// multiple output targets (e.g. preview + write).
library odoo_model_generator.generator_cache;

// ─────────────────────────────────────────────────────────────────────────────
//  GeneratorCache
// ─────────────────────────────────────────────────────────────────────────────

/// Simple LRU-style cache for generated file contents.
///
/// Key: `'modelName::relativePath'`
/// Value: generated string content.
class GeneratorCache {
  final int maxEntries;
  final Map<String, String> _store = {};
  final List<String> _order = [];

  GeneratorCache({this.maxEntries = 128});

  // ── read ──────────────────────────────────────────────────────────────────

  /// Returns the cached content or `null` if not present.
  String? get(String modelName, String relativePath) =>
      _store['$modelName::$relativePath'];

  bool contains(String modelName, String relativePath) =>
      _store.containsKey('$modelName::$relativePath');

  // ── write ─────────────────────────────────────────────────────────────────

  /// Stores [content] under the composite key.
  void set(String modelName, String relativePath, String content) {
    final key = '$modelName::$relativePath';
    if (_store.containsKey(key)) {
      _store[key] = content;
      return;
    }

    // Evict oldest if at capacity
    if (_store.length >= maxEntries) {
      final oldest = _order.removeAt(0);
      _store.remove(oldest);
    }

    _store[key] = content;
    _order.add(key);
  }

  // ── management ────────────────────────────────────────────────────────────

  /// Invalidates all entries for [modelName].
  void invalidate(String modelName) {
    final keys = _store.keys
        .where((k) => k.startsWith('$modelName::'))
        .toList();
    for (final k in keys) {
      _store.remove(k);
      _order.remove(k);
    }
  }

  /// Clears the entire cache.
  void clear() {
    _store.clear();
    _order.clear();
  }

  /// Current number of cached entries.
  int get size => _store.length;
}
