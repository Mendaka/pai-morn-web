import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Wraps the browser Fullscreen API so the lyrics view's "Full" mode can
/// hand the whole tab over to the lyrics, and correctly detect drop-outs
/// the app didn't trigger itself (e.g. the user pressing Esc).
class FullscreenController {
  void enter() {
    web.document.documentElement?.requestFullscreen();
  }

  void exit() {
    if (web.document.fullscreenElement != null) {
      web.document.exitFullscreen();
    }
  }

  bool get isActive => web.document.fullscreenElement != null;

  void onChange(void Function() callback) {
    web.document.addEventListener(
      'fullscreenchange',
      ((web.Event _) => callback()).toJS,
    );
  }
}
