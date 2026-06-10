/// Naming-convention helpers used throughout code generation.
library odoo_model_generator.naming_conventions;

/// Centralises all naming transformations so every generator uses
/// the same rules.
abstract final class NamingConventions {
  NamingConventions._();

  // ── Python class name ─────────────────────────────────────────────────────

  /// Converts an Odoo model name (`x_product_custom`) to a Python class name
  /// (`XProductCustom`).
  static String toPythonClass(String modelName) {
    return modelName
        .split('.')
        .expand((part) => part.split('_'))
        .map(_capitalize)
        .join();
  }

  // ── Human label ───────────────────────────────────────────────────────────

  /// Converts `x_product_custom` or `invoice_date` to `X Product Custom` /
  /// `Invoice Date`.
  static String toLabel(String identifier) {
    return identifier
        .split(RegExp(r'[._]'))
        .map(_capitalize)
        .join(' ');
  }

  // ── XML / view IDs ────────────────────────────────────────────────────────

  /// `x_product_custom` → `view_form_x_product_custom`
  static String formViewId(String modelName) => 'view_form_$modelName';

  /// `x_product_custom` → `view_tree_x_product_custom`
  static String treeViewId(String modelName) => 'view_tree_$modelName';

  /// `x_product_custom` → `view_search_x_product_custom`
  static String searchViewId(String modelName) => 'view_search_$modelName';

  /// `x_product_custom` → `action_x_product_custom`
  static String actionId(String modelName) => 'action_$modelName';

  /// `x_product_custom` → `menu_x_product_custom`
  static String menuId(String modelName) => 'menu_$modelName';

  // ── security CSV IDs ──────────────────────────────────────────────────────

  /// `x_product_custom` → `access_x_product_custom`
  static String accessId(String modelName) => 'access_$modelName';

  /// `x_product_custom` → `model_x_product_custom` (used as `model_id:id`)
  static String modelRefId(String modelName) =>
      'model_${modelName.replaceAll('.', '_')}';

  // ── file paths ────────────────────────────────────────────────────────────

  /// `x_product_custom` → `x_product_custom_view.xml`
  static String viewFileName(String modelName) => '${modelName}_view.xml';

  // ── helpers ───────────────────────────────────────────────────────────────

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}
