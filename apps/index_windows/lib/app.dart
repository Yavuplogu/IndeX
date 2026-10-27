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
import 'document_text.dart';
import 'episode_search.dart';
import 'window_port.dart';

typedef DirectoryPicker = Future<String?> Function();
Future<String?> nativeDirectoryPicker() =>
    getDirectoryPath(confirmButtonText: 'Choisir ce dossier');

final class EditorialColors {
  EditorialColors(bool dark)
    : background = dark ? const Color(0xff1b1918) : const Color(0xfff5f1e9),
      panel = dark ? const Color(0xff252220) : const Color(0xfffffcf6),
      controls = dark ? const Color(0xff36302a) : const Color(0xffeee4d4),
      titleBar = dark ? const Color(0xff302e2d) : const Color(0xffe9e8e5),
      hitBackground = dark ? const Color(0xff36302a) : const Color(0xffeee4d4),
      hitInk = ColorScheme.fromSeed(
        seedColor: dark ? const Color(0xffe5ad8e) : const Color(0xff99533d),
        brightness: dark ? Brightness.dark : Brightness.light,
      ).primary,
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
      titleBar,
      hitBackground,
      hitInk,
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
const associationNames = {
  'confirmed': 'Associé par nom',
  'conflict': 'Conflit',
  'unknown': 'Nom inconnu',
  'blocked': 'Scan incomplet',
  'provisional': 'À vérifier',
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
        menuTheme: MenuThemeData(
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(c.controls),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
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
                Container(
                  key: const ValueKey('window-title-bar'),
                  height: 32,
                  color: c.titleBar,
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
                    child: m.opening || (m.busy && m.session == null)
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 18),
                                Text('N’allons pas trop vite...'),
                              ],
                            ),
                          )
                        : m.needsSetup
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
                      : 'IndeX permet de rechercher et consulter les épisodes de Rendez-Vous avec X, puis d’écouter vos MP3 personnels. Pour commencer, choisissez leur dossier ou précisez-le plus tard, puis vérifiez le dossier proposé pour vos favoris, votre suivi et vos sauvegardes. Le catalogue reste consultable sans MP3.',
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
  const Brand({super.key = const ValueKey('index-brand')});
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

class FilterMenu<T> extends StatelessWidget {
  const FilterMenu({
    super.key,
    required this.menuKey,
    required this.value,
    required this.labels,
    required this.onChanged,
    this.framed = false,
  });
  final bool framed;
  final String menuKey;
  final T value;
  final Map<T, String> labels;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    consumeOutsideTap: false,
    menuChildren: [
      for (final entry in labels.entries)
        MenuItemButton(
          key: ValueKey('$menuKey-${entry.key}'),
          onPressed: () => onChanged(entry.key),
          leadingIcon: entry.key == value
              ? const Icon(Icons.check, size: 16)
              : const SizedBox(width: 16),
          child: Text(entry.value, style: const TextStyle(fontSize: 12)),
        ),
    ],
    builder: (context, controller, child) => TextButton(
      key: ValueKey(menuKey),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).textTheme.bodyMedium!.color,
        backgroundColor: framed ? Theme.of(context).colorScheme.surface : null,
        side: framed ? BorderSide(color: Theme.of(context).dividerColor) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(
          horizontal: framed ? 12 : 4,
          vertical: framed ? 12 : 0,
        ),
        textStyle: TextStyle(fontSize: framed ? 14 : 12),
      ),
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(labels[value]!),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_drop_down, size: 20),
        ],
      ),
    ),
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
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
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
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              key: const ValueKey('library-search-panel'),
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
                FilterMenu<CatalogSort>(
                  menuKey: 'sort-filter',
                  value: m.sort,
                  labels: sortNames,
                  onChanged: (value) {
                    m.sort = value;
                    m.reload();
                  },
                ),
                FilterMenu<String>(
                  menuKey: 'status-filter',
                  value: m.status,
                  labels: {
                    for (final value in [
                      'Tous',
                      'NON_ECOUTE',
                      'EN_COURS',
                      'ECOUTE',
                    ])
                      value: value == 'Tous'
                          ? 'Tous les états'
                          : statusLabel(value),
                  },
                  onChanged: (value) {
                    m.status = value;
                    m.reload();
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              m.queryError.isNotEmpty ? m.queryError : m.episodeCountLabel,
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
  final headerScroll = ScrollController(keepScrollOffset: false);
  final dataScroll = ScrollController(keepScrollOffset: false);
  @override
  void dispose() {
    headerScroll.dispose();
    dataScroll.dispose();
    super.dispose();
  }

  int tab = 0;
  String? lastId;
  String lastSearch = '';
  int matchIndex = -1;
  late EpisodeSearch document;
  String? get activeMatch =>
      matchIndex >= 0 && matchIndex < document.matches.length
      ? document.matches[matchIndex].id
      : null;
  void moveMatch(int delta) {
    if (document.matches.isEmpty) return;
    setState(() {
      matchIndex = matchIndex < 0
          ? (delta > 0 ? 0 : document.matches.length - 1)
          : (matchIndex + delta) % document.matches.length;
      tab = document.matches[matchIndex].tab;
    });
  }

  Widget documentText(
    String id,
    TextStyle style,
    EditorialColors c, {
    String empty = 'Non renseigné',
    bool selectable = true,
  }) {
    final segment = document.segments[id]!;
    if (segment.text.trim().isEmpty) return Text(empty, style: style);
    if (segment.matches.isEmpty)
      return id == 'title'
          ? SelectableText(segment.text, style: style)
          : Text(segment.text, style: style);
    final text = DocumentText(
      key: ValueKey(id),
      segment: segment,
      style: style,
      ink: c.hitInk,
      fill: c.hitBackground,
      active: activeMatch,
    );
    return selectable ? SelectionArea(child: text) : text;
  }

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
      final signature =
          '${e.id}|${m.query}|${m.fields.map((f) => f.name).join(',')}';
      if (lastSearch != signature) {
        lastSearch = signature;
        matchIndex = -1;
      }
      document = EpisodeSearch(e, m.catalog);
      final c = EditorialColors(m.dark);
      final hasSearch =
          m.query.trim().characters.length >= 3 && e.matchedFields.isNotEmpty;
      return LayoutBuilder(
        builder: (context, bounds) => Column(
          key: ValueKey('detail-${e.id}'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              // On small windows/high zoom only, the header can be scrolled
              // manually without taking away the data viewport.
              constraints: BoxConstraints(maxHeight: bounds.maxHeight * 0.7),
              child: SingleChildScrollView(
                key: ValueKey('detail-header-${e.id}'),
                controller: headerScroll,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        KeyedSubtree(
                          key: const ValueKey('episode-detail-heading'),
                          child: documentText(
                            'title',
                            const TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                            c,
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
                            color: m.audioKnown && !e.audioAvailable
                                ? c.alert
                                : c.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                    if (hasSearch)
                      Container(
                        key: const ValueKey('search-match-guide'),
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: c.hitBackground,
                          border: Border.all(color: c.hitInk),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Résultat de la recherche',
                              style: TextStyle(
                                color: c.hitInk,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Correspondances encadrées en rouge, utilisez les boutons pour parcourir.',
                            ),
                            const SizedBox(height: 8),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                document.matches.isEmpty
                                    ? 'Aucune correspondance dans les champs affichés.'
                                    : matchIndex < 0
                                    ? '${document.matches.length} correspondance(s)'
                                    : 'Correspondance ${matchIndex + 1} / ${document.matches.length}',
                              ),
                            ),
                          ],
                        ),
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (hasSearch)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: c.hitInk,
                                      backgroundColor: c.hitBackground,
                                      side: BorderSide(color: c.hitInk),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 10,
                                      ),
                                      textStyle: Theme.of(context)
                                          .textTheme
                                          .labelLarge!
                                          .copyWith(fontSize: 13),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: document.matches.isEmpty
                                        ? null
                                        : () => moveMatch(-1),
                                    icon: const Icon(Icons.navigate_before),
                                    label: const Text('Résultat précédent'),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: c.hitInk,
                                      backgroundColor: c.hitBackground,
                                      side: BorderSide(color: c.hitInk),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 10,
                                      ),
                                      textStyle: Theme.of(context)
                                          .textTheme
                                          .labelLarge!
                                          .copyWith(fontSize: 13),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: document.matches.isEmpty
                                        ? null
                                        : () => moveMatch(1),
                                    icon: const Icon(Icons.navigate_next),
                                    iconAlignment: IconAlignment.end,
                                    label: const Text('Résultat suivant'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          key: const ValueKey('episode-detail-tabs'),
                          children: [
                            for (var i = 0; i < 3; i++)
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: tab == i
                                      ? c.accent
                                      : c.muted,
                                ),
                                onPressed: () => setState(() => tab = i),
                                child: Text(
                                  ['Résumé', 'Sources', 'Musiques'][i],
                                  style: TextStyle(
                                    fontWeight: tab == i
                                        ? FontWeight.bold
                                        : null,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    Divider(
                      key: const ValueKey('episode-detail-divider'),
                      height: 12,
                      color: c.line,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: ValueKey('detail-data-${e.id}-$tab'),
                controller: dataScroll,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  key: const ValueKey('episode-detail-content'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (tab == 0) summary(e.description, c),
                    if (tab == 1) ...sources(e, c),
                    if (tab == 2) ...music(e, c),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
  Widget summary(String text, EditorialColors c) {
    if (text.isEmpty || text == 'Aucune donnée')
      return const Text('Aucun résumé renseigné.');
    return DropCapSummary(
      text: text,
      colors: c,
      segment: document.segments['summary'],
      active: activeMatch,
    );
  }

  Widget card(String id, List<Widget> content, EditorialColors c) => Container(
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
          child: documentText(
            id,
            TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.muted,
            ),
            c,
            empty: 'Aucune donnée',
          ),
        ),
        ...content,
      ],
    ),
  );
  Widget field(String label, String id, EditorialColors c) => IntrinsicHeight(
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
            child: documentText(id, const TextStyle(fontSize: 13), c),
          ),
        ),
      ],
    ),
  );
  List<Widget> sources(DesktopEpisode e, EditorialColors c) {
    if (e.sources.isEmpty) return [const Text('Aucune source renseignée.')];
    return [
      for (final (i, s) in e.sources.indexed)
        card('source/$i/title', [
          field('Auteur', 'source/$i/author', c),
          Divider(height: 1, color: c.line),
          field('Éditeur', 'source/$i/publisher', c),
          ...related(s['raw_text'] as String? ?? '', c, i),
        ], c),
    ];
  }

  List<Widget> related(String raw, EditorialColors c, int sourceIndex) {
    final entries = relatedEpisodes(raw, m.catalog);
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
      for (final (j, entry) in entries.indexed)
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: TextButton(
            onPressed: () => widget.onRelated(entry),
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: const RoundedRectangleBorder(),
            ),
            child: Row(
              children: [
                Expanded(
                  child: documentText(
                    'source/$sourceIndex/related/$j/title',
                    TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: m.audioKnown && !entry.audioAvailable
                          ? c.missingInk
                          : entry.status == 'ECOUTE'
                          ? c.heardInk
                          : c.ink,
                    ),
                    c,
                    selectable: false,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  dateLabel(entry.date),
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontSize: 11,
                    color: m.audioKnown && !entry.audioAvailable
                        ? c.missingInk
                        : entry.status == 'ECOUTE'
                        ? c.heardInk
                        : c.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> music(DesktopEpisode e, EditorialColors c) => e.music.isEmpty
      ? [const Text('Aucune musique renseignée.')]
      : [
          for (final (i, _) in e.music.indexed)
            card('music/$i/title', [
              field('Artiste', 'music/$i/artist', c),
              Divider(height: 1, color: c.line),
              field('Album', 'music/$i/album', c),
              Divider(height: 1, color: c.line),
              field('Label', 'music/$i/label', c),
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
  AppModel get m => widget.model;
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
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Material(
          color: c.controls,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: c.line),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
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
          ),
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
        backgroundColor: c.panel,
        surfaceTintColor: Colors.transparent,
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
                            FilterMenu<bool>(
                              menuKey: 'appearance-filter',
                              framed: true,
                              value: m.dark,
                              labels: const {
                                false: 'Mode clair',
                                true: 'Mode sombre',
                              },
                              onChanged: (value) {
                                try {
                                  m.setTheme(value);
                                } catch (e) {
                                  m.error = e.toString();
                                  m.changed();
                                }
                              },
                            ),
                          ], c),
                          group('Données utilisateur', [
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
                          ], c),
                          group('Analyse au démarrage', [
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: const Text(
                                'Ne plus scanner le dossier MP3 à chaque ouverture',
                              ),
                              subtitle: const Text(
                                'Les derniers résultats sont conservés. Relancez une analyse dans Fichiers et associations pour actualiser les disponibilités.',
                              ),
                              value: m.skipStartupScan,
                              onChanged: (value) =>
                                  m.setSkipStartupScan(value!),
                            ),
                          ], c),
                          group('Transfert du suivi', [
                            const Text(
                              'Transfert manuel des favoris, statuts et progressions entre Windows et Android. Aucun MP3, catalogue, chemin ou lien audio local transféré. Un fichier .json pouvant ensuite être importé sera créé dans le dossier "exports" du dossier des données utilisateur.',
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
                                    'Cette fonction sera disponible au Lot 5 ter. Elle créera un fichier tel que IndeX_suivi_20261025T143000Z_a1b2c3d4.json dans le dossier exports des données utilisateur, sans modifier le suivi local.',
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

  Future<void> removeAssociation(BuildContext context, String reference) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enlever cette association ?'),
        content: const Text(
          'Le fichier MP3, les favoris et le suivi sont conservés. Le fichier restera sans association lors des prochains scans ; utilisez Associer… pour le rétablir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enlever'),
          ),
        ],
      ),
    );
    if (yes == true) await model.unlink(reference);
  }

  Future<void> diagnostics(BuildContext context, List<dynamic> issues) =>
      showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: EditorialColors(model.dark).panel,
          child: SizedBox(
            width: 700,
            height: 580,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Diagnostic du scan',
                          style: TextStyle(fontFamily: 'Georgia', fontSize: 24),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Fermer'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: issues.isEmpty
                        ? const Center(
                            child: Text('Aucun diagnostic à signaler.'),
                          )
                        : ScanDiagnostics(issues: issues),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = EditorialColors(model.dark);
    final decisions = (model.report?['decisions'] as List?) ?? [];
    final issues = (model.report?['issues'] as List?) ?? [];
    final manualRefs = model.manualAudioReferences;
    final entries = [
      for (final (i, raw) in decisions.indexed)
        (
          decision: Map<String, dynamic>.from(raw as Map),
          index: i,
          manual: manualRefs.contains(raw['audio_reference']),
        ),
    ];
    entries.sort((a, b) {
      final rank =
          (a.manual || a.decision['status'] == 'confirmed' ? 1 : 0) -
          (b.manual || b.decision['status'] == 'confirmed' ? 1 : 0);
      return rank != 0 ? rank : a.index.compareTo(b.index);
    });
    return LayoutBuilder(
      builder: (context, bounds) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: bounds.maxHeight * .75),
            child: SingleChildScrollView(
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
                    spacing: 18,
                    runSpacing: 6,
                    children: [
                      Text('Catalogue : ${model.catalog.length} épisodes'),
                      Text(
                        'Dossier MP3 : ${model.mp3Path.isEmpty ? 'Non analysé' : model.report?['count'] ?? 'Non analysé'} fichiers',
                      ),
                      Text(
                        'Épisodes associés : ${model.mp3Path.isEmpty ? 'Non vérifié' : model.availableAudioCount}',
                      ),
                      Text(
                        'Épisodes manquants : ${model.audioKnown ? model.missingAudioCount : 'Non vérifié'}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
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
                      OutlinedButton.icon(
                        onPressed: model.mp3Path.isEmpty
                            ? null
                            : () => unawaited(model.openMp3Folder()),
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Ouvrir le dossier MP3'),
                      ),
                      if (model.mp3Path.isNotEmpty)
                        TextButton(
                          onPressed: () =>
                              unawaited(model.folders('', model.recursive)),
                          child: const Text('Retirer le dossier MP3'),
                        ),
                    ],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Analyser aussi les sous-dossiers'),
                    value: model.recursive,
                    onChanged: (value) => model.setRecursive(value!),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    model.report == null
                        ? 'Aucun scan réalisé.'
                        : '${model.report!['count']} MP3 analysé(s) · ${issues.length} diagnostic(s).',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('Diagnostic du scan'),
                        onPressed: () =>
                            unawaited(diagnostics(context, issues)),
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
                              model.error =
                                  'Export du diagnostic impossible : $error';
                              model.changed();
                            }
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: decisions.isEmpty
                ? const Center(
                    child: Text(
                      'Sélectionnez un dossier pour analyser les MP3.',
                    ),
                  )
                : ListView.builder(
                    key: const ValueKey('scan-associations-list'),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final decision = entries[index].decision;
                      final manual = entries[index].manual;
                      final linked =
                          decision['status'] == 'confirmed' || manual;
                      return SelectionArea(
                        child: Card(
                          color: linked ? c.controls : c.missing,
                          surfaceTintColor: Colors.transparent,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 5,
                          ),
                          child: ListTile(
                            title: Text(decision['current_name'] as String),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${manual ? 'Association manuelle' : associationNames[decision['status']] ?? decision['status']} · ${decision['reason']}',
                                  style: TextStyle(
                                    color: linked ? c.muted : c.hitInk,
                                  ),
                                ),
                                Text(
                                  displayDiagnosticPath(
                                    decision['audio_reference'] as String,
                                  ),
                                ),
                              ],
                            ),
                            trailing: linked
                                ? IconButton(
                                    tooltip: 'Enlever l’association',
                                    icon: const Icon(Icons.link_off),
                                    onPressed: () => unawaited(
                                      removeAssociation(
                                        context,
                                        decision['audio_reference'] as String,
                                      ),
                                    ),
                                  )
                                : OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: c.controls,
                                    ),
                                    onPressed: () =>
                                        unawaited(associate(context, decision)),
                                    child: const Text('Associer…'),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
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

class DropCapSummary extends StatelessWidget {
  const DropCapSummary({
    super.key,
    required this.text,
    required this.colors,
    this.segment,
    this.active,
  });
  final String text;
  final EditorialColors colors;
  final TextSegment? segment;
  final String? active;
  @override
  Widget build(BuildContext context) => DropCapText(
    segment: segment ?? TextSegment('summary', text, const []),
    accent: colors.accent,
    ink: colors.hitInk,
    fill: colors.hitBackground,
    active: active,
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
            subtitle: Text(
              displayDiagnosticPath(issue['source']?.toString() ?? ''),
            ),
          );
        },
      ),
    ),
  );
}
