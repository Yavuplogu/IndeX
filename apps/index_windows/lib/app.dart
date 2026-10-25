import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:index_core/index_core.dart';
import 'package:index_core/index_desktop.dart';
import 'package:window_manager/window_manager.dart';

import 'app_model.dart';
import 'window_port.dart';

typedef DirectoryPicker = Future<String?> Function();
Future<String?> nativeDirectoryPicker() =>
    getDirectoryPath(confirmButtonText: 'Choisir ce dossier');

final class EditorialColors {
  EditorialColors(bool dark)
    : background = dark ? const Color(0xff1b1918) : const Color(0xfff5f1e9),
      panel = dark ? const Color(0xff252220) : const Color(0xfffffcf6),
      controls = dark ? const Color(0xff36302a) : const Color(0xffeee4d4),
      ink = dark ? const Color(0xfff0e8df) : const Color(0xff302b26),
      muted = dark ? const Color(0xffc2b7ac) : const Color(0xff6f6357),
      accent = dark ? const Color(0xffe5ad8e) : const Color(0xff99533d),
      line = dark ? const Color(0xff50463f) : const Color(0xffe4dcd0),
      missing = dark ? const Color(0xff33302d) : const Color(0xffeeece8),
      missingInk = dark ? const Color(0xffb2aba3) : const Color(0xff77716a),
      alert = dark ? const Color(0xffffa99c) : const Color(0xff922f2a),
      heard = dark ? const Color(0xff393345) : const Color(0xfff0edf9),
      heardInk = dark ? const Color(0xffd0c3ff) : const Color(0xff56509b);
  final Color background,
      panel,
      controls,
      ink,
      muted,
      accent,
      line,
      missing,
      missingInk,
      alert,
      heard,
      heardInk;
}

String dateLabel(String? value) {
  if (value == null) return 'Date non renseignée';
  final p = value.split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : value;
}

String statusLabel(String value) => switch (value) {
  'ECOUTE' => 'Écouté',
  'EN_COURS' => 'En cours',
  _ => 'Non écouté',
};
IconData statusIcon(String value) => switch (value) {
  'ECOUTE' => Icons.check_circle_outline,
  'EN_COURS' => Icons.timelapse,
  _ => Icons.radio_button_unchecked,
};
const sortNames = {
  CatalogSort.relevance: 'Pertinence',
  CatalogSort.dateNew: 'Diffusion · Plus récent',
  CatalogSort.dateOld: 'Diffusion · Plus ancien',
  CatalogSort.titleAZ: 'Titre · A → Z',
  CatalogSort.titleZA: 'Titre · Z → A',
  CatalogSort.audioFirst: 'MP3 · Disponibles d’abord',
  CatalogSort.audioLast: 'MP3 · Absents d’abord',
};
const fieldNames = {
  SearchField.title: 'Titre',
  SearchField.description: 'Résumé',
  SearchField.sources: 'Sources',
  SearchField.music: 'Musiques',
};

class IndeXApp extends StatefulWidget {
  const IndeXApp({
    super.key,
    required this.model,
    required this.window,
    this.pickDirectory = nativeDirectoryPicker,
    this.nativeWindow = false,
  });
  final AppModel model;
  final WindowPort window;
  final DirectoryPicker pickDirectory;
  final bool nativeWindow;
  @override
  State<IndeXApp> createState() => _IndeXAppState();
}

class _IndeXAppState extends State<IndeXApp> with WindowListener {
  final navigator = GlobalKey<NavigatorState>();
  bool closing = false;
  bool closeErrorDialog = false;
  AppModel get m => widget.model;
  @override
  void initState() {
    super.initState();
    if (widget.nativeWindow) windowManager.addListener(this);
  }

  @override
  void dispose() {
    if (widget.nativeWindow) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() {
    unawaited(close());
  }

  Future<void> close() async {
    if (closing || closeErrorDialog) return;
    setState(() => closing = true);
    try {
      await m.closeSafely();
      await widget.window.destroy();
    } catch (e) {
      if (!mounted) return;
      setState(() => closing = false);
      closeErrorDialog = true;
      final retry = await showDialog<bool>(
        context: navigator.currentContext!,
        builder: (context) => AlertDialog(
          title: const Text('Sauvegarde impossible'),
          content: Text(
            'La fenêtre reste ouverte. Vos données ne sont pas annoncées comme sauvegardées.\n\n$e',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
      closeErrorDialog = false;
      if (mounted) setState(() => closing = false);
      if (retry == true) await close();
      return;
    }
    if (mounted) setState(() => closing = false);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: m,
    builder: (context, _) {
      final c = EditorialColors(m.dark);
      final theme = ThemeData(
        useMaterial3: true,
        brightness: m.dark ? Brightness.dark : Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: c.accent,
          brightness: m.dark ? Brightness.dark : Brightness.light,
          surface: c.panel,
        ),
        scaffoldBackgroundColor: c.panel,
        dialogTheme: DialogThemeData(backgroundColor: c.controls),
        textButtonTheme: const TextButtonThemeData(
          style: ButtonStyle(mouseCursor: WidgetStateMouseCursor.clickable),
        ),
        outlinedButtonTheme: const OutlinedButtonThemeData(
          style: ButtonStyle(mouseCursor: WidgetStateMouseCursor.clickable),
        ),
        filledButtonTheme: const FilledButtonThemeData(
          style: ButtonStyle(mouseCursor: WidgetStateMouseCursor.clickable),
        ),
        iconButtonTheme: const IconButtonThemeData(
          style: ButtonStyle(mouseCursor: WidgetStateMouseCursor.clickable),
        ),
        checkboxTheme: const CheckboxThemeData(
          mouseCursor: WidgetStateMouseCursor.clickable,
        ),
        dividerColor: c.line,
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          filled: true,
          fillColor: c.background,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        textTheme: ThemeData(
          brightness: m.dark ? Brightness.dark : Brightness.light,
        ).textTheme.apply(bodyColor: c.ink, displayColor: c.ink),
      );
      return MaterialApp(
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(minScaleFactor: 1.08),
            ),
            child: child!,
          );
        },
        navigatorKey: navigator,
        title: 'IndeX',
        debugShowCheckedModeBanner: false,
        theme: theme,
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: 32,
                  child: Row(
                    children: [
                      Expanded(
                        child: widget.nativeWindow
                            ? const DragToMoveArea(child: SizedBox.expand())
                            : const SizedBox(),
                      ),
                      IconButton(
                        tooltip: 'Réduire',
                        onPressed: () => unawaited(widget.window.minimize()),
                        icon: const Icon(Icons.minimize, size: 17),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        tooltip: 'Agrandir ou restaurer',
                        onPressed: () =>
                            unawaited(widget.window.maximizeOrRestore()),
                        icon: const Icon(Icons.crop_square, size: 16),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        tooltip: 'Fermer',
                        onPressed: closing ? null : () => unawaited(close()),
                        icon: const Icon(Icons.close, size: 18),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                if (m.busy || closing)
                  const LinearProgressIndicator(minHeight: 3),
                if (m.busy || closing)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Text(
                      closing ? 'Sauvegarde et fermeture…' : m.message,
                      style: TextStyle(fontSize: 12, color: c.muted),
                    ),
                  ),
                if (m.error.isNotEmpty)
                  MaterialBanner(
                    content: SelectableText(m.error),
                    actions: [
                      TextButton(
                        onPressed: () {
                          m.error = '';
                          m.changed();
                        },
                        child: const Text('Masquer'),
                      ),
                    ],
                  ),
                Expanded(
                  child: AbsorbPointer(
                    absorbing: m.busy || closing,
                    child: m.needsSetup
                        ? StartupPage(
                            model: m,
                            pickDirectory: widget.pickDirectory,
                            onQuit: close,
                          )
                        : LibraryPage(
                            model: m,
                            pickDirectory: widget.pickDirectory,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class StartupPage extends StatefulWidget {
  const StartupPage({
    super.key,
    required this.model,
    required this.pickDirectory,
    required this.onQuit,
  });
  final AppModel model;
  final DirectoryPicker pickDirectory;
  final Future<void> Function() onQuit;
  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  final form = GlobalKey<FormState>();
  late final TextEditingController data, mp3;
  bool later = false;
  @override
  void initState() {
    super.initState();
    data = TextEditingController(text: widget.model.dataPath);
    mp3 = TextEditingController(text: widget.model.mp3Path);
  }

  @override
  void dispose() {
    data.dispose();
    mp3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 610),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Brand(),
                const SizedBox(height: 28),
                Text(
                  m.session == null
                      ? 'Bienvenue dans IndeX'
                      : 'Choisir le dossier MP3',
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 27),
                ),
                const SizedBox(height: 12),
                Text(
                  m.requireExisting && m.session == null
                      ? 'Retrouvez le dossier de vos données existantes. Aucune base vide ne remplacera votre suivi.'
                      : 'Le catalogue est consultable sans MP3. Choisissez le dossier dédié à vos données.',
                ),
                const SizedBox(height: 22),
                FolderField(
                  label: 'Dossier contenant les MP3',
                  controller: mp3,
                  picker: widget.pickDirectory,
                  enabled: !later,
                  validator: (v) => !later && (v ?? '').trim().isEmpty
                      ? 'Choisissez le dossier MP3 ou cochez la case ci-dessous.'
                      : null,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Préciser le dossier MP3 plus tard'),
                  value: later,
                  onChanged: (value) => setState(() => later = value!),
                ),
                const SizedBox(height: 12),
                FolderField(
                  label: 'Dossier des données utilisateur',
                  controller: data,
                  picker: widget.pickDirectory,
                  enabled: m.session == null,
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Ce dossier est obligatoire.'
                      : null,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Favoris, suivi et sauvegardes restent dans ce dossier. L’application est portable et ne déplace pas vos MP3.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: () => unawaited(widget.onQuit()),
                      child: const Text('Quitter'),
                    ),
                    FilledButton(
                      onPressed: () {
                        if (form.currentState!.validate())
                          unawaited(m.configure(data.text, mp3.text, later));
                      },
                      child: const Text('Ouvrir la bibliothèque'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FolderField extends StatelessWidget {
  const FolderField({
    super.key,
    required this.label,
    required this.controller,
    required this.picker,
    this.enabled = true,
    this.validator,
  });
  final String label;
  final TextEditingController controller;
  final DirectoryPicker picker;
  final bool enabled;
  final String? Function(String?)? validator;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: TextFormField(
          controller: controller,
          enabled: enabled,
          validator: validator,
          decoration: InputDecoration(labelText: label),
        ),
      ),
      const SizedBox(width: 8),
      IconButton(
        tooltip: 'Parcourir : $label',
        onPressed: !enabled
            ? null
            : () async {
                final value = await picker();
                if (value != null) controller.text = value;
              },
        icon: const Icon(Icons.folder_open),
      ),
    ],
  );
}

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text.rich(
        TextSpan(
          children: [
            const TextSpan(
              text: 'Inde',
              style: TextStyle(color: Color(0xff858585)),
            ),
            const TextSpan(text: 'X'),
          ],
        ),
        style: TextStyle(
          fontSize: 29,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      const SizedBox(height: 5),
      const Text(
        'Recherche et écoute de Rendez-Vous avec X',
        style: TextStyle(fontSize: 12, height: 1.5),
      ),
    ],
  );
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.model,
    required this.pickDirectory,
  });
  final AppModel model;
  final DirectoryPicker pickDirectory;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final search = TextEditingController();
  Timer? debounce;
  final listFocus = FocusNode(debugLabel: 'Liste des épisodes');
  final listScroll = ScrollController();
  KeyEventResult navigateList(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent)
      return KeyEventResult.ignored;
    final delta = event.logicalKey == LogicalKeyboardKey.arrowDown
        ? 1
        : event.logicalKey == LogicalKeyboardKey.arrowUp
        ? -1
        : 0;
    if (delta == 0) return KeyEventResult.ignored;
    m.selectRelative(delta);
    final index = m.visible.indexWhere((e) => e.id == m.selected?.id);
    if (index >= 0 && listScroll.hasClients) {
      final extent = m.query.trim().characters.length >= 3 ? 66.0 : 52.0;
      final top = index * extent;
      final position = listScroll.position;
      final target = top < position.pixels
          ? top
          : top + extent > position.pixels + position.viewportDimension
          ? top + extent - position.viewportDimension
          : position.pixels;
      listScroll.jumpTo(target.clamp(0.0, position.maxScrollExtent));
    }
    return KeyEventResult.handled;
  }

  AppModel get m => widget.model;
  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    listFocus.dispose();
    listScroll.dispose();
    super.dispose();
  }

  Future<void> settings() => showDialog<void>(
    context: context,
    builder: (context) =>
        SettingsDialog(model: m, pickDirectory: widget.pickDirectory),
  );
  void section(bool files, bool favorites) {
    m.filesView = files;
    m.favoritesOnly = favorites;
    m.reload();
  }

  @override
  Widget build(BuildContext context) {
    final c = EditorialColors(m.dark);
    return Column(
      children: [
        if (m.mp3Path.isEmpty || m.audioState != AudioFolderState.ready)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            color: c.background,
            child: Text(
              m.folderLabel,
              style: TextStyle(
                fontSize: 12,
                color: m.audioState == AudioFolderState.ready
                    ? c.muted
                    : c.accent,
              ),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, size) {
              final compact = size.maxWidth < 950;
              return Row(
                children: [
                  if (!compact)
                    Container(
                      width: 172,
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: c.line)),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Brand(),
                          const SizedBox(height: 20),
                          _nav(
                            'Bibliothèque',
                            Icons.library_books,
                            !m.filesView && !m.favoritesOnly,
                            () => section(false, false),
                          ),
                          _nav(
                            'Favoris',
                            Icons.star_border,
                            !m.filesView && m.favoritesOnly,
                            () => section(false, true),
                          ),
                          _nav(
                            'Fichiers',
                            Icons.folder_outlined,
                            m.filesView,
                            () => section(true, false),
                          ),
                          _nav(
                            'Paramètres',
                            Icons.settings_outlined,
                            false,
                            () => unawaited(settings()),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: m.filesView
                        ? ScanPage(
                            model: m,
                            pickDirectory: widget.pickDirectory,
                          )
                        : compact
                        ? list(c, true)
                        : Row(
                            children: [
                              Expanded(flex: 11, child: list(c, false)),
                              VerticalDivider(width: 1, color: c.line),
                              Expanded(
                                flex: 10,
                                child: EpisodeDetail(
                                  model: m,
                                  onRelated: related,
                                  pickDirectory: widget.pickDirectory,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
        _futurePlayer(c),
        if (MediaQuery.sizeOf(context).width < 950)
          Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: 12,
            children: [
              TextButton(
                onPressed: () => section(false, false),
                child: const Text('Bibliothèque'),
              ),
              TextButton(
                onPressed: () => section(false, true),
                child: const Text('Favoris'),
              ),
              TextButton(
                onPressed: () => section(true, false),
                child: const Text('Fichiers'),
              ),
              TextButton(
                onPressed: () => unawaited(settings()),
                child: const Text('Paramètres'),
              ),
            ],
          ),
      ],
    );
  }

  void related(DesktopEpisode episode) {
    debounce?.cancel();
    search.clear();
    m.query = '';
    m.status = 'Tous';
    m.favoritesOnly = false;
    m.sort = CatalogSort.dateNew;
    m.reload();
    final entry = m.catalog.firstWhere((e) => e.id == episode.id);
    m.select(entry);
  }

  Widget _nav(String text, IconData icon, bool active, VoidCallback action) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: TextButton.icon(
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            backgroundColor: EditorialColors(m.dark).controls,
            foregroundColor: active
                ? EditorialColors(m.dark).accent
                : EditorialColors(m.dark).ink,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          ),
          onPressed: action,
          icon: Icon(icon, size: 18),
          label: Text(text, style: const TextStyle(fontSize: 12)),
        ),
      );
  Widget list(EditorialColors c, bool compact) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: c.line),
                borderRadius: BorderRadius.circular(8),
                color: c.background,
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: search,
                      decoration: InputDecoration(
                        hintText: 'Rechercher un sujet… (3 caractères minimum)',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: 'Effacer la recherche',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            debounce?.cancel();
                            search.clear();
                            m.search('');
                          },
                        ),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        debounce?.cancel();
                        debounce = Timer(
                          const Duration(milliseconds: 250),
                          () => m.search(value),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final field in SearchField.values)
                          InkWell(
                            mouseCursor: WidgetStateMouseCursor.clickable,
                            onTap: () {
                              if (m.fields.contains(field))
                                m.fields.remove(field);
                              else
                                m.fields.add(field);
                              m.reload();
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 30,
                                  child: Checkbox(
                                    value: m.fields.contains(field),
                                    onChanged: (value) {
                                      if (value!)
                                        m.fields.add(field);
                                      else
                                        m.fields.remove(field);
                                      m.reload();
                                    },
                                  ),
                                ),
                                Text(
                                  fieldNames[field]!,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              m.favoritesOnly ? 'Favoris' : 'Bibliothèque',
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<CatalogSort>(
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
                  value: m.sort,
                  isDense: true,
                  items: [
                    for (final entry in sortNames.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    m.sort = v!;
                    m.reload();
                  },
                ),
                DropdownButton<String>(
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
                  value: m.status,
                  isDense: true,
                  items: [
                    for (final value in [
                      'Tous',
                      'NON_ECOUTE',
                      'EN_COURS',
                      'ECOUTE',
                    ])
                      DropdownMenuItem(
                        value: value,
                        child: Text(
                          value == 'Tous'
                              ? 'Tous les états'
                              : statusLabel(value),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    m.status = v!;
                    m.reload();
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              m.queryError.isNotEmpty
                  ? m.queryError
                  : '${m.visible.length} / ${m.catalog.length} épisodes',
              style: TextStyle(
                fontSize: 11,
                color: m.queryError.isNotEmpty ? c.alert : c.muted,
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: Focus(
          focusNode: listFocus,
          onKeyEvent: navigateList,
          child: m.visible.isEmpty
              ? const Center(child: Text('Aucun épisode pour ces critères.'))
              : ListView.builder(
                  key: const ValueKey('episode-list'),
                  controller: listScroll,
                  itemExtent: m.query.trim().characters.length >= 3 ? 66 : 52,
                  itemCount: m.visible.length,
                  itemBuilder: (context, index) {
                    final e = m.visible[index];
                    final missing = m.audioKnown && !e.audioAvailable,
                        heard = e.status == 'ECOUTE';
                    final color = missing
                        ? c.missingInk
                        : heard
                        ? c.heardInk
                        : c.ink;
                    return Material(
                      color: missing
                          ? c.missing
                          : heard
                          ? c.heard
                          : c.panel,
                      child: InkWell(
                        mouseCursor: SystemMouseCursors.click,
                        onTap: () {
                          listFocus.requestFocus();
                          m.select(e);
                          if (compact)
                            unawaited(
                              showDialog<void>(
                                context: context,
                                builder: (context) => Dialog(
                                  child: SizedBox(
                                    width: 650,
                                    height: 650,
                                    child: Column(
                                      children: [
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Fermer'),
                                          ),
                                        ),
                                        Expanded(
                                          child: EpisodeDetail(
                                            model: m,
                                            onRelated: related,
                                            pickDirectory: widget.pickDirectory,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: c.line),
                              left: BorderSide(
                                width: 4,
                                color: m.selected?.id == e.id
                                    ? c.accent
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 3,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      e.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Georgia',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: color,
                                      ),
                                    ),
                                    Text(
                                      dateLabel(e.date),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: color,
                                      ),
                                    ),
                                    if (e.matchedFields.isNotEmpty)
                                      Text(
                                        'Trouvé dans : ${e.matchedFields.map((f) => fieldNames[f]!).join(', ')}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: c.accent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (e.favorite)
                                Icon(Icons.star, size: 16, color: c.accent),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        statusIcon(e.status),
                                        size: 11,
                                        color: color,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        statusLabel(e.status),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    m.availability(e),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: missing ? c.alert : c.muted,
                                      fontWeight: missing
                                          ? FontWeight.w600
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    ],
  );
  Widget _futurePlayer(EditorialColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aucun épisode en lecture',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  m.audioKnown ? 'Lecteur audio prévu au Lot 5' : m.folderLabel,
                  style: TextStyle(fontSize: 11, color: c.muted),
                ),
              ],
            ),
          ),
          const Tooltip(
            message: 'Lecture audio disponible au Lot 5',
            child: IconButton(onPressed: null, icon: Icon(Icons.play_arrow)),
          ),
          const SizedBox(width: 4),
          const Text('— / —', style: TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class EpisodeDetail extends StatefulWidget {
  const EpisodeDetail({
    super.key,
    required this.model,
    required this.onRelated,
    required this.pickDirectory,
  });
  final AppModel model;
  final ValueChanged<DesktopEpisode> onRelated;
  final DirectoryPicker pickDirectory;
  @override
  State<EpisodeDetail> createState() => _EpisodeDetailState();
}

class _EpisodeDetailState extends State<EpisodeDetail> {
  int tab = 0;
  String? lastId;
  AppModel get m => widget.model;
  Future<void> toggle(DesktopEpisode e) async {
    bool reset = false;
    if (e.status == 'ECOUTE') {
      reset =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Marquer comme non écouté ?'),
              content: const Text(
                'La progression sera remise à zéro. Le favori et le lien audio seront conservés.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirmer'),
                ),
              ],
            ),
          ) ??
          false;
      if (!reset) return;
    }
    try {
      m.listened(e, reset: reset);
    } catch (error) {
      m.error = error.toString();
      m.changed();
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: m,
    builder: (context, _) {
      final e = m.selected;
      if (e == null)
        return const Center(child: Text('Sélectionnez un épisode.'));
      if (lastId != e.id) {
        lastId = e.id;
        tab = 0;
      }
      final c = EditorialColors(m.dark);
      return Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          key: ValueKey('detail-${e.id}'),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(
                e.title,
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                dateLabel(e.date),
                style: TextStyle(color: c.muted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => unawaited(toggle(e)),
                    icon: Icon(statusIcon(e.status), size: 18),
                    label: Text('${statusLabel(e.status)} ↻'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      try {
                        m.favorite(e);
                      } catch (error) {
                        m.error = error.toString();
                        m.changed();
                      }
                    },
                    icon: Icon(
                      e.favorite ? Icons.star : Icons.star_border,
                      color: c.accent,
                      size: 18,
                    ),
                    label: const Text('Favori'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                m.availability(e),
                style: TextStyle(
                  color: m.audioKnown && !e.audioAvailable ? c.alert : c.muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              if (m.query.isNotEmpty && e.excerpt.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: c.background,
                    border: Border.all(color: c.accent),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Résultat de la recherche',
                        style: TextStyle(
                          color: c.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText.rich(
                        TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: c.ink,
                          ),
                          children: searchExcerptSpans(
                            e.markedExcerpt.isEmpty
                                ? e.excerpt
                                : e.markedExcerpt,
                            c.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: tab == i ? c.accent : c.muted,
                      ),
                      onPressed: () => setState(() => tab = i),
                      child: Text(
                        ['Résumé', 'Sources', 'Musiques'][i],
                        style: TextStyle(
                          fontWeight: tab == i ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                ],
              ),
              Divider(color: c.line),
              if (tab == 0) summary(e.description, c),
              if (tab == 1) ...sources(e, c),
              if (tab == 2) ...music(e, c),
            ],
          ),
        ),
      );
    },
  );
  Widget summary(String text, EditorialColors c) {
    if (text.isEmpty || text == 'Aucune donnée')
      return const Text('Aucun résumé renseigné.');
    return DropCapSummary(text: text, colors: c);
  }

  Widget card(String title, List<Widget> content, EditorialColors c) =>
      Container(
        margin: const EdgeInsets.only(top: 14),
        decoration: BoxDecoration(
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: c.background,
              child: Text(
                title.trim().isEmpty ? 'Aucune donnée' : title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.muted,
                ),
              ),
            ),
            ...content,
          ],
        ),
      );
  Widget field(String label, Object? value, EditorialColors c) =>
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 88,
              padding: const EdgeInsets.all(10),
              color: c.background,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.accent,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: SelectableText(
                  value?.toString().trim().isNotEmpty == true
                      ? value.toString()
                      : 'Non renseigné',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      );
  List<Widget> sources(DesktopEpisode e, EditorialColors c) {
    if (e.sources.isEmpty) return [const Text('Aucune source renseignée.')];
    return [
      for (final s in e.sources)
        card(s['title'] as String? ?? 'Aucune donnée', [
          field('Auteur', s['author'], c),
          Divider(height: 1, color: c.line),
          field('Éditeur', s['publisher'], c),
          ...related(s['raw_text'] as String? ?? '', c),
        ], c),
    ];
  }

  List<Widget> related(String raw, EditorialColors c) {
    final refs = RegExp(r'\(([^()]+\.mp3)\)')
        .allMatches(raw)
        .map((m) => m[1]!)
        .toList();
    final byName = {for (final e in m.catalog) e.originalName: e};
    final entries = refs
        .where(byName.containsKey)
        .map((name) => byName[name]!)
        .toList();
    if (entries.isEmpty) return [];
    return [
      Container(
        padding: const EdgeInsets.all(10),
        color: c.background,
        child: Text(
          'Épisodes connexes',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: c.accent,
          ),
        ),
      ),
      for (final entry in entries)
        TextButton(
          onPressed: () => widget.onRelated(entry),
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.all(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(entry.title, style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Text(
                dateLabel(entry.date),
                style: TextStyle(fontSize: 10, color: c.muted),
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> music(DesktopEpisode e, EditorialColors c) => e.music.isEmpty
      ? [const Text('Aucune musique renseignée.')]
      : [
          for (final t in e.music)
            card(t['title'] as String? ?? 'Aucune donnée', [
              field('Artiste', t['artist'], c),
              Divider(height: 1, color: c.line),
              field('Album', t['album'], c),
              Divider(height: 1, color: c.line),
              field('Label', t['label'], c),
            ], c),
        ];
}

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    super.key,
    required this.model,
    required this.pickDirectory,
  });
  final AppModel model;
  final DirectoryPicker pickDirectory;
  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late final TextEditingController mp3;
  late bool recursive;
  AppModel get m => widget.model;
  @override
  void initState() {
    super.initState();
    mp3 = TextEditingController(text: m.mp3Path);
    recursive = m.session!.setting('recursive') == 'true';
  }

  @override
  void dispose() {
    mp3.dispose();
    super.dispose();
  }

  Future<void> move() async {
    final value = await widget.pickDirectory();
    if (value == null || !mounted) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Copier les données vers ce dossier ?'),
        content: Text(
          'Destination : $value\n\nLe dossier doit être vide. La base, les sauvegardes et les exports seront copiés et contrôlés. L’ancien dossier restera intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await m.relocate(Directory(value));
      if (mounted) setState(() {});
    }
  }

  Widget group(String title, List<Widget> content, EditorialColors c) =>
      Container(
        margin: const EdgeInsets.symmetric(vertical: 7),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.accent,
              ),
            ),
            const SizedBox(height: 12),
            ...content,
          ],
        ),
      );
  void future(String title, String text) => unawaited(
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: m,
    builder: (context, _) {
      final c = EditorialColors(m.dark);
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650, maxHeight: 780),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Paramètres',
                        style: TextStyle(fontFamily: 'Georgia', fontSize: 24),
                      ),
                    ),
                    TextButton(
                      onPressed: m.busy ? null : () => Navigator.pop(context),
                      child: const Text('Fermer'),
                    ),
                  ],
                ),
                if (m.busy) const LinearProgressIndicator(),
                Flexible(
                  child: AbsorbPointer(
                    absorbing: m.busy,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (m.error.isNotEmpty)
                            Text(m.error, style: TextStyle(color: c.alert)),
                          group('Apparence', [
                            DropdownButton<bool>(
                              mouseCursor: WidgetStateMouseCursor.clickable,
                              dropdownMenuItemMouseCursor:
                                  WidgetStateMouseCursor.clickable,
                              value: m.dark,
                              items: const [
                                DropdownMenuItem(
                                  value: false,
                                  child: Text('Mode clair'),
                                ),
                                DropdownMenuItem(
                                  value: true,
                                  child: Text('Mode sombre'),
                                ),
                              ],
                              onChanged: (v) {
                                try {
                                  m.setTheme(v!);
                                } catch (e) {
                                  m.error = e.toString();
                                  m.changed();
                                }
                              },
                            ),
                          ], c),
                          group('Dossiers', [
                            const Text(
                              'Données utilisateur',
                              style: TextStyle(fontSize: 12),
                            ),
                            SelectableText(
                              m.dataPath,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () => unawaited(move()),
                              child: const Text(
                                'Changer le dossier des données…',
                              ),
                            ),
                            const SizedBox(height: 18),
                            FolderField(
                              label: 'Dossier contenant les MP3',
                              controller: mp3,
                              picker: widget.pickDirectory,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Laisser ce champ vide pour retirer le dossier MP3. Le choix sera reproposé au prochain démarrage.',
                              style: TextStyle(fontSize: 12),
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Analyser aussi les sous-dossiers',
                                style: TextStyle(fontSize: 13),
                              ),
                              value: recursive,
                              onChanged: (v) => setState(() => recursive = v!),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  unawaited(m.folders(mp3.text, recursive)),
                              child: const Text('Enregistrer et analyser'),
                            ),
                          ], c),
                          group('Transfert du suivi', [
                            const Text(
                              'Transfert manuel des favoris, statuts et progressions entre Windows et Android. Aucun MP3, catalogue, chemin ou lien audio local transféré. Le JSON sera créé dans exports/ du dossier utilisateur, avec un nom explicite sans espaces.',
                              style: TextStyle(fontSize: 13, height: 1.6),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () => future(
                                    'Export du suivi — Lot 5 ter',
                                    'Cette fonction sera disponible au Lot 5 ter. Elle créera un fichier tel que IndeX_suivi_20261025T143000Z_a1b2c3d4.json dans le dossier des données utilisateur, sans modifier le suivi local.',
                                  ),
                                  child: const Text('Exporter le suivi JSON'),
                                ),
                                OutlinedButton(
                                  onPressed: () => future(
                                    'Import et fusion — Lot 5 ter',
                                    'La fusion présentera les différences et les conflits avant confirmation. Cette fonction n’est pas encore livrée.',
                                  ),
                                  child: const Text(
                                    'Importer et fusionner un suivi JSON',
                                  ),
                                ),
                              ],
                            ),
                          ], c),
                          group('Fichiers audio', [
                            const Text(
                              'Une seule conversion sera proposée : nom historique → nom système du catalogue. Exemple : mr_x_2005_10_15.mp3 → 2005-10-15 L’Irak (1 sur 3) _ Halabja.mp3. Aucun autre modèle ni sens inverse. Aperçu et confirmation obligatoires.',
                              style: TextStyle(fontSize: 13, height: 1.6),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: () => future(
                                'Renommage des MP3 — Lot 5 bis',
                                'Le renommage contrôlé sera développé au Lot 5 bis. Aucun fichier n’est modifié dans ce lot.',
                              ),
                              child: const Text(
                                'Prévisualiser le renommage des MP3',
                              ),
                            ),
                          ], c),
                        ],
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: m.busy ? null : () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class ScanPage extends StatelessWidget {
  const ScanPage({super.key, required this.model, required this.pickDirectory});
  final AppModel model;
  final DirectoryPicker pickDirectory;
  Future<void> associate(
    BuildContext context,
    Map<String, dynamic> decision,
  ) async {
    final selected = await showDialog<DesktopEpisode>(
      context: context,
      builder: (context) => ManualEpisodePicker(
        model: model,
        filename: decision['current_name'] as String,
      ),
    );
    if (selected == null || !context.mounted) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer cette association manuelle ?'),
        content: Text(
          '${decision['current_name']}\n→ ${selected.title} · ${dateLabel(selected.date)}\n\nCe choix sera conservé lors des prochains scans. Il ne constitue pas une confirmation ID3.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (yes == true)
      await model.manual(
        selected.id,
        decision['audio_reference'] as String,
        decision['current_name'] as String,
      );
  }

  @override
  Widget build(BuildContext context) {
    final c = EditorialColors(model.dark);
    final decisions = (model.report?['decisions'] as List?) ?? [];
    final issues = (model.report?['issues'] as List?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Fichiers et associations',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(model.folderLabel),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      final path = await pickDirectory();
                      if (path != null) await model.scan(path);
                    },
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Choisir un dossier MP3'),
                  ),
                  OutlinedButton(
                    onPressed: model.mp3Path.isEmpty
                        ? null
                        : () => unawaited(model.scan(model.mp3Path)),
                    child: const Text('Relancer le scan'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                model.report == null
                    ? 'Aucun scan réalisé.'
                    : '${model.report!['count']} MP3 analysé(s) · ${issues.length} diagnostic(s). Les fichiers ne sont jamais modifiés.',
              ),
              if (model.report != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Exporter le diagnostic TXT'),
                  onPressed: () async {
                    try {
                      final file = await model.exportScanDiagnostic();
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: SelectableText(
                              'Diagnostic exporté : ${file.path}',
                            ),
                          ),
                        );
                    } catch (error) {
                      model.error = 'Export du diagnostic impossible : $error';
                      model.changed();
                    }
                  },
                ),
              if (issues.isNotEmpty)
                ExpansionTile(
                  title: const Text('Diagnostics du scan'),
                  children: [
                    SizedBox(
                      height: 180,
                      child: ScanDiagnostics(issues: issues),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: decisions.isEmpty
              ? const Center(
                  child: Text('Sélectionnez un dossier pour analyser les MP3.'),
                )
              : ListView.builder(
                  itemCount: decisions.length,
                  itemBuilder: (context, index) {
                    final decision = Map<String, dynamic>.from(
                      decisions[index] as Map,
                    );
                    final manual = model.isManual(
                      decision['audio_reference'] as String,
                    );
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 5,
                      ),
                      child: ListTile(
                        title: Text(decision['current_name'] as String),
                        subtitle: Text(
                          '${manual ? 'Association manuelle' : decision['status']} · ${decision['reason']}',
                        ),
                        trailing: decision['status'] == 'confirmed' || manual
                            ? Icon(Icons.check_circle_outline, color: c.accent)
                            : OutlinedButton(
                                onPressed: () =>
                                    unawaited(associate(context, decision)),
                                child: const Text('Associer…'),
                              ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class ManualEpisodePicker extends StatefulWidget {
  const ManualEpisodePicker({
    super.key,
    required this.model,
    required this.filename,
  });
  final AppModel model;
  final String filename;
  @override
  State<ManualEpisodePicker> createState() => _ManualEpisodePickerState();
}

class _ManualEpisodePickerState extends State<ManualEpisodePicker> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final episodes = widget.model.catalog
        .where((e) => frenchTitleKey(e.title).contains(frenchTitleKey(query)))
        .toList();
    return Dialog(
      child: SizedBox(
        width: 650,
        height: 600,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choisir la fiche correspondante',
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 8),
              Text(widget.filename),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Rechercher une fiche',
                ),
                onChanged: (v) => setState(() => query = v),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: episodes.length,
                  itemBuilder: (context, i) {
                    final e = episodes[i];
                    return ListTile(
                      title: Text(e.title),
                      subtitle: Text(dateLabel(e.date)),
                      onTap: () => Navigator.pop(context, e),
                    );
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Les marqueurs proviennent de FTS5 ; aucun balisage fourni par le corpus n'est interprété.
List<TextSpan> searchExcerptSpans(String marked, Color accent) {
  final spans = <TextSpan>[];
  var bold = false;
  final buffer = StringBuffer();
  void flush() {
    if (buffer.isEmpty) return;
    spans.add(
      TextSpan(
        text: buffer.toString(),
        style: bold
            ? TextStyle(fontWeight: FontWeight.bold, color: accent)
            : null,
      ),
    );
    buffer.clear();
  }

  for (final character in marked.characters) {
    if (character == '\u0001' || character == '\u0002') {
      flush();
      bold = character == '\u0001';
    } else {
      buffer.write(character);
    }
  }
  flush();
  return spans;
}

class DropCapSummary extends StatelessWidget {
  const DropCapSummary({super.key, required this.text, required this.colors});
  final String text;
  final EditorialColors colors;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scaler = MediaQuery.textScalerOf(context);
      final style = TextStyle(fontSize: 15, height: 1.7, color: colors.ink);
      final first = text.characters.first;
      final rest = text.characters.skip(1).toString();
      final capWidth = scaler.scale(44);
      final lineHeight = scaler.scale(15) * 1.7;
      final painter = TextPainter(
        text: TextSpan(text: rest, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout(maxWidth: (box.maxWidth - capWidth).clamp(1, double.infinity));
      final lines = painter.computeLineMetrics();
      final split = lines.length <= 2
          ? rest.length
          : painter
                .getLineBoundary(
                  painter.getPositionForOffset(Offset(0, lines[1].baseline)),
                )
                .end;
      painter.dispose();
      return SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: capWidth,
                  height: lineHeight * 2,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      first,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 48,
                        height: 1,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ),
                Expanded(child: Text(rest.substring(0, split), style: style)),
              ],
            ),
            if (split < rest.length)
              Text(
                rest.substring(split).replaceFirst(RegExp(r'^\n'), ''),
                style: style,
              ),
          ],
        ),
      );
    },
  );
}

class ScanDiagnostics extends StatefulWidget {
  const ScanDiagnostics({super.key, required this.issues});
  final List<dynamic> issues;
  @override
  State<ScanDiagnostics> createState() => _ScanDiagnosticsState();
}

class _ScanDiagnosticsState extends State<ScanDiagnostics> {
  final controller = ScrollController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: controller,
    thumbVisibility: true,
    child: SelectionArea(
      child: ListView.builder(
        controller: controller,
        primary: false,
        itemCount: widget.issues.length,
        itemBuilder: (context, index) {
          final issue = widget.issues[index] as Map;
          return ListTile(
            dense: true,
            title: Text(issue['message'].toString()),
            subtitle: Text(issue['source']?.toString() ?? ''),
          );
        },
      ),
    ),
  );
}
