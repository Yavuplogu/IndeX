import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:index_windows/document_text.dart';

void main() {
  test(
    'Lettrine : ponctuation initiale et premier caractère alphanumérique',
    () {
      for (final entry in {
        'C’était une première': 'C',
        '« Une histoire': '« U',
        '“L’histoire': '“L',
        "'Été": "'É",
        '... 1945': '... 1',
        'Été': 'É',
        'E\u0301té': 'E\u0301',
      }.entries) {
        expect(entry.key.substring(0, dropCapEnd(entry.key)), entry.value);
      }
    },
  );

  testWidgets(
    'Lettrine : deux lignes exactes, texte conservé, police et zoom hérités',
    (tester) async {
      const text =
          '« C’était une première : la prise de contrôle en pleine mer d’un paquebot transportant plus de six cents passagers et trois cent cinquante hommes d’équipage... Acte de piratage ou spectaculaire manifestation politique ?\n\nUn autre paragraphe conserve sa place.';
      for (final width in [310.0, 440.0, 640.0]) {
        for (final scale in [1.0, 1.3]) {
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: width,
                        child: DefaultTextStyle(
                          style: const TextStyle(
                            fontFamily: 'Ahem',
                            fontSize: 17,
                            letterSpacing: 0.7,
                          ),
                          child: DropCapText(
                            segment: const TextSegment('summary', text, [
                              DocumentMatch('m', 'summary', 0, 21, 28),
                            ]),
                            accent: Colors.brown,
                            ink: Colors.red,
                            fill: Colors.redAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          final head = find.byKey(const ValueKey('summary-first-two-lines'));
          final rich = tester.widget<RichText>(
            find.descendant(of: head, matching: find.byType(RichText)),
          );
          final painter = TextPainter(
            text: rich.text,
            textDirection: TextDirection.ltr,
            strutStyle: rich.strutStyle,
            textScaler: rich.textScaler,
          )..layout(maxWidth: tester.getSize(head).width);
          expect(
            painter.computeLineMetrics(),
            hasLength(2),
            reason: 'largeur=$width zoom=$scale',
          );
          final cap = find.byKey(const ValueKey('summary-drop-cap'));
          final tail = find.byKey(const ValueKey('summary-continuation'));
          String plain(Finder finder) => tester
              .widget<RichText>(
                find.descendant(of: finder, matching: find.byType(RichText)),
              )
              .text
              .toPlainText();
          expect('${plain(cap)}${plain(head)}${plain(tail)}', text);
          expect(
            tester.getTopLeft(tail).dy,
            closeTo(tester.getTopLeft(head).dy + painter.height, 0.1),
          );
          final render = tester.renderObject<RenderParagraph>(
            find.descendant(of: head, matching: find.byType(RichText)),
          );
          expect(render.didExceedMaxLines, isFalse);
          painter.dispose();
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
}
