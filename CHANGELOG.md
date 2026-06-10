# Changelog

All notable changes to `odoo_model_generator` are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).  
Versions follow [Semantic Versioning](https://semver.org/).

---

## [2.0.0] — 2024-12-01

### Added
- **Dart 3.0 records syntax** for `Float.digits` — `digits: (10, 2)` instead of a list.
- **`NameField`** convenience class — shorthand for `Char('name', required: true)`.
- **`Monetary` field type** — `fields.Monetary` with currency field support.
- **`Image` field type** — `fields.Image` with `maxWidth` / `maxHeight`.
- **`Reference` field type** — dynamic model reference.
- **`ComputeDefinition`** — register compute method bodies directly on the model.
- **`OnchangeDefinition`** — register onchange method bodies.
- **`ConstraintDefinition`** — register Python constraint methods.
- **SQL constraints** via `.sqlConstraint(id, expr, msg)`.
- **`_order` support** on `OdooModel`.
- **`InheritMode` enum** — distinguishes mixin vs extension inheritance.
- **`OdooGenerator.dryRun()`** — returns all file contents without I/O.
- **`ParallelGenerator`** — concurrent multi-model generation with `concurrency` cap.
- **`GeneratorCache`** — LRU in-memory cache for generated content.
- **`ModuleExporter`** — ZIP and TAR.GZ archive export.
- **`OdooCLIIntegration`** — bridge to `odoo-bin` for direct installs.
- **`ServerAction`** — metadata for `ir.actions.server` records.
- **`GenerationReport`** — ASCII table summary of a generation run.
- **`CodeFormatter`** — post-processes Python and XML output.
- **`FieldTemplates`** — per-field rendering helpers and Markdown table generator.
- **`GeneratorConfig.copyWith`** — immutable config updates.
- **`GeneratorConfig.extraDependencies`** — inject dependencies via config.
- **Full CLI (`oomg`)** — `generate`, `validate`, `dry-run`, `export`, `version`.
- **JSON schema input** for CLI — describe models in JSON.
- **Comprehensive test suite** — unit + integration tests, > 95% coverage.
- **5 complete examples** in `example/`.
- **Auto-create module sub-directories** (wizards, reports, controllers, etc.).
- **Chatter integration** — emits `<div class="oe_chatter">` when `mail.thread` is inherited.
- **Tree decorations** — `decoration-success` / `decoration-muted` from `Selection` fields.
- **Search view group-by** suggestions for `Many2one` fields.
- **Notebook pages** for `One2many`, `Many2many`, `Text`, `Html` fields.
- **Status bar** for the first `Selection` field.
- **Two-column form layout** auto-split.
- **Shadow timestamp fields** (`create_date_display`, `write_date_display`).
- **Sequence auto-assign** in `create()` when `createSequence=true`.

### Changed
- `OdooField` is now `sealed` — exhaustive `switch` works correctly.
- `Many2one` field name is now the first positional parameter (instead of second).
- `generate()` now returns `GenerationResult` (was `void`).
- Module structure now includes all standard Odoo subdirectories.
- `models.py` now split into `models/<modelName>.py` for better organisation.
- Security CSV now generates both `_user` and `_manager` rows.
- Manifest now uses Python dict literal (`.py`) not YAML.

### Fixed
- Trailing commas in generated Python field kwargs no longer appear.
- Blank line collapsing is now deterministic.
- `_rec_name` validation now triggers before any file is written.

### Removed
- `OdooModel.docstring` is no longer a required parameter (now optional).
- `Many2one.cascadeDelete` removed in favour of `ondelete: 'cascade'`.

---

## [1.0.0] — 2024-06-01

### Added
- Initial public release.
- `OdooModel` fluent builder.
- Basic field types: `Char`, `Text`, `Integer`, `Float`, `Boolean`, `Date`,
  `Datetime`, `Selection`, `Binary`.
- Relational fields: `Many2one`, `One2many`, `Many2many`.
- `ComputedField` (basic).
- `generate()` producing `models.py`, `__manifest__.py`, `views.xml`,
  `security/ir.model.access.csv`.
- Basic form / tree / search view generation.
- Method chaining API.
- `ValidationException`, `GenerationException` error types.
