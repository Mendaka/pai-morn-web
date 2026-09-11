import 'dart:js_interop';
import 'package:web/web.dart' as web;

// Chrome/Edge/Android's install-prompt event — not part of any web standard,
// so package:web doesn't type it. Constructing this extension type over the
// raw web.Event gives access to the one extra member (`prompt()`) we need,
// same "view" pattern used for any untyped JS object in this codebase.
extension type _BeforeInstallPromptEvent(web.Event _) implements web.Event {
  external JSPromise prompt();
}

// `navigator.standalone` is a non-standard iOS Safari-only property that
// package:web doesn't type — this view adds just that one getter.
extension type _IOSNavigator(JSObject _) implements JSObject {
  external JSBoolean? get standalone;
}

/// Bridges the browser's PWA install machinery into Dart:
///  - Android/Desktop Chrome fires `beforeinstallprompt`, which this class
///    captures (and suppresses the browser's own mini-infobar for) so a
///    custom "Install App" button can trigger it later via [promptInstall].
///  - iOS Safari never fires that event at all — there is no programmatic
///    install API there, only the user manually doing Share > Add to Home
///    Screen — so [isIOS] lets the UI show instructions instead of a button.
///  - [isStandalone] detects an already-installed/launched-from-home-screen
///    session (either the cross-browser `display-mode` media query, or
///    iOS Safari's own `navigator.standalone` flag), so the UI can hide
///    itself entirely once there's nothing left to offer.
class PwaInstallController {
  _BeforeInstallPromptEvent? _deferredEvent;

  void init(void Function() onInstallable) {
    web.window.addEventListener(
      'beforeinstallprompt',
      (web.Event event) {
        event.preventDefault();
        _deferredEvent = _BeforeInstallPromptEvent(event);
        onInstallable();
      }.toJS,
    );
  }

  bool get canPromptInstall => _deferredEvent != null;

  bool get isIOS {
    final ua = web.window.navigator.userAgent.toLowerCase();
    return ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
  }

  bool get isStandalone {
    final displayModeStandalone =
        web.window.matchMedia('(display-mode: standalone)').matches;
    final iosStandalone = _IOSNavigator(web.window.navigator).standalone;
    return displayModeStandalone || (iosStandalone?.toDart ?? false);
  }

  Future<void> promptInstall() async {
    final event = _deferredEvent;
    if (event == null) return;
    await event.prompt().toDart;
    // A given deferred prompt can only be used once (whether accepted or
    // dismissed) — Chrome fires a fresh beforeinstallprompt for any later
    // opportunity, so there's no need to keep this one around.
    _deferredEvent = null;
  }
}
