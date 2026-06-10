# Getting Started

`odoo_model_generator` (OOMG) is a Dart package that generates complete,
production-ready Odoo 16/17 modules from a concise fluent Dart API.  
One call produces `__init__.py`, `models/<name>.py`, `__manifest__.py`,
`views/<name>_view.xml`, and `security/ir.model.access.csv`.

---

## Requirements

| Tool | Minimum version |
|------|----------------|
| Dart SDK | 3.0.0 |
| Odoo | 16.0 or 17.0 |

---

## Installation

### As a library dependency

Add to your `pubspec.yaml`:

```yaml
dependencies:
  odoo_model_generator: ^2.0.0
```

Then fetch packages:

```bash
dart pub get
```

### As a global CLI tool

```bash
dart pub global activate odoo_model_generator
```

This makes the `oomg` executable available on your `PATH`.

---

## Your first module in 30 seconds

```dart
import 'package:odoo_model_generator/odoo_model_generator.dart';

Future<void> main() async {
  final model = OdooModel('x_product_custom', docstring: 'Custom Product')
    ..field(NameField())
    ..field(const Float('price', required: true, inTree: true))
    ..field(const Many2one('supplier_id', relation: 'res.partner', inTree: true))
    ..field(const Text('description'));

  final result = await model.generate(outputPath: './my_module');
  print('Generated ${result.writtenFiles.length} files → ${result.outputPath}');
}
```

Run it:

```bash
dart run your_script.dart
```

This writes the following files to `./my_module/`:

```
my_module/
├── __init__.py
├── __manifest__.py
├── models/
│   ├── __init__.py
│   └── x_product_custom.py
├── views/
│   └── x_product_custom_view.xml
└── security/
    └── ir.model.access.csv
```

---

## Using the CLI

The `oomg` binary provides five commands.  See [CLI Reference](cli_reference.md) for
full details.

### Quick example — generate from a model name

```bash
oomg generate --model x_product_custom --output ./my_module
```

### Quick example — dry run (preview without writing)

```bash
oomg dry-run --model x_product_custom
```

### Quick example — generate from a JSON schema

```bash
oomg generate --schema schema.json --output ./my_module
```

---

## Minimal JSON schema

```json
{
  "modelName": "x_product_custom",
  "docstring": "Custom Product",
  "dependencies": ["sale"],
  "fields": [
    { "type": "Char",    "name": "name",        "required": true },
    { "type": "Float",   "name": "price" },
    { "type": "Many2one","name": "supplier_id", "relation": "res.partner" }
  ]
}
```

---

## Next steps

| Topic | Document |
|-------|---------|
| All field types and their options | [Field Types](field_types.md) |
| Full API reference | [API Reference](api_reference.md) |
| CLI commands and flags | [CLI Reference](cli_reference.md) |
| Advanced features | [Advanced Usage](advanced_usage.md) |
| Package internals | [Architecture](architecture.md) |
