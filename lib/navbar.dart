import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/auth/auth_provider.dart';
import 'package:pai_morn_web/menu_item.dart';
import 'package:pai_morn_web/theme/app_theme.dart';
import 'package:pai_morn_web/widget/notification_bell.dart';
import 'package:provider/provider.dart';

class Navbar extends StatelessWidget {
  final MenuItem selectedMenu;
  final ValueChanged<MenuItem> onMenuSelected;
  final VoidCallback onToggleTheme;
  final VoidCallback onSearch;

  const Navbar({
    super.key,
    required this.selectedMenu,
    required this.onMenuSelected,
    required this.onToggleTheme,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < AppBreakpoints.tablet;
    final scheme = Theme.of(context).colorScheme;
    final textColor = scheme.onPrimary;
    final localeProvider = Provider.of<LocaleProvider>(context);
    final currentLanguage = localeProvider.currentLanguage;
    final isLoggedIn = Provider.of<AuthProvider>(context).isLoggedIn;
    // A detached floating "capsule" bar instead of the old edge-to-edge strip
    // with a hairline bottom border — margin on all sides plus a soft shadow
    // and a slightly tinted fill (not fully transparent, so it reads as a
    // distinct panel even though nothing scrolls behind it to blur) is what
    // gives it a lifted, premium feel while leaving the page content below
    // completely untouched.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? AppSpacing.sm : AppSpacing.lg,
        10,
        isMobile ? AppSpacing.sm : AppSpacing.lg,
        10,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? AppSpacing.sm : AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Color.alphaBlend(scheme.onSurface.withOpacity(0.045), scheme.surface),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: textColor.withOpacity(0.08)),
          boxShadow: AppShadows.soft(scheme.onSurface),
        ),
        // Tightens every IconButton's default 48x48 tap target (including
        // NotificationBell's, a descendant here) on mobile only — six icons
        // (search/theme/language/notifications/account/menu) at full default
        // size plus the logo no longer fit on a narrow phone once the
        // notification bell was added, silently clipping the rightmost one
        // (the menu toggle) off-screen in release mode (a user reported the
        // menu as simply "disappeared" — this app's known release-mode-
        // overflow-is-invisible gotcha, not a real removal).
        child: IconButtonTheme(
          data: IconButtonThemeData(
            style: IconButton.styleFrom(
              padding: EdgeInsets.all(isMobile ? 4 : 8),
              minimumSize: Size(isMobile ? 34 : 48, isMobile ? 34 : 48),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          child: Row(
          children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onMenuSelected(MenuItem.home),
              child: Text(
                'Paimorn',
                style: GoogleFonts.lobsterTwo(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: AppSpacing.xl),
            _buildMenuButton(
              context,
              MenuItem.home,
              AppTranslations.getText('home', currentLanguage),
              textColor,
            ),
            _buildMenuButton(
              context,
              MenuItem.book,
              AppTranslations.getText('songbook', currentLanguage),
              textColor,
            ),
            _buildMenuButton(
              context,
              MenuItem.tuner,
              AppTranslations.getText('tunerLabel', currentLanguage),
              textColor,
            ),
            _buildMenuButton(
              context,
              MenuItem.chords,
              AppTranslations.getText('chordsLabel', currentLanguage),
              textColor,
            ),
            _buildMenuButton(
              context,
              MenuItem.community,
              AppTranslations.getText('communityLabel', currentLanguage),
              textColor,
            ),
          ],
          const Spacer(),
          IconButton(
            icon: FaIcon(FontAwesomeIcons.magnifyingGlass, color: textColor, size: 18),
            tooltip: '${AppTranslations.getText('searchTooltip', currentLanguage)} (Ctrl+K)',
            onPressed: onSearch,
          ),
          IconButton(
            icon: FaIcon(
              // Reads the live resolved theme via Theme.of(context) rather
              // than threading a `themeMode` value down through props —
              // `MyHomePage` is go_router's ShellRoute shell, which (unlike
              // a normal ancestor widget) only gets reconstructed on
              // navigation, not on every setState, so a `themeMode` prop
              // passed down that way goes stale the moment the theme is
              // toggled without also navigating (exactly what this button
              // does). Theme.of(context) sidesteps that: it's delivered via
              // the InheritedWidget mechanism, which updates live for every
              // descendant regardless of whether an ancestor's own
              // constructor parameters got refreshed. This used to be a
              // real bug here (confirmed via a temporary debug marker that
              // a `themeMode` prop really did stay stuck on `ThemeMode.light`
              // after toggling to dark) — not something the icon swap
              // introduced, just something it surfaced.
              Theme.of(context).brightness == Brightness.dark
                  ? FontAwesomeIcons.moon
                  : FontAwesomeIcons.sun,
              color: textColor,
              size: 18,
            ),
            onPressed: onToggleTheme,
            tooltip: 'Toggle Theme',
          ),
          PopupMenuButton<String>(
            icon: FaIcon(FontAwesomeIcons.globe, color: textColor, size: 18),
            onSelected: (String languageCode) {
              localeProvider.changeLanguage(languageCode);
            },
            itemBuilder:
                (BuildContext context) => [
                  const PopupMenuItem(value: 'en', child: Text('English')),
                  const PopupMenuItem(value: 'th', child: Text('ภาษาไทย')),
                  const PopupMenuItem(value: 'shn', child: Text('ၽႃႇသႃႇတႆး')),
                  const PopupMenuItem(value: 'mm', child: Text('မြန်မာဘာသာ')),
                ],
          ),
          NotificationBell(textColor: textColor),
          _buildAuthButton(context, textColor, currentLanguage),
          if (isMobile)
            // Home/SongBook/Tuner/Chords/Community moved out of here and
            // into MobileBottomNav (home_page.dart) — a phone-style bottom
            // tab bar instead of a dropdown for the 5 primary destinations.
            // This menu now holds what used to be the footer's own links
            // instead, since mobile no longer renders a footer at all (see
            // home_page.dart) — nothing from the footer is lost, just
            // relocated to where it's actually reachable on a phone.
            PopupMenuButton<MenuItem>(
              icon: FaIcon(FontAwesomeIcons.bars, color: textColor, size: 18),
              onSelected: onMenuSelected,
              itemBuilder:
                  (context) => [
                    // Tuner's bottom-nav tab is swapped for the "Submit a
                    // Song" action for signed-in members (see
                    // mobile_bottom_nav.dart) — surfaced here instead so it
                    // stays one tap away rather than becoming unreachable
                    // on mobile. Signed-out visitors already have it in the
                    // bottom bar, so it isn't duplicated here for them.
                    if (isLoggedIn)
                      PopupMenuItem(
                        value: MenuItem.tuner,
                        child: Text(
                          AppTranslations.getText('tunerLabel', currentLanguage),
                        ),
                      ),
                    PopupMenuItem(
                      value: MenuItem.about,
                      child: Text(
                        AppTranslations.getText('about', currentLanguage),
                      ),
                    ),
                    PopupMenuItem(
                      value: MenuItem.guide,
                      child: Text(
                        AppTranslations.getText('guideLabel', currentLanguage),
                      ),
                    ),
                    PopupMenuItem(
                      value: MenuItem.contact,
                      child: Text(
                        AppTranslations.getText('contact', currentLanguage),
                      ),
                    ),
                    PopupMenuItem(
                      value: MenuItem.privacy,
                      child: Text(
                        AppTranslations.getText(
                          'privacyLabel',
                          currentLanguage,
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: MenuItem.terms,
                      child: Text(
                        AppTranslations.getText('termsLabel', currentLanguage),
                      ),
                    ),
                  ],
            ),
        ],
        ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context,
    MenuItem menu,
    String label,
    Color textColor,
  ) {
    final isSelected = selectedMenu == menu;
    // Monochrome selected/unselected hierarchy: full-opacity + semibold text
    // plus a small animated underline dot for the active item, muted text
    // and no underline for the rest — no shadows/accent color, just weight
    // and opacity, matching the flat look established across the site.
    return TextButton(
      onPressed: () => onMenuSelected(menu),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: isSelected ? textColor : textColor.withOpacity(0.55),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2,
            width: isSelected ? 18 : 0,
            decoration: BoxDecoration(
              color: textColor,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthButton(
    BuildContext context,
    Color textColor,
    String currentLanguage,
  ) {
    final auth = Provider.of<AuthProvider>(context);

    if (!auth.isLoggedIn) {
      return IconButton(
        icon: FaIcon(FontAwesomeIcons.rightToBracket, color: textColor, size: 18),
        tooltip: AppTranslations.getText('login', currentLanguage),
        onPressed: () => onMenuSelected(MenuItem.login),
      );
    }

    // The account items (Profile, Submit a Song, My Songs, Admin, ...) now
    // live in AccountDrawer, opened from home_page.dart's Scaffold — this
    // button just requests it, same as any other AppBar-triggers-Scaffold-
    // drawer pattern.
    return IconButton(
      icon: FaIcon(FontAwesomeIcons.solidCircleUser, color: textColor, size: 20),
      tooltip: auth.displayName ?? '',
      onPressed: () => Scaffold.of(context).openDrawer(),
    );
  }
}
