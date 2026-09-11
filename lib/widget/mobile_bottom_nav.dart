import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pai_morn_web/auth/auth_provider.dart';
import 'package:pai_morn_web/menu_item.dart';
import 'package:provider/provider.dart';

/// Replaces the footer on mobile — the primary destinations (previously
/// duplicated as text links inside the navbar's hamburger dropdown) live
/// here instead as an icon-only, equal-width tab strip pinned to the
/// bottom of the screen, the layout mobile users actually expect from an
/// app-like bottom nav rather than a dropdown menu. The hamburger itself
/// still exists (see navbar.dart) but now holds the site-info links that
/// used to be in the footer (About/Guide/Contact/Privacy/Terms) instead —
/// nothing here duplicates that content or vice versa.
///
/// Signed-in members get a 6th, center "+" action (Submit a Song) in place
/// of Tuner — Tuner moves into the navbar's hamburger menu for signed-in
/// users only (still one tap away there, see navbar.dart) so nothing
/// becomes unreachable on mobile, it's just relocated to make room for the
/// action a member reaches for far more often. Signed-out visitors keep the
/// original 5-tab layout untouched.
class MobileBottomNav extends StatelessWidget {
  const MobileBottomNav({
    super.key,
    required this.selectedMenu,
    required this.onMenuSelected,
  });

  final MenuItem selectedMenu;
  final ValueChanged<MenuItem> onMenuSelected;

  static const _guestItems = [
    (MenuItem.home, FontAwesomeIcons.house),
    (MenuItem.book, FontAwesomeIcons.book),
    (MenuItem.tuner, FontAwesomeIcons.gaugeHigh),
    (MenuItem.chords, FontAwesomeIcons.guitar),
    (MenuItem.community, FontAwesomeIcons.peopleGroup),
  ];

  static const _memberItems = [
    (MenuItem.home, FontAwesomeIcons.house),
    (MenuItem.book, FontAwesomeIcons.book),
    (MenuItem.submitSong, FontAwesomeIcons.plus),
    (MenuItem.chords, FontAwesomeIcons.guitar),
    (MenuItem.community, FontAwesomeIcons.peopleGroup),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLoggedIn = context.watch<AuthProvider>().isLoggedIn;
    final items = isLoggedIn ? _memberItems : _guestItems;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.onSurface.withOpacity(0.08))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              for (final (menu, icon) in items)
                Expanded(
                  child: menu == MenuItem.submitSong
                      ? _actionTab(scheme, menu, icon)
                      : _tab(scheme, menu, icon),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(ColorScheme scheme, MenuItem menu, IconData icon) {
    final isSelected = selectedMenu == menu;
    return InkWell(
      onTap: () => onMenuSelected(menu),
      child: Center(
        child: FaIcon(
          icon,
          size: 20,
          // Full-opacity onSurface for selected vs. faded onSurface for the
          // rest — same monochrome selected/unselected treatment navbar.dart
          // uses for its own desktop tabs, deliberately not scheme.primary
          // (this app's ColorScheme.light sets primary to white, which would
          // render an invisible icon on the white/light surface behind it).
          color: isSelected ? scheme.onSurface : scheme.onSurface.withOpacity(0.4),
        ),
      ),
    );
  }

  // The center "Submit a Song" action reads as a button, not a nav tab —
  // filled circle in the same monochrome onSurface/surface pairing every
  // other flat-design surface in this app uses instead of introducing a
  // one-off accent color (this theme has no accent; secondary is just
  // black/white, see main.dart's ColorScheme).
  Widget _actionTab(ColorScheme scheme, MenuItem menu, IconData icon) {
    return InkWell(
      onTap: () => onMenuSelected(menu),
      child: Center(
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: scheme.onSurface, shape: BoxShape.circle),
          child: FaIcon(icon, size: 16, color: scheme.surface),
        ),
      ),
    );
  }
}
