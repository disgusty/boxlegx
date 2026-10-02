// Маршрутизация сайтов (Routing → Sites) — доменный split-tunneling по образцу
// Amnezia VPN: Выключено / Белый список (только эти сайты через VPN) / Чёрный
// список (эти сайты мимо VPN). Устройство вкладки — зеркало TunAppsTab
// (LazyPersistMixin, глобальный баннер «Apply / Restart»).
//
// Builder applyRouteSites() переводит список в route-правило ядра.
// Импорт/экспорт списка — JSON формата Amnezia VPN (`[{"hostname", "ip"}]`),
// импорт понимает ещё и простой текст (по записи в строке).

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/home_controller.dart';
import '../controllers/subscription_controller.dart';
import '../services/error_format.dart';
import '../services/file_export.dart';
import '../services/file_import.dart';
import '../services/settings_storage.dart'
    show RouteSitesConfig, SettingsStorage;
import '../services/ui_helpers.dart';
import '../services/url_launcher.dart';
import '../services/utf8_decode.dart';
import '../widgets/export_action_sheet.dart';
import 'lazy_persist_mixin.dart';
import '../services/l10n/locale_controller.dart';

class RouteSitesTab extends StatefulWidget {
  const RouteSitesTab({
    super.key,
    required this.homeController,
    required this.subController,
  });

  final HomeController homeController;
  final SubscriptionController subController;

  @override
  State<RouteSitesTab> createState() => _RouteSitesTabState();
}

class _RouteSitesTabState extends State<RouteSitesTab>
    with
        WidgetsBindingObserver,
        LazyPersistMixin<RouteSitesTab>,
        SnackHelper<RouteSitesTab> {
  RouteSitesConfig _cfg =
      const RouteSitesConfig(mode: 'off', sites: <String>[]);
  bool _loading = true;
  String _filter = '';

  @override
  SubscriptionController get lazyController => widget.subController;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final cfg = await SettingsStorage.getRouteSites();
    if (!mounted) return;
    setState(() {
      _cfg = cfg;
      _loading = false;
    });
  }

  @override
  Future<void> stageChanges() async {
    await SettingsStorage.setRouteSites(_cfg, flush: false);
  }

  void _setMode(String mode) {
    setState(() => _cfg = _cfg.copyWith(mode: mode));
    markDirty();
  }

  /// Добавляет записи, возвращает число реально новых.
  int _addAll(Iterable<String> raw, {bool replace = false}) {
    final next = replace ? <String>{} : _cfg.sites.toSet();
    final before = next.length;
    for (final r in raw) {
      final n = RouteSitesConfig.normalize(r);
      if (n != null) next.add(n);
    }
    setState(() => _cfg = _cfg.copyWith(sites: next.toList()..sort()));
    markDirty();
    return next.length - before;
  }

  void _remove(String site) {
    setState(() => _cfg =
        _cfg.copyWith(sites: _cfg.sites.where((s) => s != site).toList()));
    markDirty();
  }

  static List<String> _splitInput(String text) =>
      RouteSitesConfig.splitInput(text);

  Future<void> _addDialog() async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(getLocalText.s("Add sites")),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 1,
          maxLines: 6,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: getLocalText.s("example.com, 1.2.3.4, 10.0.0.0/8"),
            helperText: getLocalText.s("Several entries — separate with spaces, commas or new lines"),
            helperMaxLines: 2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(getLocalText.s("Cancel")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(getLocalText.s("Add")),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null || !mounted) return;
    final parts = _splitInput(text);
    if (parts.isEmpty) return;
    final valid = parts.where((p) => RouteSitesConfig.normalize(p) != null);
    final skipped = parts.length - valid.length;
    _addAll(valid);
    if (skipped > 0) {
      showSnack(getLocalText.s("Skipped invalid entries: %d", skipped));
    }
  }

  void _clearAll() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(getLocalText.s("Clear all sites?")),
        content: Text(getLocalText.s("Remove all %d sites from the list. The mode is kept.", _cfg.sites.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(getLocalText.s("Cancel")),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _cfg = _cfg.copyWith(sites: const <String>[]));
              markDirty();
            },
            child: Text(getLocalText.s("Clear")),
          ),
        ],
      ),
    );
  }

  Future<void> _import() async {
    try {
      final outcome = await pickFileSafely();
      if (outcome is! PickedFiles) {
        final problem = pickProblemText(outcome);
        if (problem != null) showSnack(problem);
        return;
      }
      final raw = utf8DecodeOrNull(outcome.single.bytes);
      if (raw == null) {
        showSnack(getLocalText.s("Could not read file."));
        return;
      }
      final entries = RouteSitesConfig.parseList(raw)
          .where((e) => RouteSitesConfig.normalize(e) != null)
          .toList();
      if (entries.isEmpty) {
        showSnack(getLocalText.s("No sites found in the file."));
        return;
      }
      if (!mounted) return;
      var replace = false;
      if (_cfg.sites.isNotEmpty) {
        final choice = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(getLocalText.s("Import sites")),
            content: Text(getLocalText.s("Found %d sites in the file.", entries.length)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(getLocalText.s("Cancel")),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(getLocalText.s("Replace list")),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(getLocalText.s("Add to list")),
              ),
            ],
          ),
        );
        if (choice == null || !mounted) return;
        replace = choice;
      }
      final added = _addAll(entries, replace: replace);
      showSnack(getLocalText.s("Imported sites: %d", replace ? _cfg.sites.length : added));
    } catch (e) {
      showSnack(getLocalText.s("Import failed: %s", formatUserError(e).render()));
    }
  }

  Future<void> _export() async {
    if (_cfg.sites.isEmpty) return;
    final json = RouteSitesConfig.toAmneziaJson(_cfg.sites);
    const filename = 'sites.json';
    try {
      final availability = await Future.wait([
        UrlLauncher.hasRealFilePicker(),
        UrlLauncher.canSaveToDownloads(),
      ]);
      if (!mounted) return;
      final action = await showExportActionSheet(
        context,
        canSaveToFile: availability[0],
        canSaveToDownloads: availability[1],
      );
      if (action == null) return;
      final SaveOutcome outcome;
      switch (action) {
        case ExportAction.saveToFile:
          outcome = await saveFileSafely(fileName: filename, content: json);
        case ExportAction.saveToDownloads:
          outcome = await saveToDownloadsSafely(fileName: filename, content: json);
        case ExportAction.share:
          final tmpDir = await getTemporaryDirectory();
          final path = '${tmpDir.path}/$filename';
          await File(path).writeAsString(json);
          await Share.shareXFiles(
            [XFile(path, mimeType: 'application/json', name: filename)],
            subject: 'LxBox sites',
          );
          return;
      }
      final problem = saveProblemText(outcome);
      if (problem != null) {
        showSnack(problem);
        return;
      }
      if (outcome is SavedToFile || outcome is SavedToDownloads) {
        showSnack(getLocalText.s("Sites exported"));
      }
    } catch (e) {
      showSnack(getLocalText.s("Export failed: %s", formatUserError(e).render()));
    }
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(getLocalText.s("Sites — split tunneling by address")),
        content: SingleChildScrollView(
          child: Text(getLocalText.s("Choose which websites go through the VPN.\n\n• Off — sites are routed by your normal rules (default)\n• Allow-list — ONLY listed sites go through VPN; everything else goes directly\n• Deny-list — listed sites go directly; everything else goes through VPN\n\nA domain also covers all of its subdomains (example.com matches www.example.com). IP addresses and subnets (10.0.0.0/8) are supported too.\n\nThe list works inside the core, so it also applies in Proxy mode. Changes apply after the core restarts or reloads from the home screen banner.\n\nImport and export use the Amnezia VPN site list format (JSON); plain text files with one site per line can be imported too.")),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(getLocalText.s("OK")),
          ),
        ],
      ),
    );
  }

  String _modeDescription(String mode) => switch (mode) {
        'allow' => getLocalText.s("Only listed sites go through VPN. Everything else goes directly."),
        'deny' => getLocalText.s("Listed sites go directly. Everything else goes through VPN."),
        _ => getLocalText.s("Sites are routed by the normal rules (default)."),
      };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottomPad = MediaQuery.of(context).padding.bottom + 24;
    final shown = _filter.isEmpty
        ? _cfg.sites
        : _cfg.sites.where((s) => s.contains(_filter)).toList();

    // ListView.builder: список сайтов бывает на тысячи записей (импорт из
    // Amnezia) — строим только видимые строки.
    final header = <Widget>[
      Row(
        children: [
          Text(getLocalText.s("Mode"), style: tt.titleMedium),
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: getLocalText.s("More"),
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              switch (v) {
                case 'import':
                  unawaited(_import());
                case 'export':
                  unawaited(_export());
                case 'clear':
                  _clearAll();
                case 'help':
                  _showHelp();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'import',
                  child: Text(getLocalText.s("Import from file"))),
              PopupMenuItem(
                  value: 'export',
                  enabled: _cfg.sites.isNotEmpty,
                  child: Text(getLocalText.s("Export to file"))),
              const PopupMenuDivider(),
              PopupMenuItem(
                  value: 'clear',
                  enabled: _cfg.sites.isNotEmpty,
                  child: Text(getLocalText.s("Clear all"))),
              PopupMenuItem(
                  value: 'help', child: Text(getLocalText.s("Help"))),
            ],
          ),
        ],
      ),
      const SizedBox(height: 8),
      SegmentedButton<String>(
        segments: [
          ButtonSegment(value: 'off', label: Text(getLocalText.s("Off"))),
          ButtonSegment(
              value: 'allow', label: Text(getLocalText.s("Allow-list"))),
          ButtonSegment(
              value: 'deny', label: Text(getLocalText.s("Deny-list"))),
        ],
        selected: {_cfg.mode},
        onSelectionChanged: (s) => _setMode(s.first),
      ),
      const SizedBox(height: 8),
      Text(
        _modeDescription(_cfg.mode),
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      if (!_cfg.isOff) ...[
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                getLocalText.s("Sites in this list (%d)", _cfg.sites.length),
                style: tt.titleMedium,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _addDialog,
              icon: const Icon(Icons.add, size: 18),
              label: Text(getLocalText.s("Add site")),
            ),
          ],
        ),
        if (_cfg.sites.length > 10) ...[
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: getLocalText.s("Search"),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
          ),
        ],
        const SizedBox(height: 8),
        if (_cfg.sites.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              getLocalText.s("No sites yet. Tap \"Add site\" or import a list."),
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
      ],
    ];
    final rows = _cfg.isOff ? const <String>[] : shown;

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
      itemCount: header.length + rows.length,
      itemBuilder: (context, i) {
        if (i < header.length) return header[i];
        final site = rows[i - header.length];
        final ip = RouteSitesConfig.isIp(site);
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(ip ? Icons.lan_outlined : Icons.language,
              color: cs.onSurfaceVariant),
          title: Text(site),
          trailing: IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: getLocalText.s("Remove"),
            onPressed: () => _remove(site),
          ),
        );
      },
    );
  }
}
