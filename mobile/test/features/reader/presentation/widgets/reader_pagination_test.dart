import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/features/reader/presentation/widgets/reader_pagination.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final paragraphs = [
    for (var i = 0; i < 40; i++) '第${i + 1}段${'字' * (i * 7 % 90)}',
  ];

  PaginationSpec spec({double fontSize = 18, Size size = const Size(300, 400), Map<int, int> counts = const {}}) =>
      PaginationSpec(
        paragraphs: paragraphs,
        title: '第一章',
        textStyle: TextStyle(fontSize: fontSize, height: 1.8),
        titleStyle: TextStyle(fontSize: fontSize + 4, fontWeight: FontWeight.bold),
        noticeStyle: const TextStyle(fontSize: 12),
        size: size,
        commentCounts: counts,
      );

  /// Each paragraph's text as reassembled from its parts on every page.
  Map<int, String> reassemble(Pagination p) {
    final texts = <int, String>{};
    for (final page in p.pages) {
      for (final b in page.blocks.whereType<ParagraphBlock>()) {
        texts[b.index] = (texts[b.index] ?? '') + b.text;
      }
    }
    return texts;
  }

  test('every paragraph appears once, in order, split only between pages', () {
    final p = spec().paginate();
    expect(p.length, greaterThan(3));
    final texts = reassemble(p);
    for (var i = 0; i < paragraphs.length; i++) {
      expect(texts[i], '$paragraphIndent${paragraphs[i]}');
    }
    // A split paragraph ends its page and continues at the top of the next.
    for (var i = 0; i < p.length; i++) {
      final blocks = p.pages[i].blocks;
      for (var j = 0; j < blocks.length; j++) {
        final b = blocks[j];
        if (b is ParagraphBlock && !b.last) {
          expect(j, blocks.length - 1);
          final next = p.pages[i + 1].blocks.first as ParagraphBlock;
          expect(next.index, b.index);
          expect(next.first, isFalse);
        }
      }
    }
    expect(p.pages.first.blocks.first, isA<TitleBlock>());
    expect(p.pages.last.blocks.last, isA<FooterBlock>());
  });

  test('pages are filled without overflowing', () {
    const size = Size(300, 400);
    final p = spec(size: size).paginate();
    for (final page in p.pages) {
      final used = page.blocks.fold<double>(0, (sum, b) => sum + b.height + (b is ParagraphBlock ? b.spacing : 0));
      final lastSpacing = page.blocks.last is ParagraphBlock ? (page.blocks.last as ParagraphBlock).spacing : 0;
      expect(used - lastSpacing, lessThanOrEqualTo(size.height + 0.5));
    }
  });

  test('anchors find the page holding a position', () {
    final p = spec().paginate();
    expect(p.pageFor((0, 0)), 0);
    for (var i = 1; i < p.length; i++) {
      expect(p.pageFor(p.pages[i].anchor), i);
    }
    final last = p.pages.lastWhere((page) => page.blocks.any((b) => b is ParagraphBlock));
    expect(p.pageFor((paragraphs.length - 1, 0)), p.pages.indexOf(last));
  });

  test('bigger text makes more pages; comment bubbles take room', () {
    final small = spec(fontSize: 14).paginate();
    final big = spec(fontSize: 26).paginate();
    expect(big.length, greaterThan(small.length));

    final plain = spec().paginate();
    final withBubbles = spec(counts: {for (var i = 0; i < paragraphs.length; i++) i: 120}).paginate();
    expect(reassemble(withBubbles).length, paragraphs.length);
    expect(withBubbles.length, greaterThanOrEqualTo(plain.length));
  });

  test('a tiny page still makes progress', () {
    final p = spec(size: const Size(120, 20)).paginate();
    expect(reassemble(p).length, paragraphs.length);
  });
}
