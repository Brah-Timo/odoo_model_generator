# API Reference

Full reference for every public class and function exported from
`package:odoo_model_generator/odoo_model_generator.dart`.

---

## `OdooModel`

The primary fluent builder.  Creates one Odoo custom model and drives
the full generation pipeline.

```dart
final model = OdooModel(
  'x_invoice_system',
  docstring: 'Custom Invoice',
  stringField: 'name',       // field used as _rec_name
  createTimestamp: true,     // shadow create_date / write_date fields
  createSequence: false,     // add a sequence integer field
  order: 'create_date desc', // Python _order value
);
```

### Constructor parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `modelName` | `String` | required | Odoo `_name`, e.g. `'x_product_custom'`. Must start with `x_` and be lowercase snake_case. |
| `docstring` | `String?` | `null` | `_description` string in the generated Python class. |
| `stringField` | `String` | `'name'` | Field used as `_rec_name`. Must match one of the declared fields. |
| `createTimestamp` | `bool` | `true` | Whether to render shadow `create_date`/`write_date` fields. |
| `createSequence` | `bool` | `false` | Whether to add a `sequence` integer field and auto-increment in `create()`. |
| `order` | `String?` | `null` | `_order` class attribute, e.g. `'name asc'`. |

### Fluent builder methods

All builder methods return `this` so calls can be chained with `..` cascade notation.

#### `.field(OdooField fieldDef) → OdooModel`

Adds a field to the model.

```dart
model
  ..field(NameField())
  ..field(const Float('price', required: true))
  ..field(const Many2one('supplier_id', relation: 'res.partner'));
```

Throws `DuplicateFieldException` if the same field name is added twice.  
Throws `ReservedFieldException` if the name is in `kReservedOdooFieldNames`.

---

#### `.inherit(String parentModel, {InheritMode mode}) → OdooModel`

Adds a mixin parent (e.g. `mail.thread`) or marks the model as an extension.

```dart
model
  ..inherit('mail.thread')
  ..inherit('mail.activity.mixin');
```

| Parameter | Type | Default |
|-----------|------|---------|
| `parentModel` | `String` | required |
| `mode` | `InheritMode` | `InheritMode.mixin` |

`InheritMode.mixin` → `_inherit = ['mail.thread', …]`  
`InheritMode.extension` → `_inherit = 'res.partner'` (no `_name`)

---

#### `.dependency(String moduleName) → OdooModel`

Adds an Odoo module dependency (deduplicated automatically).

```dart
model
  ..dependency('sale')
  ..dependency('stock');
```

---

#### `.onchange(OnchangeDefinition definition) → OdooModel`

Registers an `@api.onchange` method stub.

```dart
model.onchange(OnchangeDefinition(
  triggerFields: ['partner_id'],
  methodName: '_onchange_partner_id',
  bodyLines: ["self.address = self.partner_id.street or ''"],
));
```

---

#### `.constraint(ConstraintDefinition definition) → OdooModel`

Registers an `@api.constrains` method stub.

```dart
model.constraint(ConstraintDefinition(
  constrainedFields: ['price'],
  methodName: '_check_price',
  errorMessage: 'Price must be positive.',
));
```

---

#### `.compute(ComputeDefinition definition) → OdooModel`

Registers the body for a `@api.depends` compute method (paired with a `ComputedField`).

```dart
model.compute(ComputeDefinition(
  methodName: '_compute_total',
  dependsOn: ['price', 'quantity'],
  bodyLines: ['for rec in self:', '    rec.total = rec.price * rec.quantity'],
));
```

---

#### `.sqlConstraint(String id, String expression, String message) → OdooModel`

Adds a PostgreSQL-level SQL constraint.

```dart
model.sqlConstraint(
  'unique_code',
  'UNIQUE(code)',
  'Code must be unique.',
);
```

---

#### `Future<GenerationResult> generate({String outputPath, GeneratorConfig config})`

Validates the model and writes all output files to disk.

```dart
final result = await model.generate(
  outputPath: './my_module',
  config: const GeneratorConfig(author: 'Acme Corp', version: '2.0.0'),
);
print(result.writtenFiles); // list of absolute paths
```

---

## `OdooGenerator`

Advanced orchestration layer for custom generation pipelines.  For everyday
use, call `model.generate()` instead.

```dart
final gen = OdooGenerator(
  model,
  outputPath: './my_module',
  config: const GeneratorConfig(),
);

// Dry run — returns Map<relativePath, content> without writing
final files = gen.dryRun();

// Full generation — delegates to model.generate()
final result = await gen.generate();
```

### `Map<String, String> dryRun()`

Validates the model and returns the would-be file contents as a map of
`relativePath → content` without touching the filesystem.

```dart
final files = gen.dryRun();
files.forEach((path, content) => print('$path: ${content.length} chars'));
```

---

## `GeneratorConfig`

Immutable value object controlling generation behaviour.

```dart
const GeneratorConfig(
  version: '1.0.0',
  author: 'Your Company',
  website: 'https://yourcompany.com',
  license: 'LGPL-3',
  category: 'Custom',
  isApplication: false,
  openFolder: false,
  generateModelsInit: true,
  generateSecurity: true,
  generateDemoStub: false,
  extraDependencies: ['sale', 'stock'],
)
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `version` | `String` | `'1.0.0'` | SemVer module version in `__manifest__.py`. |
| `author` | `String` | `'Your Company'` | Author name in `__manifest__.py`. |
| `website` | `String` | `'https://yourcompany.com'` | Author website. |
| `license` | `String` | `'LGPL-3'` | License identifier (`LGPL-3`, `OPL-1`, etc.). |
| `category` | `String` | `'Custom'` | App Store category. |
| `isApplication` | `bool` | `false` | Marks the module as an App. |
| `openFolder` | `bool` | `false` | Auto-opens the output folder after generation (macOS/Linux/Windows). |
| `generateModelsInit` | `bool` | `true` | Generates `models/__init__.py`. |
| `generateSecurity` | `bool` | `true` | Generates `security/ir.model.access.csv`. |
| `generateDemoStub` | `bool` | `false` | Generates an empty `data/demo.xml` stub. |
| `extraDependencies` | `List<String>` | `[]` | Additional Odoo modules appended to the manifest `depends` list. |

Use `copyWith(…)` to produce a modified copy:

```dart
final prodConfig = defaultConfig.copyWith(version: '2.0.0', author: 'Acme');
```

---

## `GenerationResult`

Immutable value object returned by `model.generate()` and `OdooGenerator.generate()`.

| Property | Type | Description |
|----------|------|-------------|
| `modelName` | `String` | The Odoo model name (`_name`). |
| `outputPath` | `String` | Absolute path to the output directory. |
| `writtenFiles` | `List<String>` | Absolute paths of every written file. |

---

## `ParallelGenerator`

Generates multiple `OdooModel`s concurrently.  Individual failures do **not**
abort sibling tasks.

```dart
final pg = ParallelGenerator(
  config: const GeneratorConfig(author: 'Acme'),
  concurrency: 4,   // null = no limit
);

final result = await pg.generateAll(
  [modelA, modelB, modelC],
  outputPath: './modules',
);

print('Success: ${result.successful.length}');
print('Failed:  ${result.failed.length}');
print('Total files: ${result.totalFiles}');

for (final f in result.failed) {
  print('${f.modelName}: ${f.error}');
}
```

### `ParallelGenerationResult`

| Property | Type | Description |
|----------|------|-------------|
| `successful` | `List<GenerationResult>` | Results for models that completed successfully. |
| `failed` | `List<({modelName, error, stackTrace})>` | Records for failed models. |
| `hasErrors` | `bool` | `true` if any model failed. |
| `totalFiles` | `int` | Sum of all written files across successful models. |

---

## `ModuleExporter`

Archives a generated module directory into a ZIP or TAR.GZ file.

```dart
final exporter = ModuleExporter();
final archive = await exporter.export(
  './my_module',
  outputFile: './my_module.zip',
  format: ExportFormat.zip,    // or ExportFormat.tar
);
print('Archive: ${archive.path}');
```

### `ExportFormat`

```dart
enum ExportFormat { zip, tar }
```

---

## `Validators`

Static validation helpers.  All methods throw the appropriate exception on
failure; they return normally on success.

```dart
Validators.modelName('x_product_custom'); // throws ValidationException if invalid
Validators.fieldName('name');
Validators.selectionOptions(<String>['draft', 'confirmed']);
Validators.fullModel(
  name: 'x_task',
  stringField: 'name',
  fields: model.fields,
  dependencies: model.dependencies,
);
```

### Static methods

| Method | Throws | Description |
|--------|--------|-------------|
| `modelName(String name)` | `ValidationException` | Name must start with `x_`, be lowercase, contain only `a-z`, `0-9`, `_`, and dots. |
| `fieldName(String name)` | `ValidationException`, `ReservedFieldException` | Name must be lowercase snake_case and not reserved. |
| `selectionOptions(List<String> options)` | `ValidationException` | List must be non-empty; options must be non-empty strings. |
| `fullModel({name, stringField, fields, dependencies})` | `ValidationException`, `DuplicateFieldException` | Runs all validations including `_rec_name` field presence check. |

---

## Exceptions

All exceptions extend `GeneratorException`.

| Class | When thrown |
|-------|-------------|
| `GeneratorException` | Base class for all package exceptions. |
| `ValidationException` | Model name, field name, or selection options failed validation. |
| `ReservedFieldException` | A field with a reserved Odoo name was declared. |
| `DuplicateFieldException` | A field name was added more than once. |
| `GenerationException` | A filesystem or pipeline error occurred during generation. |
| `OutputPathException` | The output directory cannot be created or accessed. |

---

## `NamingConventions`

Utilities for converting between Odoo naming styles.

```dart
NamingConventions.toLabel('x_product_custom');  // → 'X Product Custom'
NamingConventions.viewFileName('x_task');        // → 'x_task_view.xml'
NamingConventions.modelRefId('x_task');          // → 'model_x_task'
NamingConventions.accessId('x_task');            // → 'access_x_task'
```

---

## `StringUtils`

Low-level string helpers.

```dart
StringUtils.escapeSingle("it's");  // → "it\\'s"
StringUtils.toCamelCase('x_task'); // → 'XTask'
StringUtils.toSnakeCase('XTask');  // → 'x_task'
```

---

## `CodeFormatter`

Static helpers that validate formatting of generated code.

```dart
CodeFormatter.formatPython('    x = 1\n');  // returns formatted Python string
CodeFormatter.formatXml('<field name="x"/>'); // returns formatted XML string
```

---

## Template classes (public surface)

These classes are exported for advanced use-cases such as custom rendering
pipelines, documentation generation, or interactive previews.

| Class | Description |
|-------|-------------|
| `ModelTemplate` | Renders the Python model class body. |
| `ManifestTemplate` | Renders `__manifest__.py`. |
| `ViewTemplate` | Renders the combined views XML file. |
| `FieldTemplates` | Per-field rendering helpers (summary rows, Markdown tables, Python/XML previews, type mapping). |
| `PythonGenerator` | Orchestrates Python file generation for one model. |
| `XmlGenerator` | Orchestrates XML view generation for one model. |

---

## `ServerAction` & `ServerActionExtension`

Attach `ir.actions.server` records and Python method stubs to a model.

```dart
model.serverAction(ServerAction(
  name: 'Send Confirmation Email',
  methodName: 'action_send_email',
  binding: true,         // appears in tree-view action menu
  multipleRecords: true, // can run on a recordset
));
```

`ServerAction.toXML(modelName)` renders the `<record>` element.  
`ServerAction.toPython()` renders the Python method stub.

---

## `OdooCLIIntegration`

Bridges generated modules with a local Odoo installation.

```dart
final cli = OdooCLIIntegration(odooBinPath: '/opt/odoo/odoo-bin');

// Install
await cli.installOrUpgrade('my_module', database: 'mydb', install: true);

// Upgrade
await cli.installOrUpgrade('my_module', database: 'mydb', install: false);

// Check availability
final available = await cli.isAvailable();
```

---

## `GenerationReport`

Produces a formatted ASCII report table for a generation run.

```dart
final report = GenerationReport(
  modelName: result.modelName,
  outputPath: result.outputPath,
  writtenFiles: result.writtenFiles,
  elapsed: stopwatch.elapsed,
);
print(report.render());
```

---

## `GeneratorCache`

Simple in-memory content-addressable cache that avoids re-generating
identical models within a session.

```dart
final cache = GeneratorCache();

final key = cache.computeKey(model);
if (cache.has(key)) {
  final files = cache.get(key)!;
} else {
  final files = generator.dryRun();
  cache.put(key, files);
}
```

| Method | Description |
|--------|-------------|
| `computeKey(OdooModel)` | Returns a deterministic SHA-256 digest of the model's configuration. |
| `has(String key)` | Returns `true` if the key is cached. |
| `get(String key)` | Returns the cached file map, or `null`. |
| `put(String key, Map<String, String> files)` | Stores a file map under the key. |
| `invalidate(String key)` | Removes one entry. |
| `clear()` | Clears the entire cache. |
