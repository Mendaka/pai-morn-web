import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pai_morn_web/navbar.dart';
import 'package:pai_morn_web/menu_item.dart';
import 'package:pai_morn_web/theme/app_theme.dart';
import 'package:pai_morn_web/widget/account_drawer.dart';
import 'package:pai_morn_web/widget/footer.dart';
import 'package:pai_morn_web/widget/mobile_bottom_nav.dart';
import 'package:pai_morn_web/widget/quick_search_dialog.dart';

/// The persistent chrome (Navbar + account drawer) wrapping every top-level
/// page — used as the `builder` for go_router's `ShellRoute` in main.dart.
/// `child` is whichever page route currently matched; `currentLocation` is
/// the router's current path, used only to derive which Navbar item to
/// highlight (see [menuItemForLocation]) since this widget no longer owns
/// navigation state itself — every menu tap just calls `context.go(...)`.
class MyHomePage extends StatelessWidget {
  final Widget child;
  final String currentLocation;
  final VoidCallback onToggleTheme;

  const MyHomePage({
    super.key,
    required this.child,
    required this.currentLocation,
    required this.onToggleTheme,
  });

  // Router.neglect makes this specific navigation report to the browser as
  // an in-place update (still changes the URL/title bar) instead of pushing
  // a new history entry — without it, every navbar tap (including the logo)
  // piles onto the browser's Back stack, so clicking Home after browsing a
  // few tabs doesn't feel like "home," it just becomes one more stop you can
  // still step back through. Tabs reached from the persistent nav should
  // behave like switching tabs, not drilling into new pages — that's still
  // true for e.g. opening a specific song, which intentionally uses
  // `.push()` on a real stacked route (see main.dart) and keeps its own
  // Back entry.
  void _onMenuSelected(BuildContext context, MenuItem menu) {
    Router.neglect(context, () => context.go(pathForMenuItem(menu)));
  }

  @override
  Widget build(BuildContext context) {
    final selectedMenu = menuItemForLocation(currentLocation);
    // On mobile, opening the on-screen keyboard shrinks the viewport, which
    // shrinks this Scaffold's body — since the footer sits below the page
    // content in that same body, it doesn't shrink itself, it just eats
    // into the space the content had, pushing whatever's being edited
    // (e.g. a long lyrics textarea in Submit Song) further up and
    // sometimes out of view entirely, right when the user needs to see the
    // cursor to delete something. The footer serves no purpose while
    // actively typing, so it's simplest to just not render it for as long
    // as the keyboard is open, handing that space back to the content.
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final isMobile = MediaQuery.of(context).size.width < AppBreakpoints.tablet;
    return CallbackShortcuts(
      // Ctrl+K (Cmd+K on macOS) opens quick search from anywhere in the
      // app — a well-worn convention (Spotlight, VS Code, Notion, ...)
      // rather than something invented for this site; the navbar's search
      // icon does the same thing for anyone who wouldn't think to try it.
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            () => showQuickSearch(context),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            () => showQuickSearch(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(96),
            child: Navbar(
              selectedMenu: selectedMenu,
              onMenuSelected: (menu) => _onMenuSelected(context, menu),
              onToggleTheme: onToggleTheme,
              onSearch: () => showQuickSearch(context),
            ),
          ),
          // Left-side account drawer (Profile/Submit Song/My Songs/Admin/Edit
          // Mode/Logout) — Navbar's account icon opens this via
          // Scaffold.of(context).openDrawer(). Only ever opened when logged
          // in (the icon does a direct Login navigation instead when logged
          // out), but it's harmless to always mount.
          drawer: AccountDrawer(
            onMenuSelected: (menu) => _onMenuSelected(context, menu),
          ),
          body: Column(
            children: [
              Expanded(child: child),
              // Desktop/tablet keeps the full footer, unchanged. Mobile
              // instead gets a bottom tab bar (see bottomNavigationBar
              // below) — the footer's own link content moves into the
              // navbar's hamburger menu on mobile so nothing is lost, just
              // relocated to where a phone user expects app-style nav.
              if (!keyboardOpen && !isMobile)
                SiteFooter(
                  onMenuSelected: (menu) => _onMenuSelected(context, menu),
                ),
            ],
          ),
          // Hidden while the keyboard is open for the same reason the
          // footer always was (home_page.dart's own note above/below): a
          // fixed-height bar at the bottom of a shrunk viewport eats into
          // the space whatever's being typed needs, right when the cursor
          // matters most.
          bottomNavigationBar:
              (isMobile && !keyboardOpen)
                  ? MobileBottomNav(
                    selectedMenu: selectedMenu,
                    onMenuSelected: (menu) => _onMenuSelected(context, menu),
                  )
                  : null,
        ),
      ),
    );
  }
}
