/// Complex model example — full invoice system with compute, constraints, onchange.
/// Run with: flutter run example/complex_model.dart
library example_complex;

import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:odoo_model_generator/odoo_model_generator.dart' as odoo;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

void main() => runApp(const ComplexModelApp());

// ════════════════════════════════════════════════════════════════════════════
//  APP
// ════════════════════════════════════════════════════════════════════════════

class ComplexModelApp extends StatelessWidget {
  const ComplexModelApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Complex Model — Odoo Generator',
        debugShowCheckedModeBanner: false,
        theme: OdooTheme.dark(const Color(0xFF9FA8DA)),
        home: const ComplexModelPage(),
      );
}

// ════════════════════════════════════════════════════════════════════════════
//  PAGE
// ════════════════════════════════════════════════════════════════════════════

class ComplexModelPage extends StatefulWidget {
  const ComplexModelPage({super.key});
  @override
  State<ComplexModelPage> createState() => _ComplexModelPageState();
}

class _ComplexModelPageState extends State<ComplexModelPage>
    with SingleTickerProviderStateMixin {
  Map<String, String>? _files;
  bool _loading = true;
  String? _error;
  String _selected = '';
  late final AnimationController _fadeCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

  static const _accent = Color(0xFF9FA8DA);

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    try {
      // x_invoice_system: full ERP invoice with compute, constraints, onchange, SQL
      final model = odoo.OdooModel('x_invoice_system',
          docstring: 'Custom Invoice Management System',
          createTimestamp: true,
          order: 'invoice_date desc, name asc')
        ..dependency('account')
        ..dependency('sale')
        ..dependency('product')
        ..field(const odoo.NameField())
        ..field(const odoo.Many2one('partner_id',
            relation: 'res.partner', required: true, inTree: true))
        ..field(const odoo.Many2one('currency_id',
            relation: 'res.currency'))
        ..field(const odoo.Many2one('salesperson_id',
            relation: 'res.users'))
        ..field(const odoo.Many2one('pricelist_id',
            relation: 'product.pricelist'))
        ..field(const odoo.Selection('state', const [], rawOptions: [
          ('draft', 'Draft'),
          ('sent', 'Sent'),
          ('confirmed', 'Confirmed'),
          ('paid', 'Paid'),
          ('cancelled', 'Cancelled'),
          ('overdue', 'Overdue'),
        ], defaultValue: "'draft'"))
        ..field(const odoo.Selection('payment_terms', const [], rawOptions: [
          ('immediate', 'Immediate'),
          ('net15', 'Net 15'),
          ('net30', 'Net 30'),
          ('net60', 'Net 60'),
          ('net90', 'Net 90'),
        ], defaultValue: "'net30'"))
        ..field(odoo.Date('invoice_date'))
        ..field(odoo.Date('due_date'))
        ..field(const odoo.Float('subtotal', digits: (16, 2)))
        ..field(const odoo.Float('tax_amount', digits: (16, 2)))
        ..field(const odoo.Float('discount_amount', digits: (16, 2)))
        ..field(const odoo.Float('amount_paid', digits: (16, 2)))
        ..field(const odoo.Integer('payment_count'))
        ..field(const odoo.Text('notes'))
        ..field(const odoo.Text('internal_notes'))
        ..field(const odoo.Boolean('active', defaultValue: 'True'))
        ..field(const odoo.Boolean('is_recurring'))
        ..field(const odoo.Many2many('tag_ids', relation: 'account.analytic.tag'))
        // compute: total = subtotal + tax - discount
        ..compute(const odoo.ComputeDefinition(
          methodName: '_compute_total',
          dependsOn: ['subtotal', 'tax_amount', 'discount_amount'],
          bodyLines: [
            'for inv in self:',
            '    inv.total_amount = inv.subtotal + inv.tax_amount - inv.discount_amount',
          ],
        ))
        ..field(const odoo.ComputedField('total_amount',
            fieldType: 'Float',
            computeMethod: '_compute_total',
            store: true,
            depends: ['subtotal', 'tax_amount', 'discount_amount']))
        // compute: balance due
        ..compute(const odoo.ComputeDefinition(
          methodName: '_compute_balance',
          dependsOn: ['total_amount', 'amount_paid'],
          bodyLines: [
            'for inv in self:',
            '    inv.balance_due = inv.total_amount - inv.amount_paid',
          ],
        ))
        ..field(const odoo.ComputedField('balance_due',
            fieldType: 'Float',
            computeMethod: '_compute_balance',
            store: true,
            depends: ['total_amount', 'amount_paid']))
        // compute: is overdue
        ..compute(const odoo.ComputeDefinition(
          methodName: '_compute_is_overdue',
          dependsOn: ['due_date', 'state', 'balance_due'],
          bodyLines: [
            'today = fields.Date.today()',
            'for inv in self:',
            '    inv.is_overdue = (',
            '        inv.due_date and inv.due_date < today',
            '        and inv.state not in ("paid", "cancelled")',
            '        and inv.balance_due > 0',
            '    )',
          ],
        ))
        ..field(const odoo.ComputedField('is_overdue',
            fieldType: 'Boolean',
            computeMethod: '_compute_is_overdue',
            store: true,
            depends: ['due_date', 'state', 'balance_due']))
        // SQL constraints
        ..sqlConstraint('positive_subtotal',
            'CHECK(subtotal >= 0)', 'Subtotal cannot be negative')
        ..sqlConstraint('positive_tax',
            'CHECK(tax_amount >= 0)', 'Tax amount cannot be negative')
        ..sqlConstraint('valid_discount',
            'CHECK(discount_amount >= 0 AND discount_amount <= subtotal)',
            'Discount must be between 0 and subtotal')
        ..sqlConstraint('positive_paid',
            'CHECK(amount_paid >= 0)', 'Amount paid cannot be negative')
        ..sqlConstraint('unique_name', 'UNIQUE(name)', 'Invoice number must be unique');

      final gen = odoo.OdooGenerator(model,
          outputPath: '/tmp/x_invoice_system',
          config: const odoo.GeneratorConfig(
            author: 'Finance Team',
            version: '1.0.0',
            license: 'LGPL-3',
            generateSecurity: true,
            generateDemoStub: true,
          ));
      final files = Map<String, String>.from(gen.dryRun());
      final def = files.keys.firstWhere(
          (k) => k.contains('models/') && k.endsWith('.py'),
          orElse: () => files.keys.first);
      setState(() {
        _files = files;
        _selected = def;
        _loading = false;
      });
      _fadeCtrl.forward();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: OdooTheme.bg,
        appBar: OdooAppBar(
          modelId: 'x_invoice_system',
          title: 'Complex Model',
          accent: _accent,
          files: _files,
          onExport: _files == null
              ? null
              : () => ZipExporter.download(_files!, 'x_invoice_system'),
        ),
        body: _loading
            ? OdooLoading(accent: _accent)
            : _error != null
                ? OdooError(error: _error!)
                : FadeTransition(
                    opacity: _fadeCtrl,
                    child: IdeShell(
                      files: _files!,
                      selected: _selected,
                      accent: _accent,
                      onSelect: (k) => setState(() => _selected = k),
                    ),
                  ),
      );
}

// ════════════════════════════════════════════════════════════════════════════
//  SHARED LIBRARY  (identical in all 5 example files)
// ════════════════════════════════════════════════════════════════════════════

// ── Theme ────────────────────────────────────────────────────────────────────

abstract class OdooTheme {
  static const bg        = Color(0xFF0F0F17);
  static const surface   = Color(0xFF16161F);
  static const panel     = Color(0xFF1C1C28);
  static const border    = Color(0xFF2A2A3C);
  static const gutter    = Color(0xFF12121A);
  static const dimText   = Color(0xFF5A5A7A);
  static const mutedText = Color(0xFF7A7A9A);

  static ThemeData dark(Color seed) => ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0A0A12),
            foregroundColor: Color(0xFFE8E8F0),
            elevation: 0,
            surfaceTintColor: Colors.transparent),
        dividerTheme:
            const DividerThemeData(color: border, thickness: 1, space: 1),
      );
}

// ── ZIP Exporter ─────────────────────────────────────────────────────────────

abstract class ZipExporter {
  static void download(Map<String, String> files, String moduleName) {
    if (!kIsWeb) return;
    final archive = Archive();
    for (final e in files.entries) {
      final bytes = utf8.encode(e.value);
      archive.addFile(
          ArchiveFile('$moduleName/${e.key}', bytes.length, bytes));
    }
    final zipBytes = ZipEncoder().encode(archive)!;
    final blob = html.Blob(
        [Uint8List.fromList(zipBytes)], 'application/zip');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', '$moduleName.zip')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  static void downloadMulti(
      Map<String, Map<String, String>> modules, String zipName) {
    if (!kIsWeb) return;
    final archive = Archive();
    for (final mod in modules.entries) {
      for (final f in mod.value.entries) {
        final bytes = utf8.encode(f.value);
        archive.addFile(
            ArchiveFile('${mod.key}/${f.key}', bytes.length, bytes));
      }
    }
    final zipBytes = ZipEncoder().encode(archive)!;
    final blob = html.Blob(
        [Uint8List.fromList(zipBytes)], 'application/zip');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', '$zipName.zip')
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}

// ── AppBar ───────────────────────────────────────────────────────────────────

class OdooAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String modelId;
  final String title;
  final Color accent;
  final Map<String, String>? files;
  final VoidCallback? onExport;

  const OdooAppBar({
    super.key,
    required this.modelId,
    required this.title,
    required this.accent,
    this.files,
    this.onExport,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final totalLines = files == null
        ? 0
        : files!.values.fold<int>(0, (s, v) => s + v.split('\n').length);

    return AppBar(
      titleSpacing: 16,
      title: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              accent.withOpacity(0.25),
              accent.withOpacity(0.10),
            ]),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: accent.withOpacity(0.5)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.code, size: 12, color: accent),
            const SizedBox(width: 5),
            Text(modelId,
                style: TextStyle(
                    fontSize: 11,
                    color: accent,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3)),
          ]),
        ),
        const SizedBox(width: 12),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                color: Color(0xFFE8E8F0),
                fontWeight: FontWeight.w500)),
      ]),
      actions: [
        if (files != null) ...[
          _StatChip(
              icon: Icons.insert_drive_file_outlined,
              value: '${files!.length}',
              label: 'files',
              color: accent),
          const SizedBox(width: 6),
          _StatChip(
              icon: Icons.format_list_numbered_outlined,
              value: '$totalLines',
              label: 'lines',
              color: const Color(0xFF80DEEA)),
          const SizedBox(width: 10),
        ],
        if (onExport != null)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _ExportBtn(accent: accent, onExport: onExport!),
          ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatChip(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: color.withOpacity(0.7)),
          const SizedBox(width: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(width: 3),
          Text(label,
              style:
                  TextStyle(fontSize: 10, color: color.withOpacity(0.5))),
        ]),
      );
}

class _ExportBtn extends StatelessWidget {
  final Color accent;
  final VoidCallback onExport;
  const _ExportBtn({required this.accent, required this.onExport});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onExport,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                accent.withOpacity(0.22),
                accent.withOpacity(0.10),
              ]),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accent.withOpacity(0.45)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.folder_zip_outlined, size: 14, color: accent),
              const SizedBox(width: 6),
              Text('Export ZIP',
                  style: TextStyle(
                      fontSize: 12,
                      color: accent,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3)),
            ]),
          ),
        ),
      );
}

// ── IDE Shell ────────────────────────────────────────────────────────────────

class IdeShell extends StatelessWidget {
  final Map<String, String> files;
  final String selected;
  final Color accent;
  final void Function(String) onSelect;

  const IdeShell({
    super.key,
    required this.files,
    required this.selected,
    required this.accent,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
          width: 246,
          child: FileSidebar(
              files: files,
              selected: selected,
              accent: accent,
              onSelect: onSelect),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: CodeEditor(
              path: selected,
              content: files[selected] ?? '',
              accent: accent),
        ),
      ]);
}

// ── File Sidebar ─────────────────────────────────────────────────────────────

class FileSidebar extends StatelessWidget {
  final Map<String, String> files;
  final String selected;
  final Color accent;
  final void Function(String) onSelect;

  const FileSidebar({
    super.key,
    required this.files,
    required this.selected,
    required this.accent,
    required this.onSelect,
  });

  static _Ext _ext(String p) {
    if (p.endsWith('.py'))  return _Ext(const Color(0xFF4EC9B0), Icons.code,             'Python');
    if (p.endsWith('.xml')) return _Ext(const Color(0xFFE6A817), Icons.view_quilt,       'XML');
    if (p.endsWith('.csv')) return _Ext(const Color(0xFF4FC1FF), Icons.table_rows,       'CSV');
    return                         _Ext(OdooTheme.mutedText,     Icons.insert_drive_file, 'File');
  }

  @override
  Widget build(BuildContext context) => Container(
        color: OdooTheme.panel,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                decoration: const BoxDecoration(
                  color: OdooTheme.gutter,
                  border: Border(
                      bottom: BorderSide(color: OdooTheme.border)),
                ),
                child: Row(children: [
                  Icon(Icons.folder_open_rounded,
                      size: 13, color: accent.withOpacity(0.7)),
                  const SizedBox(width: 7),
                  Text('EXPLORER',
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.8,
                          color: accent.withOpacity(0.55),
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${files.length}',
                        style: TextStyle(
                            fontSize: 10,
                            color: accent,
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: files.entries.map((e) {
                    final sel = e.key == selected;
                    final ext = _ext(e.key);
                    final lines = e.value.split('\n').length;
                    return _FileRow(
                      path: e.key,
                      ext: ext,
                      lines: lines,
                      selected: sel,
                      accent: accent,
                      onTap: () => onSelect(e.key),
                    );
                  }).toList(),
                ),
              ),
            ]),
      );
}

class _Ext {
  final Color color;
  final IconData icon;
  final String label;
  const _Ext(this.color, this.icon, this.label);
}

class _FileRow extends StatelessWidget {
  final String path;
  final _Ext ext;
  final int lines;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _FileRow({
    required this.path,
    required this.ext,
    required this.lines,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: accent.withOpacity(0.05),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.12) : Colors.transparent,
          border: selected
              ? Border(
                  left: BorderSide(color: accent, width: 2.5),
                  right: BorderSide(
                      color: accent.withOpacity(0.08), width: 0))
              : const Border(
                  left: BorderSide(color: Colors.transparent, width: 2.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: ext.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(ext.icon, size: 13, color: ext.color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_fileName(path),
                      style: TextStyle(
                          fontSize: 12,
                          color: selected
                              ? const Color(0xFFE8E8F0)
                              : const Color(0xFFAAAAAC),
                          fontWeight: selected
                              ? FontWeight.w500
                              : FontWeight.normal),
                      overflow: TextOverflow.ellipsis),
                  if (_dir(path).isNotEmpty)
                    Text(_dir(path),
                        style: const TextStyle(
                            fontSize: 10, color: OdooTheme.dimText),
                        overflow: TextOverflow.ellipsis),
                ]),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: OdooTheme.gutter,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('$lines',
                style: const TextStyle(
                    fontSize: 10,
                    color: OdooTheme.dimText,
                    fontFamily: 'monospace')),
          ),
        ]),
      ),
    );
  }

  static String _fileName(String p) =>
      p.contains('/') ? p.split('/').last : p;
  static String _dir(String p) =>
      p.contains('/') ? p.substring(0, p.lastIndexOf('/')) : '';
}

// ── Code Editor ───────────────────────────────────────────────────────────────

class CodeEditor extends StatefulWidget {
  final String path;
  final String content;
  final Color accent;
  const CodeEditor(
      {super.key,
      required this.path,
      required this.content,
      required this.accent});
  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  late final ScrollController _vScroll = ScrollController();
  bool _copied = false;

  @override
  void dispose() {
    _vScroll.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.content));
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.content.split('\n');
    final isXml = widget.path.endsWith('.xml');
    final isCsv = widget.path.endsWith('.csv');

    return Column(children: [
      _TabBar(
          path: widget.path,
          accent: widget.accent,
          lines: lines.length,
          copied: _copied,
          onCopy: _copy),
      Expanded(
        child: Container(
          color: OdooTheme.bg,
          child: Scrollbar(
            controller: _vScroll,
            thumbVisibility: true,
            thickness: 6,
            radius: const Radius.circular(3),
            child: SingleChildScrollView(
              controller: _vScroll,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 56,
                        color: OdooTheme.gutter,
                        padding: const EdgeInsets.fromLTRB(0, 14, 10, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(
                            lines.length,
                            (i) => Text('${i + 1}',
                                style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    height: 1.65,
                                    color: OdooTheme.dimText)),
                          ),
                        ),
                      ),
                      Container(width: 1, color: OdooTheme.border),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 32, 28),
                        child: isXml
                            ? XmlView(content: widget.content)
                            : isCsv
                                ? CsvView(content: widget.content)
                                : PythonView(content: widget.content),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      _StatusBar(
          path: widget.path, lines: lines.length, accent: widget.accent),
    ]);
  }
}

// ── Tab Bar ───────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final String path;
  final Color accent;
  final int lines;
  final bool copied;
  final VoidCallback onCopy;
  const _TabBar(
      {required this.path,
      required this.accent,
      required this.lines,
      required this.copied,
      required this.onCopy});

  @override
  Widget build(BuildContext context) => Container(
        height: 38,
        color: OdooTheme.panel,
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            decoration: BoxDecoration(
              color: OdooTheme.bg,
              border: Border(
                  top: BorderSide(color: accent, width: 2),
                  right: const BorderSide(color: OdooTheme.border)),
            ),
            child: Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_tabIcon(path), size: 13, color: _tabColor(path)),
                const SizedBox(width: 6),
                Text(_name(path),
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFE8E8F0),
                        fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _CopyBtn(copied: copied, accent: accent, onCopy: onCopy),
          ),
        ]),
      );

  static IconData _tabIcon(String p) {
    if (p.endsWith('.py'))  return Icons.code;
    if (p.endsWith('.xml')) return Icons.view_quilt_rounded;
    if (p.endsWith('.csv')) return Icons.table_rows_rounded;
    return Icons.insert_drive_file_outlined;
  }

  static Color _tabColor(String p) {
    if (p.endsWith('.py'))  return const Color(0xFF4EC9B0);
    if (p.endsWith('.xml')) return const Color(0xFFE6A817);
    if (p.endsWith('.csv')) return const Color(0xFF4FC1FF);
    return OdooTheme.mutedText;
  }

  static String _name(String p) =>
      p.contains('/') ? p.split('/').last : p;
}

// ── Status Bar ────────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  final String path;
  final int lines;
  final Color accent;
  const _StatusBar(
      {required this.path, required this.lines, required this.accent});

  @override
  Widget build(BuildContext context) => Container(
        height: 24,
        color: accent.withOpacity(0.18),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Icon(Icons.check_circle_rounded,
              size: 11, color: accent.withOpacity(0.8)),
          const SizedBox(width: 6),
          Text(path,
              style: TextStyle(
                  fontSize: 10,
                  color: accent.withOpacity(0.7),
                  fontFamily: 'monospace')),
          const Spacer(),
          Text('$lines lines  ·  UTF-8',
              style: TextStyle(
                  fontSize: 10,
                  color: accent.withOpacity(0.5),
                  fontFamily: 'monospace')),
        ]),
      );
}

// ── Syntax Highlight: Python ──────────────────────────────────────────────────

class PythonView extends StatelessWidget {
  final String content;
  const PythonView({super.key, required this.content});

  static const _kw      = Color(0xFF569CD6);
  static const _builtin = Color(0xFF4EC9B0);
  static const _str     = Color(0xFFCE9178);
  static const _num     = Color(0xFFB5CEA8);
  static const _cmt     = Color(0xFF6A9955);
  static const _dec     = Color(0xFFDCDCAA);
  static const _op      = Color(0xFFD4D4D4);
  static const _self    = Color(0xFF9CDCFE);
  static const _attr    = Color(0xFF4FC1FF);

  static const _keywords = {
    'class', 'def', 'return', 'import', 'from', 'as', 'if', 'elif',
    'else', 'for', 'while', 'in', 'not', 'and', 'or', 'is', 'True',
    'False', 'None', 'raise', 'with', 'pass', 'lambda', 'try',
    'except', 'finally', 'yield', 'async', 'await', 'global', 'del',
  };

  @override
  Widget build(BuildContext context) => RichText(
        text: TextSpan(
          style: const TextStyle(
              fontFamily: 'monospace', fontSize: 13, height: 1.65, color: _op),
          children: _tokenize(content),
        ),
      );

  List<TextSpan> _tokenize(String src) {
    final spans = <TextSpan>[];
    final lines = src.split('\n');
    for (var li = 0; li < lines.length; li++) {
      spans.addAll(_tokenizeLine(lines[li]));
      if (li < lines.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return spans;
  }

  List<TextSpan> _tokenizeLine(String line) {
    final spans = <TextSpan>[];
    final stripped = line.trimLeft();
    if (stripped.startsWith('#')) {
      return [TextSpan(text: line, style: const TextStyle(color: _cmt))];
    }
    if (stripped.startsWith('@')) {
      return [TextSpan(text: line, style: const TextStyle(color: _dec))];
    }
    final pattern = RegExp(
        r"(#.*$)"
        r"|('(?:[^'\\]|\\.)*'"
        r'|"(?:[^"\\]|\\.)*")'
        r'|([0-9]+\.?[0-9]*)'
        r'|([a-zA-Z_]\w*)'
        r'|(\S|\s+)');
    for (final m in pattern.allMatches(line)) {
      final tok = m.group(0)!;
      if (m.group(1) != null) {
        spans.add(TextSpan(text: tok, style: const TextStyle(color: _cmt)));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(text: tok, style: const TextStyle(color: _str)));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(text: tok, style: const TextStyle(color: _num)));
      } else if (m.group(4) != null) {
        Color c = _op;
        if (_keywords.contains(tok)) c = _kw;
        else if (tok == 'self' || tok == 'cls') c = _self;
        else if (tok[0] == tok[0].toUpperCase() && tok.length > 1) c = _builtin;
        else if (tok.startsWith('_') && !tok.startsWith('__')) c = _attr;
        spans.add(TextSpan(text: tok, style: TextStyle(color: c)));
      } else {
        spans.add(TextSpan(text: tok, style: const TextStyle(color: _op)));
      }
    }
    return spans;
  }
}

// ── Syntax Highlight: XML ─────────────────────────────────────────────────────

class XmlView extends StatelessWidget {
  final String content;
  const XmlView({super.key, required this.content});

  static const _tag     = Color(0xFF4EC9B0);
  static const _attr    = Color(0xFF9CDCFE);
  static const _str     = Color(0xFFCE9178);
  static const _cmt     = Color(0xFF6A9955);
  static const _bracket = Color(0xFF808080);
  static const _text    = Color(0xFFD4D4D4);

  @override
  Widget build(BuildContext context) => RichText(
        text: TextSpan(
          style: const TextStyle(
              fontFamily: 'monospace', fontSize: 13, height: 1.65),
          children: _tokenize(content),
        ),
      );

  List<TextSpan> _tokenize(String src) {
    final spans = <TextSpan>[];
    final pat = RegExp(
        r'(<!--.*?-->)'
        r'|(</?[a-zA-Z][^>]*?>)'
        r'|([^<]+)',
        dotAll: true);
    for (final m in pat.allMatches(src)) {
      if (m.group(1) != null) {
        spans.add(TextSpan(
            text: m.group(1), style: const TextStyle(color: _cmt)));
      } else if (m.group(2) != null) {
        spans.addAll(_tokenizeTag(m.group(2)!));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(
            text: m.group(3), style: const TextStyle(color: _text)));
      }
    }
    return spans;
  }

  List<TextSpan> _tokenizeTag(String tag) {
    final spans = <TextSpan>[];
    final pat = RegExp(
        r'([<>/]+)'
        r'|([a-zA-Z_:][^\s=/>]*)'
        r'|("(?:[^"\\]|\\.)*")'
        r"('(?:[^'\\]|\\.)*')"   // single-quoted strings
        r'|(\"(?:[^\"\\\\]|\\\\.)*\")'   // double-quoted strings
        r'|(=)'
        r'|(\s+)');
    bool first = true;
    for (final m in pat.allMatches(tag)) {
      final tok = m.group(0)!;
      if (m.group(1) != null) {
        spans.add(TextSpan(text: tok, style: const TextStyle(color: _bracket)));
      } else if (m.group(2) != null) {
        final c = first ? _tag : _attr;
        first = false;
        spans.add(TextSpan(text: tok, style: TextStyle(color: c)));
      } else if (m.group(3) != null || m.group(4) != null) {
        spans.add(TextSpan(text: tok, style: const TextStyle(color: _str)));
      } else {
        spans.add(TextSpan(text: tok, style: const TextStyle(color: _text)));
      }
    }
    return spans;
  }
}

// ── Syntax Highlight: CSV ─────────────────────────────────────────────────────

class CsvView extends StatelessWidget {
  final String content;
  const CsvView({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    final spans = <TextSpan>[];
    for (var i = 0; i < lines.length; i++) {
      final cols = lines[i].split(',');
      for (var j = 0; j < cols.length; j++) {
        final isHeader = i == 0;
        final col = cols[j];
        final isNum = RegExp(r'^\d+$').hasMatch(col.trim());
        Color c = const Color(0xFFD4D4D4);
        if (isHeader) c = const Color(0xFF4EC9B0);
        else if (isNum) c = const Color(0xFFB5CEA8);
        else if (col.contains('.')) c = const Color(0xFF9CDCFE);
        spans.add(TextSpan(text: col, style: TextStyle(color: c)));
        if (j < cols.length - 1) {
          spans.add(const TextSpan(
              text: ',', style: TextStyle(color: Color(0xFF808080))));
        }
      }
      if (i < lines.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(
            fontFamily: 'monospace', fontSize: 13, height: 1.65),
        children: spans,
      ),
    );
  }
}

// ── Loading / Error ───────────────────────────────────────────────────────────

class OdooLoading extends StatelessWidget {
  final Color accent;
  const OdooLoading({super.key, required this.accent});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(color: accent, strokeWidth: 2.5),
          ),
          const SizedBox(height: 20),
          Text('Generating Odoo module…',
              style: TextStyle(
                  color: accent.withOpacity(0.7),
                  fontSize: 14,
                  letterSpacing: 0.3)),
          const SizedBox(height: 6),
          Text('Running validators & templates',
              style:
                  TextStyle(color: OdooTheme.dimText, fontSize: 12)),
        ]),
      );
}

class OdooError extends StatelessWidget {
  final String error;
  const OdooError({super.key, required this.error});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.all(40),
          padding: const EdgeInsets.all(28),
          constraints: const BoxConstraints(maxWidth: 700),
          decoration: BoxDecoration(
            color: const Color(0xFF1A0808),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: Colors.red.shade800.withOpacity(0.7)),
          ),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.error_outline_rounded,
                      color: Colors.red.shade400, size: 20),
                  const SizedBox(width: 10),
                  Text('Generation Error',
                      style: TextStyle(
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                ]),
                const SizedBox(height: 16),
                SelectableText(error,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.6,
                        color: Color(0xFFE8E8F0))),
              ]),
        ),
      );
}

// ── Copy Button ───────────────────────────────────────────────────────────────

class _CopyBtn extends StatelessWidget {
  final bool copied;
  final Color accent;
  final VoidCallback onCopy;
  const _CopyBtn(
      {required this.copied, required this.accent, required this.onCopy});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onCopy,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: copied ? accent.withOpacity(0.18) : OdooTheme.panel,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color:
                    copied ? accent.withOpacity(0.6) : OdooTheme.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
                copied
                    ? Icons.check_rounded
                    : Icons.content_copy_rounded,
                size: 13,
                color: copied ? accent : OdooTheme.mutedText),
            const SizedBox(width: 5),
            Text(copied ? 'Copied!' : 'Copy',
                style: TextStyle(
                    fontSize: 11,
                    color: copied ? accent : OdooTheme.mutedText)),
          ]),
        ),
      );
}
