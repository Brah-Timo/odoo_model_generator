# Advanced Usage

This document covers features beyond basic model generation: onchange/constraint/compute
stubs, SQL constraints, inheritance, parallel generation, module export, server actions,
caching, the Odoo CLI bridge, and dry-run pipelines.

---

## Table of contents

1. [Onchange stubs](#1-onchange-stubs)
2. [Constraint stubs](#2-constraint-stubs)
3. [Compute method bodies](#3-compute-method-bodies)
4. [SQL constraints](#4-sql-constraints)
5. [Model inheritance](#5-model-inheritance)
6. [Parallel generation](#6-parallel-generation)
7. [Module export (ZIP / TAR)](#7-module-export-zip--tar)
8. [Server actions](#8-server-actions)
9. [GeneratorCache](#9-generatorcache)
10. [OdooCLIIntegration](#10-odoocliintegration)
11. [Dry-run pipelines](#11-dry-run-pipelines)
12. [Custom GeneratorConfig](#12-custom-generatorconfig)
13. [Custom field extra kwargs](#13-custom-field-extra-kwargs)

---

## 1. Onchange stubs

Register `@api.onchange` Python method stubs that fire when listed fields change.

```dart
final model = OdooModel('x_sale_order')
  ..field(NameField())
  ..field(const Many2one('partner_id', relation: 'res.partner', onchange: true))
  ..field(const Many2one('pricelist_id', relation: 'product.pricelist'))
  ..onchange(OnchangeDefinition(
    triggerFields: ['partner_id'],
    methodName: '_onchange_partner_id',
    bodyLines: [
      "if self.partner_id:",
      "    self.pricelist_id = self.partner_id.property_product_pricelist",
    ],
  ));
```

The generator emits:

```python
@api.onchange('partner_id')
def _onchange_partner_id(self):
    if self.partner_id:
        self.pricelist_id = self.partner_id.property_product_pricelist
```

---

## 2. Constraint stubs

Register `@api.constrains` method stubs for validation logic.

```dart
model
  ..field(const Float('discount', required: true))
  ..constraint(ConstraintDefinition(
    constrainedFields: ['discount'],
    methodName: '_check_discount',
    errorMessage: 'Discount must be between 0 and 100.',
    bodyLines: [
      'for rec in self:',
      '    if not 0 <= rec.discount <= 100:',
      "        raise ValidationError(_('Discount must be between 0 and 100.'))",
    ],
  ));
```

Generated output:

```python
@api.constrains('discount')
def _check_discount(self):
    for rec in self:
        if not 0 <= rec.discount <= 100:
            raise ValidationError(_('Discount must be between 0 and 100.'))
```

---

## 3. Compute method bodies

Pair `ComputedField` with a `ComputeDefinition` to emit full `@api.depends` methods.

```dart
model
  ..field(const Float('price'))
  ..field(const Integer('quantity'))
  ..field(const ComputedField(
    'total',
    fieldType: 'Float',
    computeMethod: '_compute_total',
    store: true,
    depends: ['price', 'quantity'],
    digits: (10, 2),
  ))
  ..compute(ComputeDefinition(
    methodName: '_compute_total',
    dependsOn: ['price', 'quantity'],
    bodyLines: [
      'for rec in self:',
      '    rec.total = rec.price * rec.quantity',
    ],
  ));
```

Generated:

```python
@api.depends('price', 'quantity')
def _compute_total(self):
    for rec in self:
        rec.total = rec.price * rec.quantity
```

---

## 4. SQL constraints

Add database-level `UNIQUE` or `CHECK` constraints:

```dart
model
  ..field(const Char('code', required: true))
  ..sqlConstraint(
    'unique_code',
    'UNIQUE(code)',
    'The code must be unique per record.',
  )
  ..sqlConstraint(
    'check_code_length',
    "CHECK(char_length(code) >= 3)",
    'Code must be at least 3 characters.',
  );
```

Generated Python:

```python
_sql_constraints = [
    ('unique_code', 'UNIQUE(code)', 'The code must be unique per record.'),
    ('check_code_length', "CHECK(char_length(code) >= 3)", 'Code must be at least 3 characters.'),
]
```

---

## 5. Model inheritance

### Mixin inheritance (mail.thread, etc.)

```dart
final model = OdooModel('x_helpdesk_ticket')
  ..inherit('mail.thread')
  ..inherit('mail.activity.mixin')
  ..field(NameField())
  ..field(const Selection('state', ['open', 'closed']));
```

Generates:

```python
class XHelpdeskTicket(models.Model):
    _name = 'x_helpdesk_ticket'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    ...
```

### Extension of an existing model

```dart
final model = OdooModel('res.partner')
  ..inherit('res.partner', mode: InheritMode.extension)
  ..field(const Char('vat_number'));
```

Generates:

```python
class ResPartner(models.Model):
    _inherit = 'res.partner'
    vat_number = fields.Char(...)
```

---

## 6. Parallel generation

Generate multiple models concurrently using `ParallelGenerator`:

```dart
import 'package:odoo_model_generator/odoo_model_generator.dart';

Future<void> main() async {
  final models = [
    OdooModel('x_product')..field(NameField())..field(const Float('price')),
    OdooModel('x_category')..field(NameField()),
    OdooModel('x_supplier')..field(NameField())
      ..field(const Many2one('partner_id', relation: 'res.partner')),
  ];

  final generator = ParallelGenerator(
    config: const GeneratorConfig(author: 'Acme Corp'),
    concurrency: 2,   // run 2 at a time; null = unlimited
  );

  final result = await generator.generateAll(models, outputPath: './modules');

  print('✅ Successful: ${result.successful.length}');
  print('❌ Failed:     ${result.failed.length}');

  for (final f in result.failed) {
    print('  ${f.modelName}: ${f.error}');
  }
}
```

Each model is placed in `<outputPath>/<modelName>/`.

---

## 7. Module export (ZIP / TAR)

Package a generated module directory into an archive:

```dart
final exporter = ModuleExporter();

// ZIP
final zip = await exporter.export(
  './modules/x_product',
  outputFile: './dist/x_product.zip',
  format: ExportFormat.zip,
);
print('ZIP: ${zip.path}');

// TAR.GZ
final tar = await exporter.export(
  './modules/x_product',
  outputFile: './dist/x_product.tar.gz',
  format: ExportFormat.tar,
);
```

The archive preserves the module directory name as the top-level folder inside
the archive, which is required by Odoo's module loader.

---

## 8. Server actions

Attach `ir.actions.server` records and Python method stubs using the
`ServerActionExtension`:

```dart
import 'package:odoo_model_generator/odoo_model_generator.dart';

final model = OdooModel('x_task')
  ..field(NameField())
  ..field(const Selection('state', ['todo', 'done']))
  ..serverAction(ServerAction(
    name: 'Mark as Done',
    methodName: 'action_mark_done',
    binding: true,          // shows in the action menu
    multipleRecords: false, // calls ensure_one() in the stub
  ));
```

The `ViewTemplate` automatically includes `ServerAction.toXML()` in the generated
views XML, and `ModelTemplate` includes `ServerAction.toPython()` in the model file.

---

## 9. GeneratorCache

Avoid redundant regeneration for identical models within a single Dart session:

```dart
final cache = GeneratorCache();
final gen = OdooGenerator(model);

final key = cache.computeKey(model);
final Map<String, String> files;

if (cache.has(key)) {
  files = cache.get(key)!;
  print('Cache hit for ${model.modelName}');
} else {
  files = gen.dryRun();
  cache.put(key, files);
}
```

The cache key is a SHA-256 digest of the model's serialised configuration,
so structurally identical models always share the same key regardless of
when they were built.

---

## 10. OdooCLIIntegration

Programmatically install or upgrade modules on a local Odoo installation:

```dart
final cli = OdooCLIIntegration(
  odooBinPath: '/opt/odoo17/odoo-bin',
);

// Check whether odoo-bin is accessible
if (!await cli.isAvailable()) {
  throw StateError('odoo-bin not found');
}

// Install
final r = await cli.installOrUpgrade(
  'x_project_task',
  database: 'production',
  install: true,                       // false → upgrade (-u)
  configFile: '/etc/odoo/odoo.conf',
);
print('Exit code: ${r.exitCode}');
```

Throws `GenerationException` if `odoo-bin` exits with a non-zero code.

---

## 11. Dry-run pipelines

Use `OdooGenerator.dryRun()` to build custom pipelines — code review tools,
diff generators, CI checks — without filesystem side-effects:

```dart
final gen = OdooGenerator(model, config: const GeneratorConfig(
  author: 'CI Bot',
  generateSecurity: false,
));

final files = gen.dryRun();

for (final entry in files.entries) {
  print('${entry.key}:');
  print(entry.value);
  print('─' * 60);
}

// Validate that Python file contains the model class
final py = files.entries
    .firstWhere((MapEntry<String, String> e) => e.key.contains('models/'))
    .value;
assert(py.contains("_name = '${model.modelName}'"));
```

---

## 12. Custom `GeneratorConfig`

Override any generation defaults without subclassing:

```dart
const myConfig = GeneratorConfig(
  version: '3.0.0',
  author: 'Acme Inc.',
  website: 'https://acme.com',
  license: 'OPL-1',
  category: 'Manufacturing',
  isApplication: true,
  generateSecurity: true,
  generateDemoStub: true,
  extraDependencies: ['manufacture', 'mrp'],
);

await model.generate(outputPath: './output', config: myConfig);
```

Use `copyWith(…)` to create variants:

```dart
final devConfig = myConfig.copyWith(generateDemoStub: true, version: '0.0.1');
final prodConfig = myConfig.copyWith(version: '3.0.0');
```

---

## 13. Custom field extra kwargs

Append arbitrary Python kwargs to any field declaration using the `extra` map:

```dart
const Char(
  'name',
  extra: {
    'index': 'True',
    'copy': 'False',
    'tracking': '1',
  },
)
```

This produces:

```python
name = fields.Char(string='Name', required=True, index=True, copy=False, tracking=1)
```

`extra` kwargs are appended after all standard kwargs and before the closing
parenthesis.
