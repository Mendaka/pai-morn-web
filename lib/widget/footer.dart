import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/menu_item.dart';
import 'package:pai_morn_web/theme/app_theme.dart';
import 'package:pai_morn_web/utils/artist_palette.dart';
import 'package:provider/provider.dart';

/// A persistent strip at the bottom of every shell page — holds About and
/// Contact (moved out of the main Navbar since they're low-traffic
/// informational pages that don't need equal billing with Home/SongBook/
/// Tuner: "no one looks at them anyway") plus the two real contact channels
/// from contact_screen.dart (email, Facebook), so a visitor doesn't have to
/// click through to Contact just to find them.
///
/// Laid out as three groups (brand, links, contact) side by side on wide
/// screens and stacked centered on narrow ones — previously a single, tight
/// one-line strip that read as an afterthought bolted onto the bottom of
/// the page rather than a real part of the site.
class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key, required this.onMenuSelected});

  static const String _email = 'hseng2018@gmail.com';
  static const String _facebookUrl =
      'https://www.facebook.com/taidevIT/?locale=th_TH';

  final ValueChanged<MenuItem> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final language = context.watch<LocaleProvider>().currentLanguage;
    final year = DateTime.now().year;
    final isNarrow = MediaQuery.of(context).size.width < AppBreakpoints.desktop;

    if (isNarrow) {
      return _buildCompactMobile(context, scheme, language, year);
    }

    final brandColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Paimorn',
          style: GoogleFonts.lobsterTwo(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        _metaLine(context, scheme, language, year, alignment: WrapAlignment.start),
      ],
    );

    final contactColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _contactRow(
          context,
          FontAwesomeIcons.envelope,
          _email,
          Uri(scheme: 'mailto', path: _email),
        ),
        const SizedBox(height: 10),
        _contactRow(
          context,
          FontAwesomeIcons.facebook,
          'facebook.com/taidevIT',
          Uri.parse(_facebookUrl),
        ),
      ],
    );

    return _wrapper(
      scheme,
      horizontalPad: 40,
      verticalPad: 32,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: brandColumn),
          Expanded(child: contactColumn),
        ],
      ),
    );
  }

  // Mobile gets its own much more compact layout rather than just stacking
  // the desktop's column groups — a real user reported the first stacked
  // version ate up nearly half a real phone's viewport height. "Request a
  // Song" moved into AccountDrawer entirely (it's a low-traffic action, not
  // core footer content), and About/Contact fold directly onto the
  // brand/copyright line instead of getting their own row — down to just 2
  // tight rows: one combined text line, and icon-only contact buttons.
  Widget _buildCompactMobile(
    BuildContext context,
    ColorScheme scheme,
    String language,
    int year,
  ) {
    return _wrapper(
      scheme,
      horizontalPad: 20,
      verticalPad: 14,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Paimorn',
            style: GoogleFonts.lobsterTwo(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          _metaLine(context, scheme, language, year, alignment: WrapAlignment.center),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _iconOnlyContact(
                context,
                FontAwesomeIcons.envelope,
                _email,
                Uri(scheme: 'mailto', path: _email),
              ),
              _iconOnlyContact(
                context,
                FontAwesomeIcons.facebook,
                'facebook.com/taidevIT',
                Uri.parse(_facebookUrl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // "© year · About · Contact" — About/Contact are real tappable links, not
  // plain text, but sit inline with the copyright rather than in their own
  // row (per the user's explicit ask to fold them onto the same line).
  Widget _metaLine(
    BuildContext context,
    ColorScheme scheme,
    String language,
    int year, {
    required WrapAlignment alignment,
  }) {
    final bulletStyle = TextStyle(
      fontSize: 12.5,
      color: scheme.onSurface.withOpacity(0.35),
    );
    return Wrap(
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '© $year',
          style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withOpacity(0.45)),
        ),
        Text('  ·  ', style: bulletStyle),
        _footerLink(
          context,
          AppTranslations.getText('about', language),
          () => onMenuSelected(MenuItem.about),
        ),
        Text('·', style: bulletStyle),
        _footerLink(
          context,
          AppTranslations.getText('guideLabel', language),
          () => onMenuSelected(MenuItem.guide),
        ),
        Text('·', style: bulletStyle),
        _footerLink(
          context,
          AppTranslations.getText('contact', language),
          () => onMenuSelected(MenuItem.contact),
        ),
        Text('·', style: bulletStyle),
        _footerLink(
          context,
          AppTranslations.getText('privacyLabel', language),
          () => onMenuSelected(MenuItem.privacy),
        ),
        Text('·', style: bulletStyle),
        _footerLink(
          context,
          AppTranslations.getText('termsLabel', language),
          () => onMenuSelected(MenuItem.terms),
        ),
      ],
    );
  }

  Widget _wrapper(
    ColorScheme scheme, {
    required double horizontalPad,
    required double verticalPad,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(scheme.onSurface.withOpacity(0.035), scheme.surface),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A thin colored line instead of a flat gray divider — the same
          // two palette colors the Home hero/CTA already use, so the
          // footer reads as the bottom edge of one consistently-branded
          // site rather than a bolted-on afterthought.
          Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  artistPalette[0].withOpacity(0.6),
                  artistPalette[3].withOpacity(0.6),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPad,
              vertical: verticalPad,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconOnlyContact(
    BuildContext context,
    IconData icon,
    String value,
    Uri uri,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(icon, size: 18),
      color: scheme.onSurface.withOpacity(0.55),
      tooltip: value,
      visualDensity: VisualDensity.compact,
      onPressed: () => _openContactLink(context, value, uri),
    );
  }

  Widget _footerLink(BuildContext context, String label, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 13.5, color: scheme.onSurface.withOpacity(0.65)),
        ),
      ),
    );
  }

  // Icon + full label (not an icon-only button behind a hover tooltip, like
  // before) so the actual email/Facebook handle is readable at a glance
  // instead of needing to hover or tap first to find out what it links to.
  Widget _contactRow(
    BuildContext context,
    IconData icon,
    String value,
    Uri uri,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => _openContactLink(context, value, uri),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: scheme.onSurface.withOpacity(0.5)),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(fontSize: 13, color: scheme.onSurface.withOpacity(0.65)),
            ),
          ],
        ),
      ),
    );
  }

  // Same fallback contact_screen.dart's _ContactChannel uses: if no mail
  // client / Facebook app is registered to handle the link (e.g. a bare
  // browser profile, or the popup gets blocked), copy the address instead
  // of leaving the tap looking like it did nothing.
  Future<void> _openContactLink(
    BuildContext context,
    String value,
    Uri uri,
  ) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, webOnlyWindowName: '_blank');
    } catch (_) {
      opened = false;
    }
    if (opened || !context.mounted) return;
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Copied "$value" to clipboard')));
    } catch (_) {
      // Clipboard access can be denied too — nothing more to do.
    }
  }
}
