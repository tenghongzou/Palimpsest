import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Splits a chapter into screen-sized pages for page mode.
///
/// Every block's height is measured up front with [TextPainter] using the
/// same style, scaler and locale the reader renders with, and paragraphs are
/// split only at line boundaries, so a page never cuts a line in half and
/// turning pages never needs a layout pass of the whole chapter.

/// One block on a page.
sealed class PageBlock {
  final double height;
  const PageBlock(this.height);
}

/// "Offline copy" / "showing a translation" notes above the title.
class NoticeBlock extends PageBlock {
  final NoticeKind kind;
  const NoticeBlock(this.kind, super.height);
}

enum NoticeKind { offline, translation }

class TitleBlock extends PageBlock {
  /// Space below the title, included in [height].
  static const gap = 32.0;
  const TitleBlock(super.height);
}

/// A whole paragraph or the part of it that fits on a page.
class ParagraphBlock extends PageBlock {
  final int index;

  /// The text shown, with the indent when [first].
  final String text;

  /// Offset of [text] in the paragraph (without the indent).
  final int start;
  final bool first;
  final bool last;

  /// Space below a paragraph's last part, not included in [height].
  final double spacing;

  const ParagraphBlock({
    required this.index,
    required this.text,
    required this.start,
    required this.first,
    required this.last,
    required double height,
    this.spacing = 0,
  }) : super(height);
}

/// Chapter navigation and the chapter comments button.
class FooterBlock extends PageBlock {
  static const gap = 32.0;
  const FooterBlock(super.height);
}

/// Where a page starts: a paragraph and a character offset in it. Pages
/// before the first paragraph start at (0, 0); a page holding only the
/// footer starts at (paragraph count, 0).
typedef PageAnchor = (int paragraph, int offset);

class ReaderPageContent {
  final List<PageBlock> blocks;
  final PageAnchor anchor;

  const ReaderPageContent(this.blocks, this.anchor);

  /// The first paragraph on this page (for progress and bookmarks).
  int get firstParagraph => anchor.$1;
}

class Pagination {
  final List<ReaderPageContent> pages;

  const Pagination(this.pages);

  int get length => pages.length;

  /// The page holding [anchor] (the first of pages starting at the same
  /// place, e.g. a title page before the first paragraph).
  int pageFor(PageAnchor anchor) {
    var result = 0;
    for (var i = 1; i < pages.length; i++) {
      final a = pages[i].anchor;
      if (_compare(a, anchor) <= 0 && _compare(a, pages[result].anchor) > 0) result = i;
    }
    return result;
  }

  static int _compare(PageAnchor a, PageAnchor b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2;
}

/// The indent added before every paragraph.
const paragraphIndent = '　　';

const paragraphSpacing = 16.0;

/// Size of the comment count bubble at the end of a commented paragraph, for
/// layout and measuring. The bubble is drawn inside a box of this size.
Size commentBubbleSize(int count, TextScaler scaler) {
  final label = TextPainter(
    text: TextSpan(text: count > 99 ? '99+' : '$count', style: const TextStyle(fontSize: 11, height: 1.2, letterSpacing: 0)),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout();
  final size = Size(6 + 4 + 5 + 5 + 2 + 11 + 2 + label.width, 4 + 4 + 1 + 1 + 2 + math.max(11, label.height));
  label.dispose();
  return Size(size.width.ceilToDouble(), size.height.ceilToDouble());
}

/// Everything that decides where pages break. Two equal specs paginate the
/// same, so the result can be cached by spec.
class PaginationSpec {
  final List<String> paragraphs;
  final String title;

  /// The body style, already merged with the ambient [DefaultTextStyle].
  final TextStyle textStyle;
  final TextStyle titleStyle;
  final TextStyle noticeStyle;
  final Size size;
  final TextScaler textScaler;
  final Locale? locale;
  final TextDirection textDirection;
  final TextHeightBehavior? textHeightBehavior;
  final bool offlineNotice;
  final bool translationNotice;

  /// Comment counts by paragraph (bubbles take space at paragraph ends).
  final Map<int, int> commentCounts;

  const PaginationSpec({
    required this.paragraphs,
    required this.title,
    required this.textStyle,
    required this.titleStyle,
    required this.noticeStyle,
    required this.size,
    this.textScaler = TextScaler.noScaling,
    this.locale,
    this.textDirection = TextDirection.ltr,
    this.textHeightBehavior,
    this.offlineNotice = false,
    this.translationNotice = false,
    this.commentCounts = const {},
  });

  /// Height of a notice line (12px text plus a compact button).
  double get noticeHeight {
    final h = math.max(textScaler.scale(12) * 1.5, textScaler.scale(14) * 1.5);
    return (h + 16 + 12).ceilToDouble();
  }

  /// Height of one footer row (a text button).
  double get footerRowHeight => math.max(48.0, (textScaler.scale(14) * 1.4 + 24).ceilToDouble());

  /// The footer: a gap, chapter navigation and the comments button.
  double get footerHeight => FooterBlock.gap + 2 * footerRowHeight;

  Pagination paginate() => _Paginator(this).run();
}

class _Paginator {
  final PaginationSpec spec;
  final pages = <ReaderPageContent>[];
  var _blocks = <PageBlock>[];
  PageAnchor _anchor = (0, 0);
  double _used = 0;

  _Paginator(this.spec);

  double get _height => math.max(1, spec.size.height);
  double get _width => math.max(1, spec.size.width);
  double get _remaining => _height - _used;

  void _add(PageBlock block, {double after = 0}) {
    _blocks.add(block);
    _used += block.height + after;
  }

  void _newPage(PageAnchor next) {
    if (_blocks.isNotEmpty) pages.add(ReaderPageContent(_blocks, _anchor));
    _blocks = [];
    _used = 0;
    _anchor = next;
  }

  TextPainter _painter(String text, TextStyle style, {Size? placeholder, TextAlign align = TextAlign.start}) {
    final painter = TextPainter(
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: text),
          if (placeholder != null)
            const WidgetSpan(alignment: PlaceholderAlignment.middle, child: SizedBox.shrink()),
        ],
      ),
      textAlign: align,
      textDirection: spec.textDirection,
      textScaler: spec.textScaler,
      locale: spec.locale,
      textHeightBehavior: spec.textHeightBehavior,
    );
    if (placeholder != null) {
      painter.setPlaceholderDimensions([
        PlaceholderDimensions(size: placeholder, alignment: PlaceholderAlignment.middle),
      ]);
    }
    painter.layout(maxWidth: _width);
    return painter;
  }

  Pagination run() {
    if (spec.offlineNotice) _add(NoticeBlock(NoticeKind.offline, spec.noticeHeight));
    if (spec.translationNotice) _add(NoticeBlock(NoticeKind.translation, spec.noticeHeight));
    final title = _painter(spec.title, spec.titleStyle, align: TextAlign.center);
    _add(TitleBlock(title.height.ceilToDouble() + TitleBlock.gap));
    title.dispose();

    for (var i = 0; i < spec.paragraphs.length; i++) {
      _paragraph(i, spec.paragraphs[i]);
    }

    if (_blocks.isNotEmpty && _remaining < spec.footerHeight) _newPage((spec.paragraphs.length, 0));
    _add(FooterBlock(spec.footerHeight));
    _newPage((0, 0));
    return Pagination(pages);
  }

  void _paragraph(int index, String paragraph) {
    final count = spec.commentCounts[index] ?? 0;
    final bubble = count > 0 ? commentBubbleSize(count, spec.textScaler) : null;
    var text = '$paragraphIndent$paragraph';
    var start = 0;
    var first = true;
    while (true) {
      final painter = _painter(text, spec.textStyle, placeholder: bubble);
      try {
        final height = painter.height;
        if (height <= _remaining + 0.5) {
          _add(
            ParagraphBlock(
                index: index, text: text, start: start, first: first, last: true, height: height, spacing: paragraphSpacing),
            after: paragraphSpacing,
          );
          return;
        }
        // Take the lines that fit.
        final lines = painter.computeLineMetrics();
        var fit = 0;
        var used = 0.0;
        while (fit < lines.length && used + lines[fit].height <= _remaining + 0.5) {
          used += lines[fit].height;
          fit++;
        }
        if (fit == 0 && _blocks.isNotEmpty) {
          _newPage((index, start));
          continue;
        }
        // A single line taller than a page still has to go somewhere.
        if (fit == 0) {
          fit = 1;
          used = lines.first.height;
        }
        final split = fit < lines.length ? _lineStart(painter, used + lines[fit].height / 2) : text.length;
        if (split <= 0 || split >= text.length) {
          // Could not find a break: place it whole and let the page clip.
          _add(ParagraphBlock(
              index: index, text: text, start: start, first: first, last: true, height: height, spacing: paragraphSpacing));
          _newPage((index + 1, 0));
          return;
        }
        _add(ParagraphBlock(
            index: index, text: text.substring(0, split), start: start, first: first, last: false, height: used));
        final consumed = first ? math.max(0, split - paragraphIndent.length) : split;
        start += consumed;
        text = text.substring(split);
        first = false;
        _newPage((index, start));
      } finally {
        painter.dispose();
      }
    }
  }

  /// Text offset where the line at [y] begins.
  int _lineStart(TextPainter painter, double y) {
    final position = painter.getPositionForOffset(Offset(0, y));
    return painter.getLineBoundary(position).start;
  }
}
