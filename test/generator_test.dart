import 'package:test/test.dart';
import 'package:odoo_model_generator/odoo_model_generator.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  OdooModel builder tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('OdooModel — construction', () {
    test('creates model with correct name', () {
      final m = OdooModel('x_product');
      expect(m.modelName, equals('x_product'));
    });

    test('stringField defaults to "name"', () {
      final m = OdooModel('x_test');
      expect(m.stringField, equals('name'));
    });

    test('docstring is stored', () {
      final m = OdooModel('x_model', docstring: 'My model description');
      expect(m.docstring, equals('My model description'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('OdooModel — field builder (chaining)', () {
    test('adds fields in insertion order', () {
      final m = OdooModel('x_m')
        ..field(const NameField())
        ..field(const Integer('qty'))
        ..field(const Float('price'));

      expect(m.fields.length, equals(3));
      expect(m.fields.map((OdooField f) => f.name).toList(),
          equals(['name', 'qty', 'price']));
    });

    test('throws DuplicateFieldException for repeated field name', () {
      final m = OdooModel('x_m')..field(const Char('code'));
      expect(
        () => m.field(const Char('code')),
        throwsA(isA<DuplicateFieldException>()),
      );
    });

    test('throws ReservedFieldException for reserved names', () {
      expect(
        () => OdooModel('x_m').field(const Char('id')),
        throwsA(isA<ReservedFieldException>()),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('OdooModel — inherit / dependency', () {
    test('adds inherit names', () {
      final m = OdooModel('x_m')
        ..inherit('mail.thread')
        ..inherit('mail.activity.mixin');

      expect(m.inherits,
          equals(['mail.thread', 'mail.activity.mixin']));
    });

    test('adds dependencies uniquely', () {
      final m = OdooModel('x_m')
        ..dependency('sale')
        ..dependency('sale') // duplicate
        ..dependency('stock');

      expect(m.dependencies, equals(['sale', 'stock']));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('OdooModel — onchange / constraint / compute', () {
    test('registers onchange definitions', () {
      final m = OdooModel('x_m')
        ..onchange(const OnchangeDefinition(
          triggerFields: ['partner_id'],
          methodName: '_onchange_partner_id',
        ));

      expect(m.onchanges.length, equals(1));
      expect(m.onchanges.first.methodName,
          equals('_onchange_partner_id'));
    });

    test('registers constraint definitions', () {
      final m = OdooModel('x_m')
        ..constraint(const ConstraintDefinition(
          constrainedFields: ['amount'],
          methodName: '_check_amount',
          errorMessage: 'Amount must be > 0',
        ));

      expect(m.constraints.first.errorMessage, contains('Amount'));
    });

    test('registers compute definitions', () {
      final m = OdooModel('x_m')
        ..compute(const ComputeDefinition(
          methodName: '_compute_total',
          dependsOn: ['price', 'qty'],
          bodyLines: ["record.total = record.price * record.qty"],
        ));

      expect(m.computes.first.dependsOn, contains('price'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('OdooModel — sqlConstraint', () {
    test('adds sql constraint tuple', () {
      final m = OdooModel('x_m')
        ..sqlConstraint(
          'unique_name',
          'UNIQUE(name)',
          'Name must be unique',
        );

      expect(m.sqlConstraints.length, equals(1));
      expect(m.sqlConstraints.first.$1, equals('unique_name'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('GeneratorConfig', () {
    test('default values', () {
      final c = GeneratorConfig();
      expect(c.version, equals('1.0.0'));
      expect(c.license, equals('LGPL-3'));
      expect(c.generateSecurity, isTrue);
    });

    test('copyWith overrides specific values', () {
      final c = GeneratorConfig();
      final c2 = c.copyWith(version: '2.0.0', isApplication: true);
      expect(c2.version, equals('2.0.0'));
      expect(c2.isApplication, isTrue);
      expect(c2.license, equals('LGPL-3')); // unchanged
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('OdooGenerator — dryRun', () {
    test('returns all expected file keys', () {
      final model = OdooModel('x_test_model')
        ..field(const NameField())
        ..field(const Float('amount'));

      final gen = OdooGenerator(model);
      final files = gen.dryRun();

      expect(files.keys, contains('__init__.py'));
      expect(files.keys, contains('__manifest__.py'));
      expect(files.keys,
          anyElement((String k) => k.contains('models/')));
      expect(files.keys,
          anyElement((String k) => k.contains('views/')));
      expect(files.keys, contains('security/ir.model.access.csv'));
    });

    test('models.py contains class name', () {
      final model = OdooModel('x_demo')
        ..field(const NameField());

      final files = OdooGenerator(model).dryRun();
      final modelPy = files.entries
          .firstWhere((MapEntry<String, String> e) => e.key.contains('models/'))
          .value;
      expect(modelPy, contains('class XDemo'));
      expect(modelPy, contains("_name = 'x_demo'"));
    });

    test('manifest.py contains depends', () {
      final model = OdooModel('x_order')
        ..dependency('sale')
        ..dependency('stock')
        ..field(const NameField());

      final files = OdooGenerator(model).dryRun();
      final manifest = files['__manifest__.py']!;

      expect(manifest, contains("'sale'"));
      expect(manifest, contains("'stock'"));
      expect(manifest, contains("'base'"));
    });

    test('views XML contains form record', () {
      final model = OdooModel('x_task')..field(const NameField());
      final files = OdooGenerator(model).dryRun();
      final xml = files.entries
          .firstWhere((MapEntry<String, String> e) => e.key.contains('views/'))
          .value;
      expect(xml, contains('ir.ui.view'));
      expect(xml, contains('view_form_x_task'));
      expect(xml, contains('view_tree_x_task'));
    });

    test('security CSV has correct columns', () {
      final model = OdooModel('x_lead')..field(const NameField());
      final files = OdooGenerator(model).dryRun();
      final csv = files['security/ir.model.access.csv']!;

      expect(csv, contains('perm_read'));
      expect(csv, contains('perm_write'));
      expect(csv, contains('base.group_user'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('PythonGenerator', () {
    test('generates valid Python class declaration', () {
      final model = OdooModel(
        'x_invoice',
        docstring: 'Invoice model',
      )
        ..field(const NameField())
        ..field(const Char('reference'))
        ..field(const Float('amount'));

      final gen = PythonGenerator(model);
      final code = gen.generate();

      expect(code, contains('class XInvoice'));
      expect(code, contains("_name = 'x_invoice'"));
      expect(code, contains('fields.Char'));
      expect(code, contains('fields.Float'));
    });

    test('includes _sql_constraints when set', () {
      final model = OdooModel('x_product')
        ..field(const NameField())
        ..sqlConstraint('unique_code', 'UNIQUE(name)', 'Name must be unique');

      final code = PythonGenerator(model).generate();
      expect(code, contains("_sql_constraints"));
      expect(code, contains("unique_code"));
    });

    test('includes @api.constrains methods', () {
      final model = OdooModel('x_m')
        ..field(const NameField())
        ..constraint(const ConstraintDefinition(
          constrainedFields: ['name'],
          methodName: '_check_name',
          errorMessage: 'Name is required',
        ));

      final code = PythonGenerator(model).generate();
      expect(code, contains("@api.constrains('name')"));
      expect(code, contains('_check_name'));
    });

    test('includes compute methods with @api.depends', () {
      final model = OdooModel('x_order')
        ..field(const NameField())
        ..field(const Float('price'))
        ..field(const Integer('qty'))
        ..field(const ComputedField(
          'total',
          computeMethod: '_compute_total',
          store: true,
          depends: ['price', 'qty'],
        ))
        ..compute(const ComputeDefinition(
          methodName: '_compute_total',
          dependsOn: ['price', 'qty'],
          bodyLines: ['record.total = record.price * record.qty'],
        ));

      final code = PythonGenerator(model).generate();
      expect(code, contains("@api.depends('price', 'qty')"));
      expect(code, contains('_compute_total'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('XmlGenerator', () {
    test('generates valid XML with all view records', () {
      final model = OdooModel('x_task')
        ..field(const NameField())
        ..field(const Selection('priority', ['low', 'medium', 'high']))
        ..field(const Many2one('user_id', relation: 'res.users'));

      final xml = XmlGenerator(model).generateViews();

      expect(xml, contains('<?xml version="1.0"'));
      expect(xml, contains('<odoo>'));
      expect(xml, contains('view_form_x_task'));
      expect(xml, contains('view_tree_x_task'));
      expect(xml, contains('view_search_x_task'));
      expect(xml, contains('action_x_task'));
      expect(xml, contains('menu_x_task'));
    });

    test('Selection renders statusbar in form', () {
      final model = OdooModel('x_doc')
        ..field(const NameField())
        ..field(const Selection('state', ['draft', 'done']));

      final xml = XmlGenerator(model).generateViews();
      expect(xml, contains('statusbar'));
    });

    test('One2many renders in notebook page', () {
      final model = OdooModel('x_order')
        ..field(const NameField())
        ..field(
            const One2many('line_ids', relation: 'x_line', inverseField: 'order_id'));

      final xml = XmlGenerator(model).generateViews();
      expect(xml, contains('<notebook>'));
      expect(xml, contains('<page'));
    });

    test('mail.thread chatter rendered', () {
      final model = OdooModel('x_issue')
        ..inherit('mail.thread')
        ..field(const NameField());

      final xml = XmlGenerator(model).generateViews();
      expect(xml, contains('message_follower_ids'));
      expect(xml, contains('message_ids'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('ManifestTemplate', () {
    test('base is always included in depends', () {
      final model = OdooModel('x_m')..field(const NameField());
      final manifest = ManifestTemplate.render(model, const GeneratorConfig());
      expect(manifest, contains("'base'"));
    });

    test('extra dependencies from config are included', () {
      final model = OdooModel('x_m')..field(const NameField());
      final config =
          const GeneratorConfig(extraDependencies: ['helpdesk']);
      final manifest = ManifestTemplate.render(model, config);
      expect(manifest, contains("'helpdesk'"));
    });

    test('isApplication=true emits application: True', () {
      final model = OdooModel('x_m')..field(const NameField());
      final config = const GeneratorConfig(isApplication: true);
      final manifest = ManifestTemplate.render(model, config);
      expect(manifest, contains("'application': True"));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('CodeFormatter', () {
    test('formatPython removes trailing whitespace', () {
      const raw = 'line1   \nline2  \n';
      final formatted = CodeFormatter.formatPython(raw);
      expect(formatted.split('\n').every((String l) => !l.endsWith(' ')), isTrue);
    });

    test('formatPython collapses >2 blank lines', () {
      const raw = 'a\n\n\n\n\nb\n';
      final formatted = CodeFormatter.formatPython(raw);
      expect(
          formatted.contains('\n\n\n\n'), isFalse);
    });

    test('formatXml collapses >1 blank lines', () {
      const raw = '<a/>\n\n\n<b/>\n';
      final formatted = CodeFormatter.formatXml(raw);
      expect(formatted.contains('\n\n\n'), isFalse);
    });

    test('file always ends with a single newline', () {
      const raw = 'hello world   ';
      final formatted = CodeFormatter.formatPython(raw);
      expect(formatted.endsWith('\n'), isTrue);
      expect(formatted.endsWith('\n\n'), isFalse);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('NamingConventions', () {
    test('toPythonClass converts correctly', () {
      expect(NamingConventions.toPythonClass('x_product_custom'),
          equals('XProductCustom'));
      expect(NamingConventions.toPythonClass('x_a'), equals('XA'));
    });

    test('toLabel converts correctly', () {
      expect(NamingConventions.toLabel('x_product_custom'),
          equals('X Product Custom'));
    });

    test('viewFileName produces correct name', () {
      expect(NamingConventions.viewFileName('x_order'),
          equals('x_order_view.xml'));
    });

    test('modelRefId replaces dots with underscores', () {
      expect(NamingConventions.modelRefId('x_product'),
          equals('model_x_product'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('GeneratorCache', () {
    test('stores and retrieves entries', () {
      final cache = GeneratorCache();
      cache.set('x_m', 'models/x_m.py', 'content1');
      expect(cache.get('x_m', 'models/x_m.py'), equals('content1'));
    });

    test('contains returns false for missing entries', () {
      final cache = GeneratorCache();
      expect(cache.contains('x_m', 'views/x_m_view.xml'), isFalse);
    });

    test('invalidate removes entries for a model', () {
      final cache = GeneratorCache()
        ..set('x_m', 'a', 'va')
        ..set('x_m', 'b', 'vb')
        ..set('x_other', 'a', 'vother');

      cache.invalidate('x_m');
      expect(cache.contains('x_m', 'a'), isFalse);
      expect(cache.contains('x_m', 'b'), isFalse);
      expect(cache.contains('x_other', 'a'), isTrue);
    });

    test('respects maxEntries (LRU eviction)', () {
      final cache = GeneratorCache(maxEntries: 3);
      cache.set('m1', 'f', 'v1');
      cache.set('m2', 'f', 'v2');
      cache.set('m3', 'f', 'v3');
      cache.set('m4', 'f', 'v4'); // should evict m1

      expect(cache.contains('m1', 'f'), isFalse);
      expect(cache.contains('m4', 'f'), isTrue);
      expect(cache.size, equals(3));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────

  group('StringUtils', () {
    test('escapeSingle escapes apostrophes', () {
      expect(StringUtils.escapeSingle("It's"), equals("It\\'s"));
    });

    test('escapeXml escapes < > & " entities', () {
      final result = StringUtils.escapeXml('<a>&"<');
      expect(result, contains('&lt;'));
      expect(result, contains('&gt;'));
      expect(result, contains('&amp;'));
      expect(result, contains('&quot;'));
    });

    test('isValidIdentifier rejects invalid strings', () {
      expect(StringUtils.isValidIdentifier('HelloWorld'), isFalse);
      expect(StringUtils.isValidIdentifier('123abc'), isFalse);
      expect(StringUtils.isValidIdentifier('valid_name'), isTrue);
    });
  });
}
