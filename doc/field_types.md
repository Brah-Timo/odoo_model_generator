# Field Types Reference

Every field is `const`-constructable, `@immutable`, and extends `OdooField`.
All fields share a common set of base parameters described first, followed by
type-specific parameters.

---

## Common base parameters

All field classes accept these named parameters:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `string` | `String?` | auto-label | Human-readable label shown in the UI. If omitted, the field `name` is title-cased automatically. |
| `required` | `bool` | `false` | Emits `required=True` in Python. |
| `defaultValue` | `dynamic` | `null` | Emits `default=…` in Python. Accepts `String`, `bool`, `num`, or `List`. |
| `help` | `String?` | `null` | Tooltip text (`help='…'` in Python). |
| `inTree` | `bool` | `false` | Include field in the generated tree/list view. |
| `inSearch` | `bool` | `false` | Include field in the generated search view. |
| `readonly` | `bool` | `false` | Emits `readonly=True` in Python and `readonly="1"` in XML. |
| `cssClass` | `String?` | `null` | CSS class added to the form-view `<field>` element. |
| `extra` | `Map<String, String>` | `{}` | Arbitrary extra Python kwargs appended verbatim to the field declaration. |

---

## Scalar fields

### `Char` — short text

Maps to `fields.Char`.

```dart
const Char(
  'code',
  required: true,
  size: 10,
  translate: false,
  inTree: true,
  inSearch: true,
)
```

| Extra parameter | Type | Default | Description |
|-----------------|------|---------|-------------|
| `size` | `int?` | `null` | Maximum character length (`size=N`). |
| `translate` | `bool` | `false` | Enable Odoo field-level translations (`translate=True`). |

---

### `Text` — long text

Maps to `fields.Text`.

```dart
const Text('notes', translate: true)
```

| Extra parameter | Type | Default | Description |
|-----------------|------|---------|-------------|
| `translate` | `bool` | `false` | Enable field-level translations. |

The form-view element is rendered with `nolabel="1"` (no inline label).

---

### `Html` — rich-text HTML

Maps to `fields.Html`.

```dart
const Html('body', sanitize: true)
```

| Extra parameter | Type | Default | Description |
|-----------------|------|---------|-------------|
| `sanitize` | `bool` | `true` | Set `sanitize=False` to disable Odoo HTML sanitization. |

---

### `Integer`

Maps to `fields.Integer`.

```dart
const Integer('quantity', required: true, defaultValue: 0, inTree: true)
```

No type-specific parameters beyond the common ones.

---

### `Float` — double-precision float

Maps to `fields.Float`.

```dart
const Float('price', digits: (10, 2), inTree: true)
```

| Extra parameter | Type | Default | Description |
|-----------------|------|---------|-------------|
| `digits` | `(int, int)?` | `null` | Dart record tuple `(totalDigits, decimalDigits)` → `digits=(10, 2)`. |

---

### `Monetary` — currency-aware amount

Maps to `fields.Monetary`.  Requires a `Many2one` to `res.currency` (default field name `currency_id`) on the same model.

```dart
const Monetary('amount', currencyField: 'currency_id')
```

| Extra parameter | Type | Default | Description |
|-----------------|------|---------|-------------|
| `currencyField` | `String` | `'currency_id'` | Name of the companion currency Many2one field. |

---

### `Boolean` — checkbox

Maps to `fields.Boolean`.

```dart
const Boolean('is_active', defaultValue: true)
```

---

### `Date` — calendar date

Maps to `fields.Date`.

```dart
const Date('deadline', required: true, inTree: true)
```

---

### `Datetime` — date + time (UTC)

Maps to `fields.Datetime`.

```dart
const Datetime('scheduled_at')
```

---

### `Binary` — file attachment (base64)

Maps to `fields.Binary`.

```dart
const Binary('document', attachment: true)
```

| Extra parameter | Type | Default | Description |
|-----------------|------|---------|-------------|
| `attachment` | `bool` | `true` | Set `false` to store binary inline in the database column instead of `ir.attachment`. |

The form-view element uses `widget="binary"`.

---

### `Image` — image (base64)

Maps to `fields.Image`.

```dart
const Image('photo', maxWidth: 256, maxHeight: 256)
```

| Extra parameter | Type | Default | Description |
|-----------------|------|---------|-------------|
| `maxWidth` | `int` | `1920` | Maximum image width in pixels. |
| `maxHeight` | `int` | `1920` | Maximum image height in pixels. |

The form-view element uses `widget="image"`.

---

## Enumeration fields

### `Selection` — drop-down list

Maps to `fields.Selection`.

```dart
// Simple options (key = display value, auto-capitalized)
const Selection(
  'state',
  ['draft', 'confirmed', 'paid'],
  defaultValue: 'draft',
  inTree: true,
)

// Explicit key/label pairs via rawOptions
const Selection(
  'priority',
  [],
  rawOptions: [
    ('0', 'Normal'),
    ('1', 'High'),
    ('2', 'Very High'),
  ],
)
```

| Extra parameter | Type | Default | Description |
|-----------------|------|---------|-------------|
| `options` | `List<String>` | required | Simple value list; labels are auto-generated. |
| `rawOptions` | `List<(String, String)>?` | `null` | Explicit `(key, label)` pairs — takes precedence over `options`. |

The form-view element uses `widget="statusbar"`.  
The search-view element emits a `<filter>` for the first option value.

---

## Relational fields

### `Many2one` — foreign key

Maps to `fields.Many2one`.

```dart
const Many2one(
  'partner_id',
  relation: 'res.partner',
  required: true,
  ondelete: 'restrict',
  onchange: true,
  domain: "[('customer_rank', '>', 0)]",
  inTree: true,
  inSearch: true,
)
```

| Extra parameter | Type | Default | Description |
|-----------------|------|---------|-------------|
| `relation` | `String` | required | Target model technical name. |
| `ondelete` | `String` | `'set null'` | PostgreSQL delete cascade policy: `'set null'`, `'restrict'`, or `'cascade'`. |
| `onchange` | `bool` | `false` | Emits an `@api.onchange` stub for this field. |
| `domain` | `String?` | `null` | Domain filter applied in the UI picker. |

---

### `One2many` — inverse of a Many2one

Maps to `fields.One2many`.

```dart
const One2many(
  'order_line_ids',
  relation: 'x_order_line',
  inverseField: 'order_id',
)
```

| Extra parameter | Type | Default | Description |
|-----------------|------|---------|-------------|
| `relation` | `String` | required | Target model technical name. |
| `inverseField` | `String` | required | Name of the `Many2one` field on the target model that points back. |

The form-view element uses `widget="one2many_list"`.

---

### `Many2many` — many-to-many

Maps to `fields.Many2many`.

```dart
const Many2many(
  'tag_ids',
  relation: 'res.partner.category',
  relationTable: 'x_task_tag_rel',
  column1: 'task_id',
  column2: 'tag_id',
)
```

| Extra parameter | Type | Default | Description |
|-----------------|------|---------|-------------|
| `relation` | `String` | required | Target model technical name. |
| `relationTable` | `String?` | auto (`rel_<name>`) | Explicit pivot table name. |
| `column1` | `String` | `'left_id'` | Column pointing to the current model. |
| `column2` | `String` | `'right_id'` | Column pointing to the related model. |

The form-view element uses `widget="many2many_tags"`.

---

## Computed fields

### `ComputedField`

Maps to any Odoo field type with `compute=…`.

```dart
const ComputedField(
  'total_price',
  fieldType: 'Float',
  computeMethod: '_compute_total_price',
  store: true,
  depends: ['price', 'quantity'],
  digits: (10, 2),
  readonly: true,
)
```

| Extra parameter | Type | Default | Description |
|-----------------|------|---------|-------------|
| `fieldType` | `String` | `'Float'` | Odoo Python type name: `'Float'`, `'Integer'`, `'Char'`, etc. |
| `computeMethod` | `String` | required | Name of the Python compute method. |
| `store` | `bool` | `false` | Set `store=True` to persist the computed value. |
| `depends` | `List<String>` | `[]` | Fields that trigger recomputation (used by `@api.depends`). |
| `digits` | `(int, int)?` | `null` | Precision for Float-type computed fields. |

---

## Convenience pseudo-fields

### `NameField`

A convenience wrapper for the canonical `name` field (`Char('name', required: true, inTree: true, inSearch: true)`).

```dart
const NameField()                          // → name field named 'name'
const NameField(fieldName: 'ref',
                string: 'Reference')       // → renamed to 'ref'
const NameField(translate: true)           // → translated name
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `fieldName` | `String` | `'name'` | Technical field name (useful if the model uses a different string field). |
| `string` | `String` | `'Name'` | Display label. |
| `translate` | `bool` | `false` | Enable field translations. |

---

### `Reference`

Maps to `fields.Reference` — a dynamic relation that can point to any of the listed models.

```dart
const Reference(
  'ref_document',
  allowedModels: ['sale.order', 'purchase.order', 'stock.picking'],
)
```

| Extra parameter | Type | Default | Description |
|-----------------|------|---------|-------------|
| `allowedModels` | `List<String>` | required | List of model technical names shown in the relation picker. |

---

## Reserved field names

The following field names are managed by Odoo's ORM and **must not** be declared manually.  
Attempting to add them throws `ReservedFieldException`.

```dart
const kReservedOdooFieldNames = {
  'id', 'create_date', 'write_date',
  'create_uid', 'write_uid',
  'display_name', '__last_update',
};
```
