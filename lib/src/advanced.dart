/// Advanced Odoo integration: server actions, CLI bridge, and Odoo CLI helpers.
library odoo_model_generator.advanced;

import 'dart:io';

import 'package:logging/logging.dart';

import 'core/model_builder.dart';
import 'core/exceptions.dart';
import 'utils/naming_conventions.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ServerAction
// ─────────────────────────────────────────────────────────────────────────────

/// Metadata for an `ir.actions.server` record written into views XML.
class ServerAction {
  /// Display name shown in the action menu.
  final String name;

  /// Python method name called on the model.
  final String methodName;

  /// Whether the action appears in the list view action menu.
  final bool binding;

  /// Whether the action can run on multiple records.
  final bool multipleRecords;

  /// Optional condition domain (Python list expression).
  final String? domain;

  const ServerAction({
    required this.name,
    required this.methodName,
    this.binding = true,
    this.multipleRecords = true,
    this.domain,
  });

  /// Renders the `<record>` XML element for this server action.
  String toXML(String modelName) {
    final modelRef = NamingConventions.modelRefId(modelName);
    return '''    <record id="action_server_${methodName}" model="ir.actions.server">
        <field name="name">$name</field>
        <field name="model_id" ref="$modelRef"/>
        ${binding ? '<field name="binding_model_id" ref="$modelRef"/>' : ''}
        <field name="binding_type">action</field>
        <field name="code">
            action = records.$methodName()
        </field>
    </record>''';
  }

  /// Renders the Python method stub for this server action.
  String toPython() {
    final self = multipleRecords ? 'self' : 'self.ensure_one()';
    return '''    def $methodName(self):
        """$name — server action method."""
        $self
        # TODO: implement $methodName
        return {
            'type': 'ir.actions.act_window_close',
        }
''';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ServerActionMixin — extends OdooModel
// ─────────────────────────────────────────────────────────────────────────────

/// Extension on [OdooModel] to register server actions.
extension ServerActionExtension on OdooModel {
  static final _actions = Expando<List<ServerAction>>();

  List<ServerAction> get serverActions => _actions[this] ??= [];

  /// Registers a [ServerAction] on this model.
  OdooModel serverAction(ServerAction action) {
    (_actions[this] ??= []).add(action);
    return this;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  OdooCLIIntegration
// ─────────────────────────────────────────────────────────────────────────────

/// Bridges the generator output with a local Odoo installation.
///
/// Requires `odoo-bin` to be accessible on the system `PATH` or at
/// [odooBinPath].
class OdooCLIIntegration {
  static final Logger _log = Logger('OdooCLIIntegration');

  /// Path to `odoo-bin`. Defaults to system PATH lookup.
  final String odooBinPath;

  const OdooCLIIntegration({this.odooBinPath = 'odoo-bin'});

  // ── upgrade / install ─────────────────────────────────────────────────────

  /// Installs or upgrades [moduleName] on database [database].
  ///
  /// [install] — if `true` uses `-i`; otherwise `-u`.
  Future<ProcessResult> installOrUpgrade(
    String moduleName, {
    required String database,
    bool install = true,
    String? configFile,
    List<String> extraArgs = const [],
  }) async {
    final flag = install ? '-i' : '-u';
    final args = [
      flag,
      moduleName,
      '-d',
      database,
      '--stop-after-init',
      if (configFile != null) ...['-c', configFile],
      ...extraArgs,
    ];

    _log.info(
        'Running: $odooBinPath ${args.join(' ')}');

    final result = await Process.run(odooBinPath, args);

    if (result.exitCode != 0) {
      throw GenerationException(
        'odoo-bin exited with code ${result.exitCode}:\n${result.stderr}',
        hint: 'Check Odoo logs for details.',
      );
    }

    return result;
  }

  // ── scaffold check ────────────────────────────────────────────────────────

  /// Returns `true` if `odoo-bin` is accessible.
  Future<bool> isAvailable() async {
    try {
      final r = await Process.run(odooBinPath, ['--version']);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  GenerationReport
// ─────────────────────────────────────────────────────────────────────────────

/// Human-readable summary of a generation run.
class GenerationReport {
  final String modelName;
  final String outputPath;
  final List<String> writtenFiles;
  final Duration elapsed;

  const GenerationReport({
    required this.modelName,
    required this.outputPath,
    required this.writtenFiles,
    required this.elapsed,
  });

  /// Formats a compact ASCII report table.
  String render() {
    final buf = StringBuffer();
    buf.writeln('┌─────────────────────────────────────────────────────────┐');
    buf.writeln('│  odoo_model_generator — Generation Report               │');
    buf.writeln('├─────────────────────────────────────────────────────────┤');
    buf.writeln(
        '│  Model   : ${_pad(modelName, 43)}│');
    buf.writeln(
        '│  Output  : ${_pad(outputPath, 43)}│');
    buf.writeln(
        '│  Files   : ${_pad(writtenFiles.length.toString(), 43)}│');
    buf.writeln(
        '│  Elapsed : ${_pad('${elapsed.inMilliseconds}ms', 43)}│');
    buf.writeln('├─────────────────────────────────────────────────────────┤');
    for (final f in writtenFiles) {
      final rel = f.length > 43 ? '…${f.substring(f.length - 42)}' : f;
      buf.writeln('│  ✓ ${_pad(rel, 51)}│');
    }
    buf.writeln('└─────────────────────────────────────────────────────────┘');
    return buf.toString();
  }

  String _pad(String s, int width) =>
      s.length >= width ? s.substring(0, width) : s + (' ' * (width - s.length));
}
