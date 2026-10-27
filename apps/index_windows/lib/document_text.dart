import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class DocumentMatch {
  const DocumentMatch(this.id, this.segment, this.tab, this.start, this.end);
  final String id, segment;
  final int tab, start, end;
}

class TextSegment {
  const TextSegment(this.id, this.text, this.matches);
  final String id, text;
  final List<DocumentMatch> matches;

  TextSpan span(TextStyle style, Color ink, {int start = 0, int? end}) {
    final stop = end ?? text.length;
    final spans = <TextSpan>[];
    var cursor = start;
    for (final match in matches) {
      if (match.end <= start || match.start >= stop) continue;
      final a = match.start.clamp(start, stop),
          b = match.end.clamp(start, stop);
      if (a > cursor) spans.add(TextSpan(text: text.substring(cursor, a)));
      spans.add(
        TextSpan(
          text: text.substring(a, b),
          style: TextStyle(color: ink, fontWeight: FontWeight.bold),
        ),
      );
      cursor = b;
    }
    if (cursor < stop) spans.add(TextSpan(text: text.substring(cursor, stop)));
    return TextSpan(style: style, children: spans);
  }
}

/// Paint match frames from the actual RenderParagraph: no inline boxes that
/// change word wrapping or the height of the summary's first two lines.
class DocumentText extends StatefulWidget {
  const DocumentText({
    super.key,
    required this.segment,
    required this.style,
    required this.ink,
    required this.fill,
    this.active,
    this.start = 0,
    this.end,
    this.strut,
  });
  final TextSegment segment;
  final TextStyle style;
  final StrutStyle? strut;
  final Color ink, fill;
  final String? active;
  final int start;
  final int? end;
  @override
  State<DocumentText> createState() => _DocumentTextState();
}

class _DocumentTextState extends State<DocumentText> {
  final paragraphKey = GlobalKey();
  bool pending = false;
  @override
  void initState() {
    super.initState();
    scheduleReveal();
  }

  @override
  void didUpdateWidget(DocumentText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active ||
        oldWidget.segment.id != widget.segment.id)
      scheduleReveal();
  }

  DocumentMatch? get active {
    for (final match in widget.segment.matches) {
      if (match.id == widget.active &&
          match.start >= widget.start &&
          match.start < (widget.end ?? widget.segment.text.length))
        return match;
    }
    return null;
  }

  void scheduleReveal() {
    if (pending || active == null || widget.segment.id == 'title') return;
    pending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pending = false;
      if (!mounted || active == null) return;
      final render = paragraphKey.currentContext?.findRenderObject();
      if (render is! RenderParagraph) return;
      final match = active!;
      final boxes = render.getBoxesForSelection(
        TextSelection(
          baseOffset: match.start - widget.start,
          extentOffset:
              match.end.clamp(
                widget.start,
                widget.end ?? widget.segment.text.length,
              ) -
              widget.start,
        ),
      );
      if (boxes.isEmpty) return;
      final scrollable = Scrollable.maybeOf(context);
      final viewport = RenderAbstractViewport.maybeOf(render);
      if (scrollable == null || viewport == null) return;
      final position = scrollable.position;
      final target = viewport
          .getOffsetToReveal(render, 0.35, rect: boxes.first.toRect())
          .offset;
      position.animateTo(
        target.clamp(position.minScrollExtent, position.maxScrollExtent),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final segment = widget.segment;
    return CustomPaint(
      painter: _MatchFrames(
        paragraphKey,
        segment.matches,
        widget.start,
        widget.end ?? segment.text.length,
        widget.ink,
        widget.fill,
        widget.active,
      ),
      child: RichText(
        text: segment.span(
          style,
          widget.ink,
          start: widget.start,
          end: widget.end,
        ),
        key: paragraphKey,
        textScaler: MediaQuery.textScalerOf(context),
        strutStyle: widget.strut,
        selectionRegistrar: SelectionContainer.maybeOf(context),
        selectionColor: Theme.of(context).colorScheme.primary
            .withValues(alpha: 0.25),
      ),
    );
  }
}

class _MatchFrames extends CustomPainter {
  _MatchFrames(
    this.paragraphKey,
    this.matches,
    this.start,
    this.end,
    this.ink,
    this.fill,
    this.active,
  );
  final GlobalKey paragraphKey;
  final List<DocumentMatch> matches;
  final int start, end;
  final Color ink, fill;
  final String? active;
  @override
  void paint(Canvas canvas, Size size) {
    final render = paragraphKey.currentContext?.findRenderObject();
    if (render is! RenderParagraph) return;
    for (final match in matches) {
      if (match.end <= start || match.start >= end) continue;
      final boxes = render.getBoxesForSelection(
        TextSelection(
          baseOffset: match.start.clamp(start, end) - start,
          extentOffset: match.end.clamp(start, end) - start,
        ),
      );
      for (final box in boxes) {
        final rect = RRect.fromRectAndRadius(
          box.toRect().inflate(1),
          const Radius.circular(2),
        );
        canvas.drawRRect(rect, Paint()..color = fill);
        canvas.drawRRect(
          rect,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = match.id == active ? 2 : 0.6,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MatchFrames old) => true;
}

/// A first-character group can include opening punctuation plus the first
/// letter/digit. All offsets remain UTF-16 offsets into the original string.
int dropCapEnd(String text) {
  var offset = 0;
  for (final character in text.characters) {
    offset += character.length;
    if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(character))
      return offset;
  }
  return text.characters.isEmpty ? 0 : text.characters.first.length;
}

class DropCapText extends StatelessWidget {
  const DropCapText({
    super.key,
    required this.segment,
    required this.accent,
    required this.ink,
    required this.fill,
    this.active,
  });
  final TextSegment segment;
  final Color accent, ink, fill;
  final String? active;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final text = segment.text;
      if (text.isEmpty) return const SizedBox.shrink();
      final scaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      final style = DefaultTextStyle.of(context).style
          .merge(const TextStyle(fontSize: 15, height: 1.7));
      final capEnd = dropCapEnd(text);
      // Explicit strut makes two line boxes stable across fonts and DPI settings.
      final strut = StrutStyle.fromTextStyle(style, forceStrutHeight: true);
      final lineProbe = TextPainter(
        text: TextSpan(text: 'Ag', style: style),
        textScaler: scaler,
        strutStyle: strut,
        textDirection: direction,
      )..layout();
      final lineHeight = lineProbe.height;
      lineProbe.dispose();
      final capStyle = style.copyWith(
        fontFamily: 'Georgia',
        fontSize: lineHeight * 2 / scaler.scale(1),
        height: 1,
        color: accent,
        fontWeight: FontWeight.normal,
      );
      final capProbe = TextPainter(
        text: segment.span(capStyle, ink, end: capEnd),
        textScaler: scaler,
        textDirection: direction,
      )..layout();
      final capWidth = (capProbe.width + scaler.scale(7)).clamp(
        1.0,
        box.maxWidth * 0.65,
      );
      capProbe.dispose();
      final width = (box.maxWidth - capWidth).clamp(1.0, double.infinity);
      final measure = TextPainter(
        text: segment.span(style, ink, start: capEnd),
        textScaler: scaler,
        textDirection: direction,
        strutStyle: strut,
      )..layout(maxWidth: width);
      final lines = measure.computeLineMetrics();
      final localEnd = lines.length <= 2
          ? text.length - capEnd
          : measure
                .getLineBoundary(
                  measure.getPositionForOffset(
                    Offset(0, lines[1].baseline - lines[1].ascent / 2),
                  ),
                )
                .end;
      final split = capEnd + localEnd;
      measure.dispose();
      // Exclude a terminal hard newline from the narrow Text widget; rendering it
      // there would manufacture an extra empty line before the full-width tail.
      final headEnd = split > capEnd && text[split - 1] == '\n'
          ? split - 1
          : split;
      Widget part(int start, int end, TextStyle textStyle, {Key? key}) =>
          DefaultTextStyle.merge(
            style: textStyle,
            child: DocumentText(
              key: key,
              segment: segment,
              style: textStyle,
              ink: ink,
              fill: fill,
              active: active,
              start: start,
              end: end,
              strut: textStyle == style ? strut : null,
            ),
          );
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
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: part(
                      0,
                      capEnd,
                      capStyle,
                      key: const ValueKey('summary-drop-cap'),
                    ),
                  ),
                ),
                Expanded(
                  child: part(
                    capEnd,
                    headEnd,
                    style,
                    key: const ValueKey('summary-first-two-lines'),
                  ),
                ),
              ],
            ),
            if (split < text.length)
              part(
                split,
                text.length,
                style,
                key: const ValueKey('summary-continuation'),
              ),
          ],
        ),
      );
    },
  );
}
