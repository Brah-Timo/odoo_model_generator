# Architecture

This document describes the internal structure of the `odoo_model_generator`
package: how files are organised, how the generation pipeline flows, and how
the main components interact.

---

## Package layout

```
odoo_model_generator/
├── bin/
│   └── oomg.dart               # CLI entry point (CommandRunner)
├── lib/
│   ├── odoo_model_generator.dart  # Public barrel export
│   └── src/
│       ├── core/
│       │   ├── exceptions.dart     # Exception hierarchy
│       │   ├── field_types.dart    # OdooField + all concrete field classes
│       │   ├── generator.dart      # OdooGenerator (thin orchestration layer)
│       │   ├── generator_cache.dart # SHA-256 in-memory cache
│       │   ├── model_builder.dart  # OdooModel (fluent builder) + value objects
│       │   └── validators.dart     # Validators (static methods)
│       ├── codegen/
│       │   ├── formatter.dart      # CodeFormatter (static helpers)
│       │   ├── python_generator.dart # PythonGenerator
│       │   └── xml_generator.dart  # XmlGenerator
│       ├── templates/
│       │   ├── field_templates.dart  # FieldTemplates (preview / docs helpers)
│       │   ├── manifest_template.dart # ManifestTemplate
│       │   ├── model_template.dart    # ModelTemplate
│       │   └── view_template.dart    # ViewTemplate
│       ├── utils/
│       │   ├── file_handler.dart    # FileHandler (filesystem I/O)
│       │   ├── naming_conventions.dart # NamingConventions
│       │   └── string_utils.dart    # StringUtils
│       ├── advanced.dart        # ServerAction, OdooCLIIntegration, GenerationReport
│       ├── module_exporter.dart # ModuleExporter (ZIP / TAR)
│       └── parallel_generator.dart # ParallelGenerator
├── examples/
│   ├── simple_model.dart
│   ├── complex_model.dart
│   ├── dry_run_preview.dart
│   ├── with_export.dart
│   └── with_parallel.dart
├── test/
│   ├── core_test.dart
│   ├── generator_test.dart
│   ├── integration_test.dart
│   └── validators_test.dart
├── doc/                        # ← documentation (this folder)
├── analysis_options.yaml       # Strict Dart analysis config
└── pubspec.yaml
```

---

## Dependency graph

```
     ┌──────────────────────────────────────────────────────┐
     │                   Public API surface                   │
     │          lib/odoo_model_generator.dart (barrel)        │
     └──────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼────────────────────┐
          ▼                   ▼                    ▼
   core/model_builder    parallel_generator   module_exporter
   core/generator         (uses model_builder)  (uses exceptions)
          │
    ┌─────┴──────┐
    ▼            ▼
 codegen/     templates/
 python_gen   model_template
 xml_gen      manifest_template
    │         view_template
    └──────────┤
               ▼
           utils/
           file_handler
           naming_conventions
           string_utils
```

All `package:` dependencies (`args`, `logging`, `meta`, `archive`, `path`,
`dart_style`, `collection`, `crypto`, etc.) are confined to the leaf modules
that actually use them, keeping the public API surface dependency-free.

---

## Generation pipeline

### Step 1 — Build the model

The user constructs an `OdooModel` using the fluent builder API.  No I/O
occurs at this stage.  All data is held in plain Dart lists and maps.

```
OdooModel('x_task')
  ..field(NameField())
  ..field(const Float('hours'))
  ..dependency('project')
```

### Step 2 — Validate

When `model.generate()` (or `OdooGenerator.dryRun()`) is called, `Validators.fullModel()`
runs synchronously before any file I/O:

- Model name format (`x_` prefix, snake_case, dot-separated segments)
- Field names (lowercase, no reserved names, no duplicates)
- `_rec_name` field present
- Selection options non-empty

### Step 3 — Code generation

Two generator objects are instantiated:

| Generator | Responsibility |
|-----------|---------------|
| `PythonGenerator` | Produces `models/<name>.py` and `__manifest__.py` content |
| `XmlGenerator` | Produces `views/<name>_view.xml` content |

Each generator delegates to its corresponding template:

```
PythonGenerator
  └─► ModelTemplate.render(model, config)    → Python class body
  └─► ManifestTemplate.render(model, config) → __manifest__.py

XmlGenerator
  └─► ViewTemplate.render(model, config)    → combined views XML
       └─► FieldTemplates.pythonPreview / xmlPreview  (per-field)
```

### Step 4 — Write files (full generation only)

`FileHandler` creates the module directory structure:

```
<outputPath>/
├── __init__.py
├── __manifest__.py
├── models/
│   ├── __init__.py       (if generateModelsInit)
│   └── <model_name>.py
├── views/
│   └── <model_name>_view.xml
├── security/
│   └── ir.model.access.csv  (if generateSecurity)
└── data/
    └── demo.xml             (if generateDemoStub)
```

All writes are async (`await handler.writeFile(…)`).

### Step 5 — Return result

`GenerationResult` is returned with the model name, output path, and the
list of written file paths.

---

## Dry-run mode

`OdooGenerator.dryRun()` performs Steps 1–3 only and returns a
`Map<String, String>` (relative path → content) without touching the
filesystem.  This is used by:

- The `oomg dry-run` CLI command
- The `GeneratorCache` (caches the map by SHA-256 key)
- Integration tests
- The `examples/dry_run_preview.dart` example

---

## Exception hierarchy

```
GeneratorException (extends Exception)
├── ValidationException    — invalid model/field names, selection options
├── ReservedFieldException — field name is in kReservedOdooFieldNames
├── DuplicateFieldException — same field name added twice
├── GenerationException    — filesystem / pipeline error
└── OutputPathException    — output directory inaccessible
```

All exceptions carry a human-readable `message` and an optional `hint`.

---

## Field rendering contract

Every `OdooField` subclass must implement:

| Method | Returns |
|--------|---------|
| `toPython()` | Python RHS, e.g. `fields.Char(string='Name', required=True)` |
| `toFormXML()` | `<field …/>` element for the form view |
| `toTreeXML()` | `<field name="…"/>` element for the tree view (default impl) |
| `toSearchXML()` | `<field name="…"/>` element for the search view (default impl; `Selection` overrides to emit a `<filter>`) |

The `buildPythonCall(fieldType, positional, {kwargs})` helper on `OdooField`
assembles the Python call and applies all common parameters automatically.

---

## Naming conventions module

`NamingConventions` centralises all name transformations used across templates:

| Method | Example input | Example output |
|--------|--------------|----------------|
| `toLabel(name)` | `'x_product_custom'` | `'X Product Custom'` |
| `viewFileName(modelName)` | `'x_task'` | `'x_task_view.xml'` |
| `modelRefId(modelName)` | `'x_task'` | `'model_x_task'` |
| `accessId(modelName)` | `'x_task'` | `'access_x_task'` |
| `toCamelCase(name)` | `'x_task'` | `'XTask'` |
| `toSnakeCase(name)` | `'XTask'` | `'x_task'` |

---

## Parallel generator design

`ParallelGenerator` wraps `Future.wait` with an optional concurrency window:

```
models.length tasks
      │
      ▼
if concurrency == null:
    Future.wait(all tasks)
else:
    for chunk in batches(models, size=concurrency):
        Future.wait(chunk)
```

Each task calls `model.generate(outputPath: '$outputPath/${model.modelName}')`.
Failures are captured into `_FailedGeneration` records so sibling tasks are
not aborted.

---

## CLI architecture

`bin/oomg.dart` uses the `package:args` `CommandRunner<int>` pattern:

```
main()
  └─► CommandRunner<int>('oomg', …)
        ├── GenerateCommand   extends Command<int>
        ├── ValidateCommand   extends Command<int>
        ├── DryRunCommand     extends Command<int>
        ├── ExportCommand     extends Command<int>
        └── VersionCommand    extends Command<int>
```

Each command:
1. Declares its own flags via `argParser` in the constructor.
2. Implements `run()` → `Future<int>` returning an exit code.
3. Resolves the model from `--schema` or `--model` via `_buildFromSchema()` /
   `_buildField()`.

Logging is directed to **stderr** so stdout can be piped cleanly.
The top-level `main()` catches `GeneratorException`, `UsageException`, and
generic errors, printing them to stderr with appropriate exit codes.

---

## Testing strategy

| Test file | Scope |
|-----------|-------|
| `test/core_test.dart` | Unit tests for every field type's `toPython()` / `toFormXML()` output |
| `test/generator_test.dart` | Unit tests for `OdooModel` builder, `OdooGenerator.dryRun()`, `PythonGenerator`, `XmlGenerator`, `ManifestTemplate`, `CodeFormatter`, `NamingConventions`, `StringUtils`, `GeneratorCache` |
| `test/validators_test.dart` | Unit tests for all `Validators` methods and exception types |
| `test/integration_test.dart` | End-to-end tests: model generation writes files to a temp directory, parallel generation, error cases |

Run the full suite:

```bash
dart test
```

Run with coverage:

```bash
dart pub global activate coverage
dart test --coverage=coverage/
dart pub global run coverage:format_coverage \
  --lcov --in=coverage/ --out=coverage/lcov.info --report-on=lib/
```
