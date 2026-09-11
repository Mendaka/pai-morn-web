import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/theme/app_theme.dart';
import 'package:pai_morn_web/utils/artist_palette.dart';

/// A plain-language tour of every feature on the site — one card per
/// feature, icon + title + a single explanatory line, same visual recipe
/// as home_screen.dart's "Features" section (just with a lot more cards,
/// since this page's whole job is to be the complete list that section
/// only samples 4 of). Reused rather than shared code since the two
/// contexts differ just enough (this page needs a title/description per
/// card that's fully localized, Home's is still English-only) that
/// factoring out a shared widget wasn't worth it for a handful of
/// duplicated lines.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  // Same soft radial-gradient "aurora" blobs as About/Home's backdrop —
  // reused so this reads as more of the same product, not a plainer,
  // bolted-on text page.
  Widget _backdrop() {
    Widget blob(Color color, double size) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withOpacity(0.25), color.withOpacity(0)],
          ),
        ),
      );
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(top: -60, right: -80, child: blob(artistPalette[3], 320)),
            Positioned(top: 340, left: -100, child: blob(artistPalette[0], 280)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final language = context.watch<LocaleProvider>().currentLanguage;

    final sections = [
      (
        FontAwesomeIcons.book,
        AppTranslations.getText('songbook', language),
        AppTranslations.getText('guideSongbookDesc', language),
      ),
      (
        FontAwesomeIcons.magnifyingGlass,
        AppTranslations.getText('guideSearchTitle', language),
        AppTranslations.getText('guideSearchDesc', language),
      ),
      (
        FontAwesomeIcons.music,
        AppTranslations.getText('tunerLabel', language),
        AppTranslations.getText('guideTunerDesc', language),
      ),
      (
        FontAwesomeIcons.guitar,
        AppTranslations.getText('chordsLabel', language),
        AppTranslations.getText('guideChordsDesc', language),
      ),
      (
        FontAwesomeIcons.listCheck,
        AppTranslations.getText('setlistsTitle', language),
        AppTranslations.getText('guideSetlistsDesc', language),
      ),
      (
        FontAwesomeIcons.heart,
        AppTranslations.getText('favoritesTitle', language),
        AppTranslations.getText('guideFavoritesDesc', language),
      ),
      (
        FontAwesomeIcons.peopleGroup,
        AppTranslations.getText('communityLabel', language),
        AppTranslations.getText('guideCommunityDesc', language),
      ),
      (
        FontAwesomeIcons.circlePlus,
        AppTranslations.getText('submitSongTitle', language),
        AppTranslations.getText('guideSubmitDesc', language),
      ),
      (
        FontAwesomeIcons.envelope,
        AppTranslations.getText('requestSongLabel', language),
        AppTranslations.getText('guideRequestDesc', language),
      ),
      (
        FontAwesomeIcons.triangleExclamation,
        AppTranslations.getText('reportIssueTooltip', language),
        AppTranslations.getText('guideReportDesc', language),
      ),
      (
        FontAwesomeIcons.mobileScreenButton,
        AppTranslations.getText('installAppTitle', language),
        AppTranslations.getText('guideInstallDesc', language),
      ),
      (
        FontAwesomeIcons.globe,
        AppTranslations.getText('guideLanguageTitle', language),
        AppTranslations.getText('guideLanguageDesc', language),
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          _backdrop(),
          SingleChildScrollView(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop =
                    constraints.maxWidth >= AppBreakpoints.desktop;
                final cardWidth = isDesktop ? 300.0 : 320.0;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: isDesktop ? 90 : 56,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            AppTranslations.getText('guideTitle', language),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isDesktop ? 36 : 26,
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            AppTranslations.getText('guideIntro', language),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isDesktop ? 17 : 15,
                              color: scheme.onSurface.withOpacity(0.65),
                            ),
                          ),
                          const SizedBox(height: 36),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 20,
                            runSpacing: 20,
                            children: [
                              for (var i = 0; i < sections.length; i++)
                                SizedBox(
                                  width: cardWidth,
                                  child: _guideCard(
                                    scheme,
                                    sections[i].$1,
                                    sections[i].$2,
                                    sections[i].$3,
                                    artistPalette[i % artistPalette.length],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _guideCard(
    ColorScheme scheme,
    IconData icon,
    String title,
    String description,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.onSurface.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.onSurface.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: FaIcon(icon, size: 18, color: accent),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: scheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
