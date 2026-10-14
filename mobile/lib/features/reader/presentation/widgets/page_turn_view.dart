import 'package:flutter/material.dart';

/// How page mode moves between pages.
enum PageTurnEffect {
  /// Instant.
  none,

  /// Both pages move together.
  slide,

  /// The new page slides over the old one, which stays put.
  cover;

  static PageTurnEffect parse(String value) =>
      PageTurnEffect.values.firstWhere((e) => e.name == value, orElse: () => PageTurnEffect.slide);
}

/// Lets the owner of a [PageTurnView] turn pages (e.g. from tap zones).
class PageTurnController {
  _PageTurnViewState? _state;

  /// Turns one page forward (1) or back (-1), animated per the view's effect.
  void turn(int direction) => _state?._turn(direction);

  bool get isTurning => _state?._isTurning ?? false;
}

/// Shows one page of a paged chapter and turns pages with a horizontal drag
/// that follows the finger (then flings or settles), or with [PageTurnController.turn].
///
/// Pages are built by [pageBuilder] for 0 until [pageCount]; it is also asked
/// for -1 and [pageCount], the pages just past either end (the neighbouring
/// chapters), when [canLeave] allows going that way. Turning onto one of
/// those calls [onLeave] and keeps showing it, so the owner can swap in the
/// next chapter without a visible jump.
///
/// Every page is drawn on an opaque [background] and in its own repaint
/// boundary, so moving pages only re-composites. With the platform's reduce
/// motion setting, every effect behaves like [PageTurnEffect.none].
class PageTurnView extends StatefulWidget {
  final int page;
  final int pageCount;
  final Widget Function(BuildContext context, int index) pageBuilder;
  final bool Function(int direction) canLeave;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onLeave;
  final PageTurnEffect effect;
  final Color background;
  final PageTurnController? controller;

  /// Changes when the pages are rebuilt from different content (e.g. a new
  /// pagination), so cached page widgets are not reused across them.
  final Object? contentKey;

  const PageTurnView({
    super.key,
    required this.page,
    required this.pageCount,
    required this.pageBuilder,
    required this.canLeave,
    required this.onPageChanged,
    required this.onLeave,
    required this.effect,
    required this.background,
    this.controller,
    this.contentKey,
  });

  @override
  State<PageTurnView> createState() => _PageTurnViewState();
}

class _PageTurnViewState extends State<PageTurnView> with SingleTickerProviderStateMixin {
  static const _turnDuration = Duration(milliseconds: 300);

  /// Fraction of the width a drag must cover to turn without a fling.
  static const _turnThreshold = 0.3;

  /// Logical pixels per second that count as a fling.
  static const _flingVelocity = 400.0;

  /// The displacement of the current page in widths: below 0 the next page
  /// is coming in, above 0 the previous one.
  late final AnimationController _offset = AnimationController.unbounded(vsync: this)
    ..addStatusListener(_onAnimationStatus);
  late int _page = widget.page;

  /// The turn the running animation completes (-1, 1), or 0 when it settles
  /// back.
  int _pending = 0;
  double _dragDx = 0;
  double _width = 1;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(PageTurnView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._state == this) oldWidget.controller?._state = null;
      widget.controller?._state = this;
    }
    // The owner moved to another page (a jump or new pagination).
    if (widget.page != oldWidget.page && widget.page != _page) {
      _offset.stop();
      _offset.value = 0;
      _pending = 0;
      _page = widget.page;
    } else if (_page >= 0 && _page < widget.pageCount && _page != widget.page && !_isTurning) {
      _page = widget.page;
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller?._state = null;
    _offset.dispose();
    super.dispose();
  }

  bool get _left => _page < 0 || _page >= widget.pageCount;

  bool get _isTurning => _offset.isAnimating || _offset.value != 0;

  PageTurnEffect get _effect =>
      MediaQuery.maybeDisableAnimationsOf(context) == true ? PageTurnEffect.none : widget.effect;

  bool _canTurn(int direction) {
    if (_left) return false;
    final target = _page + direction;
    if (target >= 0 && target < widget.pageCount) return true;
    return widget.canLeave(direction);
  }

  void _turn(int direction) {
    if (_offset.isAnimating) _finishNow();
    if (!_canTurn(direction)) return;
    if (_effect == PageTurnEffect.none) {
      _commit(direction);
      return;
    }
    _pending = direction;
    _offset.animateTo(-direction.toDouble(), duration: _turnDuration, curve: Curves.easeInOut);
  }

  /// Jumps to the end of the running animation.
  void _finishNow() {
    final pending = _pending;
    _offset.stop();
    _offset.value = 0;
    _pending = 0;
    if (pending != 0) _commit(pending);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final pending = _pending;
    _pending = 0;
    if (pending != 0) {
      _offset.value = 0;
      _commit(pending);
    }
  }

  void _commit(int direction) {
    final target = _page + direction;
    setState(() => _page = target);
    if (target >= 0 && target < widget.pageCount) {
      widget.onPageChanged(target);
    } else {
      widget.onLeave(direction);
    }
  }

  // ---------------------------------------------------------------- drag

  void _onDragStart(DragStartDetails details) {
    if (_offset.isAnimating) {
      if (_pending != 0) {
        // Mid-turn: finish it and start a fresh drag from the new page.
        _finishNow();
      } else {
        // Settling back: pick it up where it is.
        _offset.stop();
      }
    }
    _dragDx = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    _dragDx += delta;
    if (_effect == PageTurnEffect.none || _left) return;
    var next = _offset.value + delta / _width;
    if (next < 0 && !_canTurn(1)) next = 0;
    if (next > 0 && !_canTurn(-1)) next = 0;
    _offset.value = next.clamp(-1.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_left) return;
    if (_effect == PageTurnEffect.none) {
      final fling = velocity.abs() > _flingVelocity;
      if (!fling && _dragDx.abs() < _width * 0.15) return;
      final direction = (fling ? velocity : _dragDx) < 0 ? 1 : -1;
      if (_canTurn(direction)) _commit(direction);
      return;
    }
    final value = _offset.value;
    var direction = value < 0 ? 1 : (value > 0 ? -1 : 0);
    if (direction == 0 && velocity.abs() > _flingVelocity) {
      direction = velocity < 0 ? 1 : -1;
      if (!_canTurn(direction)) direction = 0;
    }
    if (direction == 0) return;
    // Velocity in the turning direction is negative for "next".
    final along = -velocity * direction;
    final commit = along > _flingVelocity || (value.abs() > _turnThreshold && along > -_flingVelocity);
    _settle(commit ? direction : 0, velocity);
  }

  void _onDragCancel() {
    if (_offset.value != 0 && !_offset.isAnimating) _settle(0, 0);
  }

  /// Animates to the end of a turn in [direction], or back to rest when 0.
  void _settle(int direction, double velocity) {
    final target = -direction.toDouble();
    final distance = (target - _offset.value).abs();
    final speed = velocity.abs() / _width; // widths per second
    var ms = distance * _turnDuration.inMilliseconds;
    // A fling finishes at least as fast as the finger was moving.
    if (speed > 0) ms = ms < distance / speed * 1000 ? ms : distance / speed * 1000;
    _pending = direction;
    _offset.animateTo(target,
        duration: Duration(milliseconds: ms.round().clamp(80, 400)), curve: Curves.easeOutCubic);
  }

  // ---------------------------------------------------------------- view

  Widget _pageView(int index) => RepaintBoundary(
        child: ColoredBox(
          color: widget.background,
          child: SizedBox.expand(child: widget.pageBuilder(context, index)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _width = constraints.maxWidth <= 0 ? 1 : constraints.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        onHorizontalDragCancel: _onDragCancel,
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _offset,
            builder: (context, _) => _buildPages(_offset.value),
          ),
        ),
      );
    });
  }

  Widget _buildPages(double offset) {
    final w = _width;
    final key = widget.contentKey;
    Widget positioned(int index, double dx, {bool shadow = false}) {
      Widget child = _pageView(index);
      if (shadow) {
        child = DecoratedBox(
          decoration: const BoxDecoration(
            boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 16)],
          ),
          child: child,
        );
      }
      return Transform.translate(key: ValueKey((key, index)), offset: Offset(dx, 0), child: child);
    }

    // The same structure at rest and in motion, so the current page's
    // widgets are kept (not rebuilt) when a drag starts.
    if (offset == 0) {
      return IgnorePointer(ignoring: false, child: Stack(fit: StackFit.expand, children: [positioned(_page, 0)]));
    }
    final next = offset < 0;
    final neighbour = _page + (next ? 1 : -1);
    final List<Widget> children;
    switch (_effect) {
      case PageTurnEffect.cover:
        children = [
          positioned(_page, 0),
          positioned(neighbour, next ? w + offset * w : -w + offset * w, shadow: true),
        ];
      case PageTurnEffect.slide:
      case PageTurnEffect.none:
        children = [
          positioned(_page, offset * w),
          positioned(neighbour, offset * w + (next ? w : -w)),
        ];
    }
    // Pages in motion take no taps or long-presses.
    return IgnorePointer(child: Stack(fit: StackFit.expand, children: children));
  }
}
