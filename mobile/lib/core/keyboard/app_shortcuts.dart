import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Opens the search page.
class OpenSearchIntent extends Intent {
  const OpenSearchIntent();
}

/// Goes back one page (closing a dialog or sheet first).
class GoBackIntent extends Intent {
  const GoBackIntent();
}

/// Esc on a page: leaves a focused text field, else goes back.
class EscapeIntent extends Intent {
  const EscapeIntent();
}

/// Whether keyboard focus is in an editable text field, where keys are text
/// and must not trigger shortcuts.
bool isEditingText() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  return context.widget is EditableText || context.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// Whether keyboard focus is inside a dialog, sheet or menu (a popup route),
/// which handles Esc itself (as [DismissIntent]).
bool isInPopup() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context != null && ModalRoute.of(context) is PopupRoute;
}

/// Whether shortcuts use Command (Apple platforms) rather than Control.
bool get usesCommandKey =>
    defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;

/// App-wide keyboard shortcuts, active wherever a hardware keyboard is:
///
/// * Ctrl+F (Cmd+F on macOS) or `/`: open search.
/// * Esc: leave a text field, else go back. Dialogs, sheets and menus are
///   left to close themselves (Flutter's [DismissIntent]).
/// * Alt+Left: go back (closing a dialog or sheet first).
///
/// None of them fire while a text field has focus, except Esc, which then
/// only leaves the field. Pages with their own keys (the reader) handle them
/// first, since key events reach the focused widget's shortcuts before
/// these.
class AppShortcuts extends StatelessWidget {
  final GoRouter router;
  final Widget child;

  const AppShortcuts({super.key, required this.router, required this.child});

  @override
  Widget build(BuildContext context) {
    final command = usesCommandKey;
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyF, control: !command, meta: command): const OpenSearchIntent(),
        const CharacterActivator('/'): const OpenSearchIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): const GoBackIntent(),
        const SingleActivator(LogicalKeyboardKey.escape): const EscapeIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          OpenSearchIntent: _OpenSearchAction(router),
          GoBackIntent: _GoBackAction(router),
          EscapeIntent: _EscapeAction(router),
        },
        child: child,
      ),
    );
  }
}

NavigatorState? _navigator(GoRouter router) => router.routerDelegate.navigatorKey.currentState;

class _OpenSearchAction extends Action<OpenSearchIntent> {
  final GoRouter router;

  _OpenSearchAction(this.router);

  @override
  bool isEnabled(OpenSearchIntent intent) =>
      !isEditingText() && router.routerDelegate.currentConfiguration.uri.path != '/search';

  @override
  Object? invoke(OpenSearchIntent intent) => router.push('/search');
}

class _GoBackAction extends Action<GoBackIntent> {
  final GoRouter router;

  _GoBackAction(this.router);

  @override
  bool isEnabled(GoBackIntent intent) => !isEditingText() && (_navigator(router)?.canPop() ?? false);

  @override
  Object? invoke(GoBackIntent intent) => _navigator(router)?.maybePop();
}

class _EscapeAction extends Action<EscapeIntent> {
  final GoRouter router;

  _EscapeAction(this.router);

  // Disabled in popups, so the key goes on to their DismissIntent.
  @override
  bool isEnabled(EscapeIntent intent) =>
      !isInPopup() && (isEditingText() || (_navigator(router)?.canPop() ?? false));

  @override
  Object? invoke(EscapeIntent intent) {
    if (isEditingText()) {
      FocusManager.instance.primaryFocus?.unfocus();
      return null;
    }
    return _navigator(router)?.maybePop();
  }
}
