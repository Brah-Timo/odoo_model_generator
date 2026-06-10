# odoo_model_generator

[![pub version](https://img.shields.io/pub/v/odoo_model_generator.svg)](https://pub.dev/packages/odoo_model_generator)
[![Dart SDK](https://img.shields.io/badge/Dart-%3E%3D3.0.0-blue)](https://dart.dev)
[![License](https://img.shields.io/badge/license-Commercial-red)](LICENSE)
[![Test Coverage](https://img.shields.io/badge/coverage-%3E95%25-brightgreen)]()

> **Ultra-pro Dart package** for automating Odoo module generation.  
> Turn a clean Dart API into production-ready `models.py`, `__manifest__.py`,
> `views.xml`, and `security/ir.model.access.csv` — in milliseconds.

---

<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/6da61dfe-1abe-4a92-b795-1124e0aa815d" />



## Table of Contents

1. [Why odoo_model_generator?](#why)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [API Reference](#api-reference)
   - [OdooModel](#odoomodel)
   - [Field Types](#field-types)
   - [GeneratorConfig](#generatorconfig)
   - [OdooGenerator (dry-run)](#oodogenerator--dry-run)
   - [ParallelGenerator](#parallelgenerator)
   - [ModuleExporter](#moduleexporter)
   - [Advanced Features](#advanced-features)
5. [CLI Tool (oomg)](#cli-tool-oomg)
6. [Generated File Structure](#generated-file-structure)
7. [Examples](#examples)
8. [Testing](#testing)
9. [Licensing & Pricing](#licensing--pricing)
10. [Support](#support)

---

## Why?

Every Odoo Partner repeats the same tedious cycle for every custom module:

1. Write `models.py` field by field — `Char`, `Many2one`, `Selection`…
2. Create `__manifest__.py` with correct dependencies
3. Build form/tree/search views in XML
4. Add security CSV rows
5. Wire everything up with `__init__.py`

**odoo_model_generator automates 100% of steps 1–5.**

| Metric | Without | With |
|--------|---------|------|
| Simple 10-field model | ~2 hours | **< 1 minute** |
| Complex 30-field model | ~1 day | **< 5 minutes** |
| Human error rate | High | **Zero (validated)** |

---

## Installation

Add to `pubspec.yaml`:

```yaml
dependencies:
  odoo_model_generator: ^2.0.0
```

```bash
dart pub get
```

For CLI usage, activate globally:

```bash
dart pub global activate odoo_model_generator
oomg version
```

---

## Quick Start

```dart
import 'package:odoo_model_generator/odoo_model_generator.dart';

Future<void> main() async {
  await OdooModel('x_product_custom')
      .field(const NameField())
      .field(const Many2one('supplier_id', relation: 'res.partner'))
      .field(const Float('price', digits: (10, 2)))
      .field(const Integer('quantity'))
      .field(const Text('description'))
      .generate(outputPath: './my_module');
}
```

This generates:

```
my_module/
├── __init__.py
├── __manifest__.py
├── models/
│   ├── __init__.py
│   └── x_product_custom.py
├── views/
│   └── x_product_custom_view.xml
├── security/
│   └── ir.model.access.csv
├── data/
├── static/
│   └── description/
├── wizards/
├── reports/
└── controllers/
```

---

## API Reference

### OdooModel

The primary fluent builder. All methods return `this` for chaining.

```dart
OdooModel(
  String modelName,          // e.g. 'x_invoice_system'
  {
    String? docstring,       // _description
    String stringField,      // _rec_name (default: 'name')
    bool createTimestamp,    // add shadow timestamp fields
    bool createSequence,     // add sequence integer + auto-assign
    String? order,           // _order value
  }
)
```

| Method | Description |
|--------|-------------|
| `.field(OdooField)` | Add a field |
| `.inherit(String)` | Add a mixin parent (`mail.thread`, etc.) |
| `.dependency(String)` | Add a module dependency |
| `.onchange(OnchangeDefinition)` | Register an onchange stub |
| `.constraint(ConstraintDefinition)` | Register a Python constraint |
| `.compute(ComputeDefinition)` | Register a compute method body |
| `.sqlConstraint(id, expr, msg)` | Add a `_sql_constraints` entry |
| `.generate(...)` | Validate and write all files |

---

### Field Types

| Dart class | Odoo Python type | Notes |
|-----------|-----------------|-------|
| `NameField()` | `fields.Char` | `required=True`, convenience shortcut |
| `Char(name)` | `fields.Char` | `size`, `translate` options |
| `Text(name)` | `fields.Text` | Renders `nolabel="1"` in form |
| `Html(name)` | `fields.Html` | `sanitize` option |
| `Integer(name)` | `fields.Integer` | |
| `Float(name)` | `fields.Float` | `digits: (10, 2)` |
| `Monetary(name)` | `fields.Monetary` | `currencyField` option |
| `Boolean(name)` | `fields.Boolean` | |
| `Date(name)` | `fields.Date` | |
| `Datetime(name)` | `fields.Datetime` | |
| `Binary(name)` | `fields.Binary` | `attachment` option |
| `Image(name)` | `fields.Image` | `maxWidth`, `maxHeight` |
| `Selection(name, options)` | `fields.Selection` | `rawOptions` for custom labels |
| `Many2one(name, relation: ...)` | `fields.Many2one` | `ondelete`, `domain`, `onchange` |
| `One2many(name, relation: ..., inverseField: ...)` | `fields.One2many` | |
| `Many2many(name, relation: ...)` | `fields.Many2many` | `relationTable`, `column1/2` |
| `ComputedField(name, computeMethod: ...)` | Any computed field | `store`, `depends`, `fieldType` |
| `Reference(name, allowedModels: [...])` | `fields.Reference` | |

All fields accept:

```dart
const MyField(
  'field_name',
  string: 'Human Label',       // optional, auto-generated if omitted
  required: true,
  defaultValue: 'default',
  help: 'Tooltip text',
  inTree: true,                // appear in tree view
  inSearch: true,              // appear in search view
  readonly: false,
  cssClass: 'oe_inline',
  extra: {'tracking': '1'},    // arbitrary extra Python kwargs
)
```

---

### GeneratorConfig

```dart
const GeneratorConfig({
  String version = '1.0.0',
  String author = 'Your Company',
  String website = 'https://yourcompany.com',
  String license = 'LGPL-3',
  String category = 'Custom',
  bool isApplication = false,
  bool openFolder = false,
  bool generateModelsInit = true,
  bool generateSecurity = true,
  bool generateDemoStub = false,
  List<String> extraDependencies = const [],
})
```

---

### OdooGenerator — Dry Run

Preview the generated content WITHOUT writing to disk:

```dart
final gen = OdooGenerator(model);
final files = gen.dryRun();  // Map<String, String>

for (final entry in files.entries) {
  print('${entry.key}:\n${entry.value}\n');
}
```

---

### ParallelGenerator

Generate multiple models concurrently:

```dart
final result = await ParallelGenerator(
  config: config,
  concurrency: 4,        // max simultaneous tasks; null = unlimited
).generateAll(
  [model1, model2, model3],
  outputPath: './output',
);

print('Generated: ${result.successful.length}');
print('Failed   : ${result.failed.length}');
print('Files    : ${result.totalFiles}');
```

---

### ModuleExporter

Package a generated module directory into a ZIP or TAR archive:

```dart
final exporter = ModuleExporter();

await exporter.export(
  './output/x_my_module',
  outputFile: './dist/x_my_module_v16.zip',
  format: ExportFormat.zip,  // or ExportFormat.tar
);
```

---

### Advanced Features

#### Computed fields with method bodies

```dart
OdooModel('x_order')
  .field(const Float('price'))
  .field(const Integer('qty'))
  .field(const ComputedField(
    'total',
    computeMethod: '_compute_total',
    store: true,
    depends: ['price', 'qty'],
    fieldType: 'Float',
    digits: (14, 2),
  ))
  .compute(const ComputeDefinition(
    methodName: '_compute_total',
    dependsOn: ['price', 'qty'],
    bodyLines: [
      'for record in self:',
      '    record.total = record.price * record.qty',
    ],
  ))
```

#### Onchange methods

```dart
  .onchange(const OnchangeDefinition(
    triggerFields: ['partner_id'],
    methodName: '_onchange_partner_id',
    bodyLines: [
      'if self.partner_id:',
      '    self.currency_id = self.partner_id.property_purchase_currency_id',
    ],
  ))
```

#### Python constraints

```dart
  .constraint(const ConstraintDefinition(
    constrainedFields: ['amount'],
    methodName: '_check_amount_positive',
    errorMessage: 'Amount must be positive',
    bodyLines: [
      'for r in self:',
      '    if r.amount <= 0:',
      '        raise ValidationError("Amount must be positive")',
    ],
  ))
```

#### SQL constraints

```dart
  .sqlConstraint(
    'unique_code_company',
    'UNIQUE(code, company_id)',
    'Code must be unique per company',
  )
```

---

## CLI Tool (oomg)

```
Usage: oomg <command> [options]

Commands:
  generate   Generate a full Odoo module
  validate   Validate a model without generating files
  dry-run    Preview generated content (no files written)
  export     Package a module directory into a ZIP archive
  version    Print version

Options for generate / dry-run:
  -s, --schema     Path to JSON schema file
  -m, --model      Odoo model name (e.g. x_product_custom)
  -o, --output     Output directory (default: ./generated)
      --open       Open the output folder after generation
  -v, --verbose    Verbose logging
      --author     Author name in manifest
      --version    Module version
      --license    License identifier
      --no-security  Skip ir.model.access.csv
      --demo         Generate data/demo.xml stub
```

### JSON Schema format

```json
{
  "modelName": "x_product_custom",
  "docstring": "Custom Product",
  "stringField": "name",
  "dependencies": ["sale", "stock"],
  "inherits": ["mail.thread"],
  "fields": [
    { "type": "Char",     "name": "name",        "required": true, "inTree": true },
    { "type": "Float",    "name": "price",        "digits": [10, 2] },
    { "type": "Integer",  "name": "quantity",     "inTree": true },
    { "type": "Many2one", "name": "supplier_id",  "relation": "res.partner" },
    { "type": "Selection","name": "state",
      "options": ["draft", "confirmed", "done"], "defaultValue": "draft" }
  ]
}
```

```bash
# Generate from schema
oomg generate --schema product.json --output ./modules/x_product

# Quick dry-run preview
oomg dry-run --model x_test_model --file models

# Validate only
oomg validate --schema product.json

# Export to ZIP
oomg export --module ./modules/x_product --zip ./dist/product.zip
```

---

## Generated File Structure

```
<output_path>/
├── __init__.py                          # from . import models
├── __manifest__.py                      # Module metadata & dependencies
├── models/
│   ├── __init__.py                      # from . import <model_name>
│   └── <model_name>.py                  # Class definition + fields + methods
├── views/
│   └── <model_name>_view.xml            # Form + Tree + Search + Action + Menu
├── security/
│   └── ir.model.access.csv              # User + Manager access rows
├── data/
│   └── demo.xml                         # (optional) demo data stub
├── static/description/
├── wizards/
├── reports/
└── controllers/
```

---

## Examples

| File | Description |
|------|-------------|
| `example/simple_model.dart` | Minimal 5-field model |
| `example/complex_model.dart` | Full invoice model with all features |
| `example/with_parallel.dart` | 5-model ERP suite in parallel |
| `example/dry_run_preview.dart` | Preview without writing files |
| `example/with_export.dart` | Generate + export to ZIP |

---

## Testing

```bash
# Run all tests
dart test

# Run with coverage
dart test --coverage=coverage
dart pub global run coverage:format_coverage \
  --lcov --in=coverage --out=coverage/lcov.info --report-on=lib

# Run a specific test file
dart test test/integration_test.dart -v
```

Test coverage target: **> 95%**

---

## Licensing & Pricing

| Plan | Price | Seats | Support |
|------|-------|-------|---------|
| **Developer** | $500 / company | 1 developer | Email |
| **Team** | $1,000 / company | 5 developers | Priority email |
| **Enterprise** | Custom | Unlimited | 24/7 dedicated |
| **Trial** | Free | 1 developer | Community |

> The trial is limited to models with ≤ 5 fields.


---

## Support

- 🐛 Issues: github.com/Brah-Timo/odoo_model_generator/issues

---

*Generated by TIMSoftDZ odoo_model_generator v2.0.0 — © 2026 Odoo Generator LLC. All rights reserved.*
