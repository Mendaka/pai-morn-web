import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pai_morn_web/auth/auth_provider.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/menu_item.dart';
import 'package:pai_morn_web/theme/app_theme.dart';
import 'package:pai_morn_web/utils/badge_tier.dart';

/// Slide-out left drawer replacing the old account PopupMenuButton dropdown
/// — everyday account items (Profile, Submit a Song, My Songs, Logout, plus
/// Admin/Edit Mode when applicable) live here instead of a small text menu.
/// Deliberately NOT a permanently-pinned sidebar like AdminShell's — these
/// are only a few items a logged-in user reaches for occasionally, so
/// reserving screen space for them on every page (Home, SongBook, ...)
/// would cost more than it's worth.
class AccountDrawer extends StatelessWidget {
  const AccountDrawer({super.key, required this.onMenuSelected});

  final ValueChanged<MenuItem> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final language = context.watch<LocaleProvider>().currentLanguage;
    final tier = badgeTier(auth.approvedSongCount);

    void go(MenuItem item) {
      Navigator.of(context).pop();
      onMenuSelected(item);
    }

    return Drawer(
      backgroundColor: scheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: scheme.onSurface.withOpacity(0.08),
                    // Shows the same photo set on Profile once a user has
                    // uploaded one — leaving this generic forever while
                    // Profile shows the real photo would look unfinished.
                    backgroundImage:
                        (auth.photoUrl?.isNotEmpty ?? false)
                            ? CachedNetworkImageProvider(auth.photoUrl!)
                            : null,
                    child:
                        (auth.photoUrl?.isNotEmpty ?? false)
                            ? null
                            : FaIcon(
                              FontAwesomeIcons.solidCircleUser,
                              size: 32,
                              color: scheme.onSurface.withOpacity(0.6),
                            ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.displayName ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurface,
                          ),
                        ),
                        if (tier > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                BadgeIcon(tier: tier, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  badgeTierLabel(tier),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.onSurface.withOpacity(0.1)),
            const SizedBox(height: 8),
            _tile(
              context,
              FontAwesomeIcons.user,
              'Profile',
              () => go(MenuItem.profile),
            ),
            _tile(
              context,
              FontAwesomeIcons.penToSquare,
              AppTranslations.getText('changeProfileNameLabel', language),
              () {
                Navigator.of(context).pop();
                context.go('/profile?edit=1');
              },
            ),
            _tile(
              context,
              FontAwesomeIcons.circlePlus,
              AppTranslations.getText('submitSongTitle', language),
              () => go(MenuItem.submitSong),
            ),
            _tile(
              context,
              FontAwesomeIcons.recordVinyl,
              AppTranslations.getText('mySongsTitle', language),
              () => go(MenuItem.mySongs),
            ),
            _tile(
              context,
              FontAwesomeIcons.heart,
              AppTranslations.getText('favoritesTitle', language),
              () => go(MenuItem.favorites),
            ),
            _tile(
              context,
              FontAwesomeIcons.listCheck,
              AppTranslations.getText('setlistsTitle', language),
              () => go(MenuItem.setlists),
            ),
            _tile(
              context,
              FontAwesomeIcons.listOl,
              AppTranslations.getText('requestSongLabel', language),
              () => go(MenuItem.requestSong),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: scheme.onSurface.withOpacity(0.1)),
            const SizedBox(height: 8),
            _tile(
              context,
              FontAwesomeIcons.shareNodes,
              AppTranslations.getText('shareAppLabel', language),
              () {
                Navigator.of(context).pop();
                _shareApp(context);
              },
            ),
            if (auth.isAdmin) ...[
              const SizedBox(height: 8),
              Divider(height: 1, color: scheme.onSurface.withOpacity(0.1)),
              const SizedBox(height: 8),
              _tile(
                context,
                FontAwesomeIcons.userShield,
                AppTranslations.getText('adminLabel', language),
                () => go(MenuItem.admin),
              ),
              _editModeTile(context, auth, language),
            ],
            const Spacer(),
            Divider(height: 1, color: scheme.onSurface.withOpacity(0.1)),
            const SizedBox(height: 8),
            _tile(
              context,
              FontAwesomeIcons.rightFromBracket,
              AppTranslations.getText('logout', language),
              () {
                Navigator.of(context).pop();
                auth.signOut();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Shares the app's own base URL (not whatever song/page is currently
  // open) via the browser's native share sheet, same fallback shape as
  // song_reader_screen.dart's `_shareSong`: Web Share API first, falling
  // back to copying the link for browsers that don't support it.
  Future<void> _shareApp(BuildContext context) async {
    final url = Uri.base.origin;
    try {
      final result = await Share.shareUri(Uri.parse(url));
      if (result.status != ShareResultStatus.unavailable) return;
    } catch (_) {
      // Web Share unsupported on this browser — fall through to clipboard.
    }
    if (!context.mounted) return;
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
    } catch (_) {
      // Clipboard access can be denied too — nothing more we can do.
    }
  }

  // Each row reads as a distinct tappable chip rather than a bare
  // edge-to-edge ListTile: the icon sits in a soft tinted circle for visual
  // weight, and a faint trailing chevron signals "this navigates somewhere"
  // — still fully monochrome (onSurface at varying opacity), matching this
  // app's flat, no-accent-color design language rather than introducing a
  // one-off color just for this drawer.
  Widget _tile(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return _row(
      context,
      leading: _iconChip(scheme, icon),
      label: label,
      onTap: onTap,
      trailing: FaIcon(
        FontAwesomeIcons.chevronRight,
        size: 12,
        color: scheme.onSurface.withOpacity(0.25),
      ),
    );
  }

  Widget _editModeTile(BuildContext context, AuthProvider auth, String language) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = auth.editModeEnabled;
    // Deliberately doesn't close the drawer on tap (unlike the nav items
    // above) so the checkbox's live state change is visible feedback.
    return _row(
      context,
      leading: _iconChip(
        scheme,
        enabled ? FontAwesomeIcons.solidSquareCheck : FontAwesomeIcons.square,
        filled: enabled,
      ),
      label: AppTranslations.getText('editModeLabel', language),
      onTap: auth.toggleEditMode,
      trailing: null,
    );
  }

  Widget _iconChip(ColorScheme scheme, IconData icon, {bool filled = false}) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? scheme.onSurface : scheme.onSurface.withOpacity(0.06),
        shape: BoxShape.circle,
      ),
      child: FaIcon(
        icon,
        size: 15,
        color: filled ? scheme.surface : scheme.onSurface.withOpacity(0.8),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required Widget leading,
    required String label,
    required VoidCallback onTap,
    required Widget? trailing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
