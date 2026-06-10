import 'package:test/test.dart';
import 'package:odoo_model_generator/odoo_model_generator.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Validator tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('Validators.modelName', () {
    test('accepts valid model name', () {
      expect(() => Validators.modelName('x_product_custom'), returnsNormally);
      expect(() => Validators.modelName('x_a'), returnsNormally);
    });

    test('rejects empty string', () {
      expect(
        () => Validators.modelName(''),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects name without x_ prefix', () {
      expect(
        () => Validators.modelName('product_custom'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects uppercase letters', () {
      expect(
        () => Validators.modelName('x_Product'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects name longer than 64 chars', () {
      final longName = 'x_${'a' * 63}';
      expect(
        () => Validators.modelName(longName),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('Validators.fieldName', () {
    test('accepts valid field names', () {
      expect(() => Validators.fieldName('product_code'), returnsNormally);
      expect(() => Validators.fieldName('a'), returnsNormally);
      expect(() => Validators.fieldName('abc123'), returnsNormally);
    });

    test('rejects empty name', () {
      expect(
        () => Validators.fieldName(''),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects reserved names', () {
      for (final r in kReservedOdooFieldNames) {
        expect(
          () => Validators.fieldName(r),
          throwsA(isA<ReservedFieldException>()),
          reason: 'Expected $r to be rejected',
        );
      }
    });

    test('rejects uppercase', () {
      expect(
        () => Validators.fieldName('ProductCode'),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('Validators.moduleName', () {
    test('accepts valid names', () {
      expect(() => Validators.moduleName('sale'), returnsNormally);
      expect(() => Validators.moduleName('my_module'), returnsNormally);
    });

    test('rejects invalid names', () {
      expect(
        () => Validators.moduleName('My-Module'),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('Validators.recNameExists', () {
    test('passes when rec_name field exists', () {
      expect(
        () => Validators.recNameExists('name', ['name', 'code']),
        returnsNormally,
      );
    });

    test('fails when rec_name field is missing', () {
      expect(
        () => Validators.recNameExists('label', ['name', 'code']),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('Validators.fieldList', () {
    test('accepts unique field names', () {
      final fields = [
        const Char('name'),
        const Integer('qty'),
      ];
      expect(() => Validators.fieldList(fields), returnsNormally);
    });

    test('rejects duplicate names', () {
      final fields = [
        const Char('name'),
        const Integer('name'), // duplicate
      ];
      expect(
        () => Validators.fieldList(fields),
        throwsA(isA<DuplicateFieldException>()),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('Validators.fullModel', () {
    test('passes for a minimal valid model', () {
      expect(
        () => Validators.fullModel(
          name: 'x_my_model',
          stringField: 'name',
          fields: [const NameField()],
          dependencies: ['sale'],
        ),
        returnsNormally,
      );
    });

    test('fails for invalid model name', () {
      expect(
        () => Validators.fullModel(
          name: 'bad_model',
          stringField: 'name',
          fields: [const NameField()],
          dependencies: <String>[],
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('fails for missing rec_name field', () {
      expect(
        () => Validators.fullModel(
          name: 'x_model',
          stringField: 'title', // not in fields
          fields: [const NameField()],
          dependencies: <String>[],
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
