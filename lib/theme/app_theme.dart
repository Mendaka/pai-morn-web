import 'package:flutter/material.dart';

/// Shared border-radius scale. Collapses the ad hoc 6/8/10/12/16/20 values
/// that had accumulated across screens down to four steps.
class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}

/// Shared spacing scale for section/element gaps.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}

/// Shared shadow recipes, replacing the 3+ inline blur/opacity/offset
/// combinations that had been invented independently per screen.
class AppShadows {
  AppShadows._();

  /// For elevated panels/cards that should read as clearly "lifted" —
  /// e.g. the lyrics-reading panel, product-preview card.
  static List<BoxShadow> soft(Color onSurface) => [
    BoxShadow(
      color: onSurface.withOpacity(0.08),
      offset: const Offset(0, 4),
      blurRadius: 16,
    ),
  ];

  /// For smaller surfaces — list-row cards, chips, buttons — that only need
  /// a light separation from the background.
  static List<BoxShadow> subtle(Color onSurface) => [
    BoxShadow(
      color: onSurface.withOpacity(0.10),
      offset: const Offset(0, 2),
      blurRadius: 8,
    ),
  ];
}

/// Shared responsive breakpoints (max width in logical pixels below which
/// the narrower layout applies). Replaces the three different raw literals
/// (900, 600, and a separate home_screen 900/600 pair) that had drifted
/// apart across files.
class AppBreakpoints {
  AppBreakpoints._();

  static const double tablet = 600;
  static const double desktop = 900;
}
