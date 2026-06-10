/// Public API surface for the `odoo_model_generator` package.
///
/// Import this single file to access everything:
/// ```dart
/// import 'package:odoo_model_generator/odoo_model_generator.dart';
/// ```
library odoo_model_generator;

// ── Core model builder ────────────────────────────────────────────────────
export 'src/core/model_builder.dart'
    show
        OdooModel,
        GeneratorConfig,
        GenerationResult,
        OnchangeDefinition,
        ConstraintDefinition,
        ComputeDefinition,
        InheritMode;

// ── Field types ───────────────────────────────────────────────────────────
export 'src/core/field_types.dart'
    show
        OdooField,
        // Scalar
        Char,
        Text,
        Html,
        Integer,
        Float,
        Monetary,
        Boolean,
        Date,
        Datetime,
        Binary,
        Image,
        // Enumeration
        Selection,
        // Relational
        Many2one,
        One2many,
        Many2many,
        // Computed
        ComputedField,
        // Convenience
        NameField,
        Reference,
        // Constants
        kReservedOdooFieldNames;

// ── Exceptions ────────────────────────────────────────────────────────────
export 'src/core/exceptions.dart'
    show
        GeneratorException,
        ValidationException,
        ReservedFieldException,
        DuplicateFieldException,
        GenerationException,
        OutputPathException;

// ── Validators ────────────────────────────────────────────────────────────
export 'src/core/validators.dart' show Validators;

// ── Main generator engine ─────────────────────────────────────────────────
export 'src/core/generator.dart' show OdooGenerator;

// ── Caching ───────────────────────────────────────────────────────────────
export 'src/core/generator_cache.dart' show GeneratorCache;

// ── Parallel generation ───────────────────────────────────────────────────
export 'src/parallel_generator.dart'
    show ParallelGenerator, ParallelGenerationResult;

// ── Module exporter ───────────────────────────────────────────────────────
export 'src/module_exporter.dart' show ModuleExporter, ExportFormat;

// ── Advanced features ─────────────────────────────────────────────────────
export 'src/advanced.dart'
    show
        ServerAction,
        ServerActionExtension,
        OdooCLIIntegration,
        GenerationReport;

// ── Utilities (public surface) ────────────────────────────────────────────
export 'src/utils/naming_conventions.dart' show NamingConventions;
export 'src/utils/string_utils.dart' show StringUtils;

// ── Templates (for custom rendering) ─────────────────────────────────────
export 'src/templates/model_template.dart' show ModelTemplate;
export 'src/templates/manifest_template.dart' show ManifestTemplate;
export 'src/templates/view_template.dart' show ViewTemplate;
export 'src/templates/field_templates.dart' show FieldTemplates;

// ── Code generators ───────────────────────────────────────────────────────
export 'src/codegen/python_generator.dart' show PythonGenerator;
export 'src/codegen/xml_generator.dart' show XmlGenerator;
export 'src/codegen/formatter.dart' show CodeFormatter;
