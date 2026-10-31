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
import 'audio_player.dart';
import 'document_text.dart';
import 'episode_search.dart';
import 'window_port.dart';

const applicationVersion = String.fromEnvironment(
  'INDEX_VERSION',
  defaultValue: 'Développement',
);

typedef DirectoryPicker = Future<String?> Function();
Future<String?> nativeDirectoryPicker() => Platform.isAndroid
    ? AppModel.androidChannel.invokeMethod<String>('pickTree')
    : getDirectoryPath(confirmButtonText: 'Choisir ce dossier');

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

class _IndeXAppState extends State<IndeXApp>
    with WindowListener, WidgetsBindingObserver {
  final navigator = GlobalKey<NavigatorState>();
  bool closing = false;
  bool closeErrorDialog = false;
  AppModel get m => widget.model;
  @override
  void initState() {
    super.initState();
    if (widget.nativeWindow) windowManager.addListener(this);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    if (widget.nativeWindow) windowManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (m.android &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.detached)) {
      unawaited(
        m.playback.suspend().catchError((Object e) {
          m.error = 'Sauvegarde audio impossible : $e';
          m.changed();
        }),
      );
    }
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
          content: SelectableText(
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
        home: PopScope<Object?>(
          canPop: !m.android,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && m.android) unawaited(close());
          },
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  if (!m.android)
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
                            onPressed: () =>
                                unawaited(widget.window.minimize()),
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
                            onPressed: closing
                                ? null
                                : () => unawaited(close()),
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
                      : 'IndeX permet de rechercher et consulter les épisodes de Rendez-vous avec X, puis d’écouter vos MP3 personnels. Pour commencer, choisissez leur dossier ou précisez-le plus tard, puis vérifiez le dossier proposé pour vos favoris, votre suivi et vos sauvegardes. Le catalogue reste consultable sans MP3.',
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
                  enabled: m.session == null && !m.android,
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
          errorBuilder: (context, error) => SelectableText(
            error,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
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
  const Brand({
    super.key = const ValueKey('index-brand'),
    this.showSubtitle = true,
  });
  final bool showSubtitle;
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
      if (showSubtitle) const SizedBox(height: 5),
      if (showSubtitle)
        const Text(
          'Recherche et écoute de Rendez-vous avec X',
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
  });
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        textStyle: const TextStyle(fontSize: 12),
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
  late final TextEditingController search;
  @override
  void initState() {
    super.initState();
    search = TextEditingController(text: m.query);
  }

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
  Future<void> about() => showDialog<void>(
    context: context,
    builder: (context) => IndexAboutDialog(model: m),
  );
  void section(bool files, bool favorites) {
    m.filesView = files;
    m.favoritesOnly = favorites;
    m.reload();
  }

  @override
  Widget build(BuildContext context) {
    final c = EditorialColors(m.dark);
    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent)
          return KeyEventResult.ignored;
        final focus = FocusManager.instance.primaryFocus?.context;
        if (focus?.findAncestorWidgetOfExactType<EditableText>() != null)
          return KeyEventResult.ignored;
        final delta = event.logicalKey == LogicalKeyboardKey.arrowLeft
            ? -10000
            : event.logicalKey == LogicalKeyboardKey.arrowRight
            ? 10000
            : 0;
        if (delta == 0 || m.playback.episodeId == null || m.playback.busy)
          return KeyEventResult.ignored;
        unawaited(m.playback.skip(delta));
        return KeyEventResult.handled;
      },
      child: Column(
        children: [
          if (m.mp3Path.isEmpty || m.audioState != AudioFolderState.ready)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              color: c.background,
              child: SelectableText(
                m.folderLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: m.audioState == AudioFolderState.ready
                      ? c.muted
                      : c.accent,
                ),
              ),
            ),
          if (m.downloading)
            Container(
              key: const ValueKey('download-progress'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: c.controls,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          m.downloadFinishing
                              ? 'Vérification et association du MP3…'
                              : 'Téléchargement : ${m.downloadingEpisode?.title ?? "Préparation…"}',
                        ),
                      ),
                      TextButton(
                        onPressed: m.downloadFinishing
                            ? null
                            : m.cancelDownload,
                        child: const Text('Annuler le téléchargement'),
                      ),
                    ],
                  ),
                  LinearProgressIndicator(
                    value: m.downloadTotal != null && m.downloadTotal! > 0
                        ? (m.downloadReceived / m.downloadTotal!).clamp(
                            0.0,
                            1.0,
                          )
                        : null,
                  ),
                  Text(
                    '${(m.downloadReceived / 1048576).toStringAsFixed(1)} Mo reçus'
                    '${m.downloadTotal == null ? "" : " / ${(m.downloadTotal! / 1048576).toStringAsFixed(1)} Mo"}',
                  ),
                ],
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
                            _nav(
                              'À propos',
                              Icons.info_outline,
                              false,
                              () => unawaited(about()),
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
                TextButton(
                  onPressed: () => unawaited(about()),
                  child: const Text('À propos'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void openPlayerEpisode(DesktopEpisode episode) {
    m.select(episode, keepOutsideList: true);
    // Quand la fiche n'est pas visible, l'ouvrir sans quitter la vue courante.
    if (m.filesView || MediaQuery.sizeOf(context).width < 950) {
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
                      onPressed: () => Navigator.pop(context),
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
    }
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
                        // Conserver aussi une saisie suivie d'une fermeture immédiate.
                        m.search(value, refresh: false);
                        debounce = Timer(
                          const Duration(milliseconds: 250),
                          m.reload,
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
            SelectableText(
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
                            gradient: !heard && m.progress(e) > 0
                                ? LinearGradient(
                                    colors: [
                                      c.heard,
                                      c.heard,
                                      Colors.transparent,
                                      Colors.transparent,
                                    ],
                                    stops: [0, m.progress(e), m.progress(e), 1],
                                  )
                                : null,
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
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                                    compact && !m.audioKnown
                                        ? 'MP3 non vérifié'
                                        : m.availability(e),
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
    final p = m.playback;
    final episode = m.playingEpisode;
    final enabled = !m.busy && !p.busy;
    final canPlay =
        enabled &&
        (episode != null ||
            m.resumeEpisode != null ||
            m.selected?.audioAvailable == true);
    final canChoose = enabled && m.availableAudioCount > 0;
    return Container(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (p.error.isNotEmpty)
            SelectableText(
              p.error,
              style: TextStyle(color: c.alert, fontSize: 12),
            ),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  key: const ValueKey('player-episode-title'),
                  mouseCursor: episode == null
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.click,
                  onTap: episode == null
                      ? null
                      : () => openPlayerEpisode(episode),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: episode?.title ?? 'Aucun épisode en lecture',
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (episode != null)
                          TextSpan(
                            text: ' · ${dateLabel(episode.date)}',
                            style: TextStyle(
                              fontFamily: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.fontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.normal,
                              color: m.audioKnown && !episode.audioAvailable
                                  ? c.missingInk
                                  : episode.status == 'ECOUTE'
                                  ? c.heardInk
                                  : c.ink,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Épisode précédent',
                onPressed: canChoose ? () => unawaited(m.nextAudio(-1)) : null,
                icon: const Icon(Icons.skip_previous),
              ),
              IconButton(
                tooltip: 'Arrêt',
                onPressed: enabled && episode != null
                    ? () => unawaited(m.stopAudio())
                    : null,
                icon: const Icon(Icons.stop),
              ),
              IconButton(
                tooltip: p.state.playing ? 'Pause' : 'Lecture / reprise',
                onPressed: canPlay ? () => unawaited(m.playToggle()) : null,
                icon: Icon(p.state.playing ? Icons.pause : Icons.play_arrow),
              ),
              IconButton(
                tooltip: 'Épisode suivant',
                onPressed: canChoose ? () => unawaited(m.nextAudio(1)) : null,
                icon: const Icon(Icons.skip_next),
              ),
              IconButton(
                tooltip: 'Lecture aléatoire',
                isSelected: m.shuffle,
                style: IconButton.styleFrom(
                  backgroundColor: m.shuffle ? c.controls : Colors.transparent,
                  foregroundColor: m.shuffle ? c.accent : c.ink,
                ),
                onPressed: canChoose
                    ? () => unawaited(m.toggleShuffle())
                    : null,
                icon: const Icon(Icons.shuffle),
              ),
              IconButton(
                tooltip: 'Lecture automatique suivante',
                isSelected: m.autoNext,
                style: IconButton.styleFrom(
                  backgroundColor: m.autoNext ? c.controls : Colors.transparent,
                  foregroundColor: m.autoNext ? c.accent : c.ink,
                ),
                onPressed: enabled ? m.toggleAutoNext : null,
                icon: const Icon(Icons.playlist_play),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                '${playbackTime(p.state.position)} / ${p.state.duration > 0 ? playbackTime(p.state.duration) : '—'}',
                style: const TextStyle(fontSize: 11),
              ),
              Expanded(
                child: PlayerSeekBar(
                  key: ValueKey('player-seek-${p.episodeId}'),
                  playback: p,
                  enabled: enabled && episode != null && p.state.duration > 0,
                ),
              ),
              const Icon(Icons.volume_up, size: 18),
              SizedBox(
                width: 80,
                child: Slider(
                  value: p.level,
                  onChanged: enabled ? (v) => unawaited(p.setVolume(v)) : null,
                ),
              ),
            ],
          ),
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

  Future<void> download(DesktopEpisode episode) async {
    if (m.downloading || m.busy) return;
    if (episode.audioRef != null && m.isManual(episode.audioRef!)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remplacer l’association indisponible ?'),
          content: const SelectableText(
            'Le MP3 téléchargé sera associé à cette fiche. Votre suivi et votre favori seront conservés. Aucun fichier existant ne sera remplacé.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Télécharger'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final path = m.mp3Path.isEmpty ? await widget.pickDirectory() : m.mp3Path;
    if (path == null || !mounted) return;
    unawaited(m.downloadEpisode(episode, path));
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
              content: const SelectableText(
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
    } else {
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Marquer comme écouté ?'),
              content: const SelectableText(
                'La lecture de cet épisode sera arrêtée et sa progression remise à zéro. Le favori est conservé.',
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
      if (!confirmed) return;
    }
    try {
      await m.listened(e, reset: reset);
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
                              label: Text(
                                e.status == 'EN_COURS'
                                    ? 'En cours (${(m.progress(e) * 100).floor()} %)'
                                    : statusLabel(e.status),
                              ),
                            ),
                            if (e.audioAvailable)
                              FilledButton.icon(
                                onPressed: !m.busy && !m.playback.busy
                                    ? () => unawaited(m.playEpisode(e))
                                    : null,
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Écouter'),
                              )
                            else
                              Tooltip(
                                message: mp3DownloadUri(e.downloadUrl) == null
                                    ? 'Aucune URL MP3 disponible dans le journal.'
                                    : 'Télécharger depuis ${mp3DownloadUri(e.downloadUrl)!.host} (connexion Internet requise)',
                                child: FilledButton.icon(
                                  key: const ValueKey('download-episode'),
                                  onPressed:
                                      !m.busy &&
                                          !m.downloading &&
                                          !m.android &&
                                          mp3DownloadUri(e.downloadUrl) != null
                                      ? () => unawaited(download(e))
                                      : null,
                                  icon: const Icon(Icons.download_outlined),
                                  label: const Text('Télécharger'),
                                ),
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
                              Flexible(
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: tab == i
                                        ? c.accent
                                        : c.muted,
                                  ),
                                  onPressed: () => setState(() => tab = i),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      ['Résumé', 'Sources', 'Musiques'][i],
                                      style: TextStyle(
                                        fontWeight: tab == i
                                            ? FontWeight.bold
                                            : null,
                                      ),
                                    ),
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

Widget panelGroup(
  String title,
  List<Widget> content,
  EditorialColors c, {
  Widget? heading,
}) => Padding(
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
          heading ??
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

class IndexAboutDialog extends StatelessWidget {
  const IndexAboutDialog({super.key, required this.model});
  final AppModel model;

  Future<void> contact(BuildContext context) async {
    try {
      await Clipboard.setData(
        const ClipboardData(text: 'index.en9nr@passinbox.com'),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Adresse mail copiée dans le presse-papiers.'),
          ),
        );
    } catch (error) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Copie impossible'),
          content: SelectableText('index.en9nr@passinbox.com\n\n$error'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = EditorialColors(model.dark);
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
                      'À propos',
                      style: TextStyle(fontFamily: 'Georgia', fontSize: 24),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  key: const ValueKey('about-scroll'),
                  child: SelectionArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        panelGroup(
                          'IndeX',
                          [
                            const Text(
                              'J’ai construit cet utilitaire à partir d’une interrogation : serait-il possible de disposer d’un outil entièrement hors ligne permettant de gérer et d’écouter ma collection d’épisodes de Rendez-vous avec X ?\n\n'
                              'Cela faisait des années que l’idée me séduisait, en réalité depuis l’arrêt de l’émission en 2015. Puis, la mort de Patrick Pesnot en 2023 m’a remotivé et j’ai fait quelques tentatives, plutôt infructueuses, car je ne suis pas du tout développeur.\n\n'
                              'Il y a quelque temps, j’ai eu l’idée d’utiliser l’IA en me disant : « Bon, à mon avis, ça va me prendre quelques mois et j’aurai probablement un résultat nébuleux, fonctionnant à moitié, puis je tenterai à nouveau ma chance dans dix ans. »\n\n'
                              'Finalement, le développement n’a duré qu’une semaine, pour un résultat parfaitement fonctionnel. Certes, il y a eu beaucoup de va-et-vient, pas mal de versions différentes et quelques adaptations, mais tout le processus a été beaucoup plus rapide et intuitif que prévu. C’est à la fois fascinant et terrifiant pour l’avenir.\n\n'
                              'Quoi qu’il en soit, vous trouverez un peu plus bas un tour d’horizon des capacités de IndeX et si vous avez une question particulière, vous pouvez me contacter sur le mail :',
                            ),
                            Align(
                              alignment: Alignment.center,
                              child: TextButton(
                                key: const ValueKey('about-contact'),
                                onPressed: () => unawaited(contact(context)),
                                child: const Text('index.en9nr@passinbox.com'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text('Bonne écoute,\n\nK.'),
                          ],
                          c,
                          heading: Row(
                            key: const ValueKey('about-links-version'),
                            children: [
                              const Brand(
                                key: ValueKey('about-brand'),
                                showSubtitle: false,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Version : $applicationVersion',
                                        key: ValueKey('about-version'),
                                      ),
                                      const SizedBox(width: 12),
                                      OutlinedButton.icon(
                                        key: const ValueKey('about-github'),
                                        icon: Image.asset(
                                          'assets/icons/github-mark.png',
                                          width: 20,
                                          height: 20,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                        label: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('Voir sur GitHub'),
                                        ),
                                        onPressed: () =>
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Lien GitHub de démonstration : aucun site n’est ouvert.',
                                                    ),
                                                  ),
                                                ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        panelGroup(
                          'Une bibliothèque pour explorer les épisodes',
                          [
                            const Text(
                              'IndeX rassemble le catalogue documentaire de 716 émissions (soit 420 heures d’écoute) de Rendez-vous avec X et permet de retrouver, consulter et écouter vos épisodes depuis une même interface. Le catalogue est intégré à l’application : aucun fichier externe n’est nécessaire pour le consulter.',
                            ),
                          ],
                          c,
                        ),
                        panelGroup('Retrouver et comprendre', [
                          const Text(
                            'Une recherche dynamique permet de trouver n’importe quel sujet dans les titres, résumés, sources et musiques. Triez les épisodes par titre, date ou disponibilité MP3, filtrez leur état d’écoute et retrouvez vos favoris.\n\nChaque fiche présente le résumé, les références et les musiques. Si les références listent des épisodes connexes, il est possible d’accéder à leur fiche d’un simple clic.',
                          ),
                        ], c),
                        panelGroup('Écouter vos MP3', [
                          const Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Choisissez votre dossier MP3 dans l’onglet ',
                                ),
                                TextSpan(
                                  text: 'Fichiers',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text: '. IndeX analyse le dossier et rapproche automatiquement les noms des fichiers du catalogue avec vos fichiers locaux, affiche un diagnostic complet et propose aussi des associations manuelles. Si vous n’avez pas l’épisode, un bouton propose le téléchargement du MP3 sur le site rendezvousavecmrx.free.fr.\n\nAttention, l’association automatique en local fonctionne uniquement avec des noms type ',
                                ),
                                TextSpan(
                                  text: '1997-01-04 La 5ème Colonne.mp3',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: ' ou son équivalent '),
                                TextSpan(
                                  text: 'mr_x_1997_01_04.mp3',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text: '. Pourquoi uniquement ces deux modèles ? Car il s’agit des deux catalogues téléchargeables les plus répandus sur Internet. Aucun autre formatage de nom ne sera pris en compte par IndeX. Le catalogue reste consultable sans MP3.\n\nLe lecteur intégré propose lecture, pause, arrêt, volume, déplacement dans la piste et sauts de dix secondes avec les flèches du clavier. Activez la lecture aléatoire ou l’enchaînement de l’épisode suivant. Consulter une autre fiche ne change pas la lecture en cours.',
                                ),
                              ],
                            ),
                          ),
                        ], c),
                        panelGroup('Garder le fil de vos écoutes', [
                          const Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'La progression d’un épisode est sauvegardée régulièrement et peut être reprise à la prochaine écoute. Les états ',
                                ),
                                TextSpan(
                                  text: 'Non écouté',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: ', '),
                                TextSpan(
                                  text: 'En cours',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: ' et '),
                                TextSpan(
                                  text: 'Écouté',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text: ' ainsi que le remplissage des lignes indiquent votre avancement. Vous pouvez aussi modifier le statut et marquer vos favoris. L’arrêt remet la progression à zéro ; relancer un épisode terminé commence une nouvelle écoute en conservant son favori.',
                                ),
                              ],
                            ),
                          ),
                        ], c),
                        panelGroup('Vos données restent chez vous', [
                          const Text(
                            'Le catalogue et l’écoute locale fonctionnent hors ligne, sans compte ni synchronisation automatique. Vos favoris, progressions, réglages et journaux restent dans le dossier de données utilisateur que vous avez spécifié. Il est possible d’exporter ces données afin de les importer sur un autre environnement, Windows ou Android. La version Windows est portable, sans installateur ni connexion Internet.',
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Le transfert par export/import JSON est prévu au Lot 5 ter et n’est pas encore disponible.',
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
        content: SelectableText(
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

  void future(String title, String text) => unawaited(
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SelectableText(text),
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
                            SelectableText(
                              m.error,
                              style: TextStyle(color: c.alert),
                            ),
                          panelGroup('Apparence', [
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                for (final dark in [false, true])
                                  Semantics(
                                    selected: m.dark == dark,
                                    child: OutlinedButton.icon(
                                      key: ValueKey(
                                        dark
                                            ? 'appearance-dark'
                                            : 'appearance-light',
                                      ),
                                      icon: Icon(
                                        dark
                                            ? Icons.dark_mode_outlined
                                            : Icons.light_mode_outlined,
                                      ),
                                      label: Text(
                                        dark ? 'Mode sombre' : 'Mode clair',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: m.dark == dark
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                            : c.controls,
                                        foregroundColor: m.dark == dark
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .onPrimary
                                            : c.ink,
                                      ),
                                      onPressed: () {
                                        try {
                                          m.setTheme(dark);
                                        } catch (e) {
                                          m.error = e.toString();
                                          m.changed();
                                        }
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ], c),
                          panelGroup('Données utilisateur', [
                            SelectableText(m.dataPath),
                            const SizedBox(height: 8),
                            if (!m.android)
                              OutlinedButton(
                                onPressed: () => unawaited(move()),
                                child: const Text(
                                  'Changer le dossier des données…',
                                ),
                              ),
                          ], c),
                          panelGroup('Lecture et reprise', [
                            CheckboxListTile(
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              subtitle: Text(
                                'La lecture en arrière-plan est mise en pause avec sauvegarde de la position.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              title: Text(
                                'Reprendre à la dernière position sauvegardée',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              value: m.resumePlayback,
                              onChanged: (value) {
                                m.session!.setSetting(
                                  'resume_playback',
                                  value.toString(),
                                );
                                m.changed();
                              },
                            ),
                          ], c),
                          panelGroup('Analyse au démarrage', [
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                'Scanner le dossier MP3 à chaque ouverture',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              subtitle: Text(
                                'Décochez pour conserver les derniers résultats sans analyse automatique. Vous pouvez toujours relancer une analyse dans Fichiers et associations.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              value: !m.skipStartupScan,
                              onChanged: (value) =>
                                  m.setSkipStartupScan(!value!),
                            ),
                          ], c),
                          panelGroup('Transfert du suivi', [
                            const Text(
                              'Transfert manuel des favoris, statuts et progressions entre Windows et Android. Aucun MP3, catalogue, chemin ou lien audio local transféré. Un fichier .json pouvant ensuite être importé sera créé dans le dossier "exports" du dossier des données utilisateur.',
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
                          panelGroup('Fichiers audio', [
                            const Text(
                              'Une seule conversion sera proposée : nom historique → nom système du catalogue. Exemple : mr_x_2005_10_15.mp3 → 2005-10-15 L’Irak (1 sur 3) _ Halabja.mp3. Aucun autre modèle ni sens inverse. Aperçu et confirmation obligatoires.',
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
        content: SelectableText(
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
        content: const SelectableText(
          'Le favori et le suivi d’écoute de cet épisode (statut, progression et durée) seront supprimés. Le fichier MP3 est conservé. Il restera sans association lors des prochains scans ; utilisez Associer… pour rétablir le lien, sans restaurer les données supprimées.',
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
    entries.removeWhere((entry) {
      final linked = entry.manual || entry.decision['status'] == 'confirmed';
      return switch (model.audioFileFilter) {
        AudioFileFilter.all => false,
        AudioFileFilter.associated => !linked,
        AudioFileFilter.unassociated => linked,
      };
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
                  SelectableText(model.folderLabel),
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
                              var location = file.path;
                              if (model.android) {
                                final target = await AppModel.androidChannel
                                    .invokeMethod<String>('exportText', {
                                      'name': file.uri.pathSegments.last,
                                      'text': await file.readAsString(),
                                    });
                                if (target == null) return;
                                location = target;
                              }
                              if (context.mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: SelectableText(
                                      'Diagnostic exporté : $location',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in const {
                  AudioFileFilter.associated: 'Fichiers associés',
                  AudioFileFilter.unassociated: 'Fichiers non associés',
                  AudioFileFilter.all: 'Tous les fichiers',
                }.entries)
                  ChoiceChip(
                    key: ValueKey('audio-files-${entry.key.name}'),
                    mouseCursor: SystemMouseCursors.click,
                    backgroundColor: c.controls,
                    selectedColor: c.controls,
                    surfaceTintColor: Colors.transparent,
                    label: Text(entry.value),
                    selected: model.audioFileFilter == entry.key,
                    onSelected: (_) {
                      model.audioFileFilter = entry.key;
                      model.changed();
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      decisions.isEmpty
                          ? 'Sélectionnez un dossier pour analyser les MP3.'
                          : 'Aucun fichier pour ce filtre.',
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

/// La cible reste affichée jusqu'à la confirmation du seek natif.
class PlayerSeekBar extends StatefulWidget {
  const PlayerSeekBar({
    super.key,
    required this.playback,
    required this.enabled,
  });
  final Playback playback;
  final bool enabled;
  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar> {
  double? preview, hover;
  int? hoverTime;
  bool committing = false, dragging = false, hovering = false;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final p = widget.playback;
      final duration = p.state.duration > 0 ? p.state.duration.toDouble() : 1.0;
      return MouseRegion(
        onEnter: (_) => setState(() => hovering = true),
        onExit: (_) => setState(() {
          hovering = false;
          if (!dragging) {
            hover = null;
            hoverTime = null;
          }
        }),
        onHover: (event) {
          if (p.state.duration <= 0) return;
          final fraction =
              ((event.localPosition.dx - 12) /
                      (constraints.maxWidth - 24).clamp(1, double.infinity))
                  .clamp(0.0, 1.0);
          setState(() {
            hovering = true;
            if (!dragging) {
              hover = event.localPosition.dx;
              hoverTime = (fraction * duration).round();
            }
          });
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Slider(
              key: const ValueKey('player-progress'),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              value: (preview ?? p.state.position.toDouble())
                  .clamp(0, duration)
                  .toDouble(),
              max: duration,
              onChangeStart: widget.enabled && !committing
                  ? (v) => setState(() {
                      dragging = true;
                      hoverTime = v.round();
                      hover = 12 + (constraints.maxWidth - 24) * v / duration;
                    })
                  : null,
              onChanged: widget.enabled && !committing
                  ? (v) => setState(() {
                      preview = v;
                      hoverTime = v.round();
                      hover = 12 + (constraints.maxWidth - 24) * v / duration;
                    })
                  : null,
              onChangeEnd: widget.enabled && !committing
                  ? (v) async {
                      setState(() {
                        preview = v;
                        committing = true;
                        dragging = false;
                        if (!hovering) {
                          hover = null;
                          hoverTime = null;
                        }
                      });
                      await p.seek(v.round());
                      if (mounted)
                        setState(() {
                          preview = null;
                          committing = false;
                        });
                    }
                  : null,
              semanticFormatterCallback: (v) => playbackTime(v.round()),
            ),
            if (hover != null && hoverTime != null)
              Positioned(
                bottom: 28,
                left: (hover! - 28).clamp(
                  0.0,
                  (constraints.maxWidth - 56).clamp(0.0, double.infinity),
                ),
                child: IgnorePointer(
                  child: Material(
                    elevation: 3,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      child: Text(
                        playbackTime(hoverTime!),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
