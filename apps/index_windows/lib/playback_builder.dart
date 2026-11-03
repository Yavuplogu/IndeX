import 'package:flutter/widgets.dart';

import 'audio_player.dart';

/// Isole les ticks du lecteur des vues documentaires et des autres épisodes.
class PlaybackBuilder extends StatefulWidget {
  const PlaybackBuilder({
    super.key,
    required this.playback,
    required this.builder,
    this.episodeId,
  });
  final Playback playback;
  final String? episodeId;
  final WidgetBuilder builder;
  @override
  State<PlaybackBuilder> createState() => _PlaybackBuilderState();
}

class _PlaybackBuilderState extends State<PlaybackBuilder> {
  String? previousId;
  @override
  void initState() {
    super.initState();
    previousId = widget.playback.episodeId;
    widget.playback.addListener(changed);
  }

  void changed() {
    final currentId = widget.playback.episodeId;
    if (widget.episodeId == null ||
        widget.episodeId == currentId ||
        widget.episodeId == previousId) {
      setState(() {});
    }
    previousId = currentId;
  }

  @override
  void didUpdateWidget(PlaybackBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playback != widget.playback) {
      oldWidget.playback.removeListener(changed);
      widget.playback.addListener(changed);
      previousId = widget.playback.episodeId;
    }
  }

  @override
  void dispose() {
    widget.playback.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
