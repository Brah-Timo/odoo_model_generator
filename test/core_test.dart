import 'package:test/test.dart';
import 'package:odoo_model_generator/odoo_model_generator.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Core field-type tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('Char field', () {
    test('generates correct Python declaration', () {
      const f = Char('product_name', required: true);
      final py = f.toPython();
      expect(py, contains('fields.Char'));
      expect(py, contains("string='Product Name'"));
      expect(py, contains('required=True'));
    });

    test('includes size when set', () {
      const f = Char('code', size: 64);
      expect(f.toPython(), contains('size=64'));
    });

    test('includes translate when true', () {
      const f = Char('label', translate: true);
      expect(f.toPython(), contains('translate=True'));
    });

    test('generates form XML element', () {
      const f = Char('name');
      expect(f.toFormXML(), contains('name="name"'));
    });

    test('label is auto-formatted from name', () {
      const f = Char('product_code');
      expect(f.label, equals('Product Code'));
    });

    test('explicit string overrides auto-label', () {
      const f = Char('pcode', string: 'P-Code');
      expect(f.label, equals('P-Code'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('Integer field', () {
    test('generates correct Python', () {
      const f = Integer('quantity');
      expect(f.toPython(), contains('fields.Integer'));
    });

    test('required flag', () {
      const f = Integer('qty', required: true);
      expect(f.toPython(), contains('required=True'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('Float field', () {
    test('generates without digits', () {
      const f = Float('price');
      expect(f.toPython(), contains('fields.Float'));
      expect(f.toPython(), isNot(contains('digits')));
    });

    test('generates with digits tuple', () {
      const f = Float('price', digits: (10, 2));
      expect(f.toPython(), contains('digits=(10, 2)'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('Selection field', () {
    test('renders options as Python list of tuples', () {
      const f = Selection('state', ['draft', 'done']);
      final py = f.toPython();
      expect(py, contains("('draft', 'Draft')"));
      expect(py, contains("('done', 'Done')"));
    });

    test('empty options — should be caught by validator', () {
      expect(
        () => Validators.selectionOptions(<String>[]),
        throwsA(isA<ValidationException>()),
      );
    });

    test('resolvedOptions works for raw pairs', () {
      const f = Selection(
        'type',
        <String>[],
        rawOptions: [('a', 'Type A'), ('b', 'Type B')],
      );
      expect(f.resolvedOptions, [('a', 'Type A'), ('b', 'Type B')]);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('Many2one field', () {
    test('includes relation name', () {
      const f = Many2one('partner_id', relation: 'res.partner');
      expect(f.toPython(), contains("'res.partner'"));
    });

    test('cascade ondelete', () {
      const f = Many2one('line_id',
          relation: 'x_line', ondelete: 'cascade');
      expect(f.toPython(), contains("ondelete='cascade'"));
    });

    test('domain attribute in form XML', () {
      const f = Many2one('user_id',
          relation: 'res.users',
          domain: "[('active', '=', True)]");
      expect(f.toFormXML(), contains('domain='));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('One2many field', () {
    test('includes relation and inverse field', () {
      const f = One2many('line_ids',
          relation: 'x_order_line', inverseField: 'order_id');
      final py = f.toPython();
      expect(py, contains("'x_order_line'"));
      expect(py, contains("'order_id'"));
    });

    test('form XML uses one2many_list widget', () {
      const f = One2many('lines',
          relation: 'x_line', inverseField: 'parent_id');
      expect(f.toFormXML(), contains('widget="one2many_list"'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('Many2many field', () {
    test('includes relation and pivot table', () {
      const f = Many2many('tag_ids', relation: 'x_tag');
      final py = f.toPython();
      expect(py, contains("'x_tag'"));
      expect(py, contains('many2many_tags'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('ComputedField', () {
    test('emits compute= with method name', () {
      const f = ComputedField(
        'total',
        computeMethod: '_compute_total',
        store: true,
      );
      expect(f.toPython(), contains("compute='_compute_total'"));
      expect(f.toPython(), contains('store=True'));
    });

    test('readonly by default', () {
      const f = ComputedField('x', computeMethod: '_compute_x');
      expect(f.readonly, isTrue);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('Monetary field', () {
    test('emits currency_field', () {
      const f = Monetary('amount');
      expect(f.toPython(), contains("currency_field='currency_id'"));
    });

    test('custom currency_field', () {
      const f = Monetary('price', currencyField: 'company_currency_id');
      expect(f.toPython(), contains("'company_currency_id'"));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('Boolean field', () {
    test('generates correct Python', () {
      const f = Boolean('is_active');
      expect(f.toPython(), contains('fields.Boolean'));
    });

    test('default value emitted', () {
      const f = Boolean('is_active', defaultValue: true);
      expect(f.toPython(), contains('default=True'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('Date / Datetime fields', () {
    test('Date generates correct Python', () {
      const f = Date('start_date', required: true);
      expect(f.toPython(), contains('fields.Date'));
      expect(f.toPython(), contains('required=True'));
    });

    test('Datetime generates correct Python', () {
      const f = Datetime('created_at');
      expect(f.toPython(), contains('fields.Datetime'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('Binary / Image fields', () {
    test('Binary emits widget binary in form XML', () {
      const f = Binary('document');
      expect(f.toFormXML(), contains('widget="binary"'));
    });

    test('Image emits max_width and max_height', () {
      const f = Image('photo', maxWidth: 800, maxHeight: 600);
      expect(f.toPython(), contains('max_width=800'));
      expect(f.toPython(), contains('max_height=600'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('NameField convenience', () {
    test('is required by default', () {
      const f = NameField();
      expect(f.required, isTrue);
      expect(f.name, equals('name'));
    });

    test('custom fieldName', () {
      const f = NameField(fieldName: 'full_name');
      expect(f.name, equals('full_name'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('Reserved field names', () {
    test('kReservedOdooFieldNames contains id', () {
      expect(kReservedOdooFieldNames, contains('id'));
    });

    test('validator rejects create_date', () {
      expect(
        () => Validators.fieldName('create_date'),
        throwsA(isA<ReservedFieldException>()),
      );
    });
  });
}
