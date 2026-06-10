import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:odoo_model_generator/odoo_model_generator.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Integration tests — writes real files to a temp directory
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('oomg_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  // ── Simple model ──────────────────────────────────────────────────────────

  group('Simple model generation', () {
    test('generates all expected files', () async {
      final model = OdooModel('x_simple_product')
        ..field(const NameField())
        ..field(const Float('price', digits: (10, 2)))
        ..field(const Integer('quantity'))
        ..field(const Text('description'));

      final result = await model.generate(outputPath: tempDir.path);

      expect(result.writtenFiles.length, greaterThanOrEqualTo(5));
      _assertFileExists(tempDir.path, '__init__.py');
      _assertFileExists(tempDir.path, '__manifest__.py');
      _assertFileExists(tempDir.path, 'models/__init__.py');
      _assertFileExists(
          tempDir.path, 'models/x_simple_product.py');
      _assertFileExists(
          tempDir.path, 'views/x_simple_product_view.xml');
      _assertFileExists(
          tempDir.path, 'security/ir.model.access.csv');
    });

    test('models.py has correct class and fields', () async {
      final model = OdooModel('x_simple_product')
        ..field(const NameField())
        ..field(const Float('price'));

      await model.generate(outputPath: tempDir.path);
      final content =
          File(p.join(tempDir.path, 'models/x_simple_product.py'))
              .readAsStringSync();

      expect(content, contains('class XSimpleProduct'));
      expect(content, contains("_name = 'x_simple_product'"));
      expect(content, contains('fields.Char'));
      expect(content, contains('fields.Float'));
      expect(content, contains('from odoo import models, fields, api'));
    });

    test('views XML is well-formed', () async {
      final model = OdooModel('x_simple_product')
        ..field(const NameField())
        ..field(const Float('price'));

      await model.generate(outputPath: tempDir.path);
      final xml =
          File(p.join(tempDir.path, 'views/x_simple_product_view.xml'))
              .readAsStringSync();

      expect(xml, startsWith('<?xml'));
      expect(xml, contains('<odoo>'));
      expect(xml, contains('</odoo>'));
      expect(xml, contains('ir.ui.view'));
    });

    test('security CSV has correct header', () async {
      final model = OdooModel('x_simple_product')
        ..field(const NameField());

      await model.generate(outputPath: tempDir.path);
      final csv =
          File(p.join(tempDir.path, 'security/ir.model.access.csv'))
              .readAsStringSync();

      expect(csv.startsWith('id,name,model_id:id'), isTrue);
      expect(csv, contains('perm_read,perm_write,perm_create,perm_unlink'));
    });

    test('manifest.py includes model name and base dep', () async {
      final model = OdooModel('x_simple_product')
        ..field(const NameField());

      await model.generate(outputPath: tempDir.path);
      final manifest =
          File(p.join(tempDir.path, '__manifest__.py')).readAsStringSync();

      expect(manifest, contains("'X Simple Product'"));
      expect(manifest, contains("'base'"));
    });
  });

  // ── Advanced model ────────────────────────────────────────────────────────

  group('Advanced model generation', () {
    test('full invoice model generates successfully', () async {
      final invoice = OdooModel(
        'x_invoice_system',
        docstring: 'Advanced Invoice System',
      )
        ..inherit('mail.thread')
        ..dependency('account')
        ..dependency('stock')
        ..field(const Char('number', required: true, inTree: true))
        ..field(const Char('name', required: true))
        ..field(const Many2one('partner_id', relation: 'res.partner',
            required: true, inTree: true))
        ..field(const Date('invoice_date', required: true))
        ..field(const Selection('state', ['draft', 'confirmed', 'paid']))
        ..field(const One2many('line_ids',
            relation: 'x_invoice_line', inverseField: 'invoice_id'))
        ..field(const Float('total_amount',
            digits: (14, 2), inTree: true))
        ..field(const Text('notes'))
        ..compute(const ComputeDefinition(
          methodName: '_compute_total_amount',
          dependsOn: ['line_ids'],
          bodyLines: ['record.total_amount = 0.0  # TODO: sum lines'],
        ))
        ..constraint(const ConstraintDefinition(
          constrainedFields: ['number'],
          methodName: '_check_number',
          errorMessage: 'Invoice number is required',
        ))
        ..sqlConstraint(
          'unique_number',
          'UNIQUE(number)',
          'Invoice number must be unique',
        );

      final result = await invoice.generate(outputPath: tempDir.path);
      expect(result.writtenFiles, isNotEmpty);

      final modelPy = File(
              p.join(tempDir.path, 'models/x_invoice_system.py'))
          .readAsStringSync();

      expect(modelPy, contains('class XInvoiceSystem'));
      expect(modelPy, contains("_inherit = ['mail.thread']"));
      expect(modelPy, contains('_sql_constraints'));
      expect(modelPy, contains('unique_number'));
      expect(modelPy, contains('@api.depends'));
      expect(modelPy, contains('@api.constrains'));
    });

    test('manifest includes all dependencies', () async {
      final model = OdooModel('x_order')
        ..dependency('sale')
        ..dependency('purchase')
        ..dependency('stock')
        ..field(const NameField());

      await model.generate(outputPath: tempDir.path);
      final manifest =
          File(p.join(tempDir.path, '__manifest__.py')).readAsStringSync();

      expect(manifest, contains("'sale'"));
      expect(manifest, contains("'purchase'"));
      expect(manifest, contains("'stock'"));
    });
  });

  // ── Validation during generate ────────────────────────────────────────────

  group('Validation errors during generate', () {
    test('throws for invalid model name', () async {
      final model = OdooModel('bad_model_name');
      // OdooModel accepts any name; validation happens in generate()
      // We need to add a field first
      model.field(const NameField());
      await expectLater(
        () => model.generate(outputPath: tempDir.path),
        throwsA(isA<GeneratorException>()),
      );
    });

    test('throws for missing rec_name field', () async {
      final model = OdooModel('x_model', stringField: 'title');
      model.field(const Char('description')); // no 'title' field
      await expectLater(
        () => model.generate(outputPath: tempDir.path),
        throwsA(isA<GeneratorException>()),
      );
    });
  });

  // ── Parallel generator ────────────────────────────────────────────────────

  group('ParallelGenerator', () {
    test('generates multiple models concurrently', () async {
      final models = List.generate(
        4,
        (i) => OdooModel('x_model_$i')..field(const NameField()),
      );

      final gen = ParallelGenerator();
      final result = await gen.generateAll(
        models,
        outputPath: tempDir.path,
      );

      expect(result.successful.length, equals(4));
      expect(result.failed, isEmpty);
      expect(result.hasErrors, isFalse);
      expect(result.totalFiles, greaterThan(0));
    });

    test('reports failed models without aborting others', () async {
      final models = [
        OdooModel('x_valid_one')..field(const NameField()),
        OdooModel('bad_name')..field(const NameField()), // will fail
        OdooModel('x_valid_two')..field(const NameField()),
      ];

      final gen = ParallelGenerator();
      final result = await gen.generateAll(
        models,
        outputPath: tempDir.path,
      );

      expect(result.successful.length, equals(2));
      expect(result.failed.length, equals(1));
      expect(result.failed.first.modelName, equals('bad_name'));
    });
  });

  // ── GenerationResult ──────────────────────────────────────────────────────

  group('GenerationResult', () {
    test('toString contains model name', () {
      final r = GenerationResult(
        modelName: 'x_m',
        outputPath: '/tmp/m',
        writtenFiles: ['/tmp/m/__init__.py'],
      );
      expect(r.toString(), contains('x_m'));
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────────────────────

void _assertFileExists(String base, String relative) {
  final file = File(p.join(base, relative));
  expect(file.existsSync(), isTrue,
      reason: 'Expected file to exist: ${file.path}');
  expect(file.lengthSync(), greaterThan(0),
      reason: 'Expected file to be non-empty: ${file.path}');
}
