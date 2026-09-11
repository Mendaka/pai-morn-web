import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/theme/app_theme.dart';
import 'package:pai_morn_web/utils/artist_palette.dart';
import 'package:pai_morn_web/utils/badge_tier.dart';

/// Editorial, text-first About page — replaces the old fixed-width Row
/// pairing this text with a duplicate of Home's decorative rotated-book
/// illustration (removed here; Home already owns that motif, and repeating
/// it added nothing). No slideshow/illustration, matching the minimalist
/// SaaS-style direction chosen for the rest of the site. All text now goes
/// through AppTranslations like every other page — it used to be hardcoded
/// Shan regardless of the language switcher, which read as a real bug once
/// pointed out ("about page is Shan even though the app is set to
/// English").
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // Same soft radial-gradient "aurora" blobs as Home's hero backdrop, same
  // palette — reused rather than reinvented so this page reads as more of
  // the same product instead of a plainer, bolted-on text page next to it.
  Widget _backdrop() {
    Widget blob(Color color, double size) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withOpacity(0.3), color.withOpacity(0)],
          ),
        ),
      );
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -80,
              child: blob(artistPalette[3], 320),
            ),
            Positioned(
              top: 260,
              left: -100,
              child: blob(artistPalette[0], 280),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final language = context.watch<LocaleProvider>().currentLanguage;
    return Scaffold(
      body: Stack(
        children: [
          _backdrop(),
          SingleChildScrollView(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop =
                    constraints.maxWidth >= AppBreakpoints.desktop;
                final isTablet = constraints.maxWidth >= AppBreakpoints.tablet;
                final titleSize = isDesktop ? 40.0 : (isTablet ? 32.0 : 26.0);
                final bodySize = isDesktop ? 20.0 : (isTablet ? 18.0 : 16.0);
                final topGap = isDesktop ? 120.0 : (isTablet ? 90.0 : 64.0);
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        topGap,
                        AppSpacing.lg,
                        AppSpacing.xxxl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppTranslations.getText('aboutEyebrow', language),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                              color: scheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 5,
                                height: titleSize * 0.9,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      artistPalette[0],
                                      artistPalette[3],
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  AppTranslations.getText(
                                    'aboutTitle',
                                    language,
                                  ),
                                  style: TextStyle(
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'AJKunheing20',
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(
                                AppRadius.lg,
                              ),
                              border: Border.all(
                                color: scheme.onSurface.withOpacity(0.08),
                              ),
                              boxShadow: AppShadows.soft(scheme.onSurface),
                            ),
                            child: Text(
                              AppTranslations.getText(
                                'aboutMission',
                                language,
                              ),
                              style: TextStyle(
                                fontSize: bodySize,
                                height: 1.9,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurface.withOpacity(0.75),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxxl),
                          _buildContributors(scheme, bodySize, language),
                          const SizedBox(height: AppSpacing.xxxl),
                          _buildCta(context, scheme, language),
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

  // A closing invitation, same vivid two-color gradient treatment as
  // Home's own CTA block — About otherwise ended on the Team section with
  // nowhere left to go; this gives a reader who just learned who's behind
  // the site somewhere obvious to act next.
  Widget _buildCta(BuildContext context, ColorScheme scheme, String language) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [artistPalette[0], artistPalette[3]],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: artistPalette[0].withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            AppTranslations.getText('aboutCtaHeading', language),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppTranslations.getText('aboutCtaDescription', language),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: artistPalette[0],
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => context.go('/submit-song'),
            child: Text(AppTranslations.getText('submitSongTitle', language)),
          ),
        ],
      ),
    );
  }

  Widget _buildContributors(
    ColorScheme scheme,
    double bodySize,
    String language,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final developers = <MapEntry<String, int>>[];
        final contributors = <MapEntry<String, int>>[];
        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['displayName'] as String?)?.trim() ?? '';
          if (name.isEmpty) continue;
          final count = (data['approvedSongCount'] as int?) ?? 0;
          if (data['isAdmin'] == true) {
            developers.add(MapEntry(name, count));
          } else if (count > 0) {
            contributors.add(MapEntry(name, count));
          }
        }
        // Developer(s) always lead, like a team lead byline — contributors
        // beneath them ranked by how much they've actually added, per the
        // maintainer's own ordering request.
        developers.sort((a, b) => a.key.compareTo(b.key));
        contributors.sort((a, b) => b.value.compareTo(a.value));

        if (developers.isEmpty && contributors.isEmpty) {
          return const SizedBox.shrink();
        }

        final headingStyle = TextStyle(
          fontSize: bodySize * 0.85,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: scheme.onSurface,
        );
        final labelStyle = TextStyle(
          fontSize: bodySize * 0.65,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: scheme.onSurface.withOpacity(0.5),
        );

        final developerLabel = AppTranslations.getText(
          'aboutDeveloperLabel',
          language,
        );
        final developerCards = [
          for (final entry in developers)
            _contributorCard(
              scheme,
              entry.key,
              subtitle: developerLabel,
              tier: badgeTier(entry.value),
            ),
        ];
        final contributorCards = [
          for (final entry in contributors)
            _contributorCard(
              scheme,
              entry.key,
              subtitle: _songsCountLabel(entry.value, language),
              tier: badgeTier(entry.value),
            ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            // A one-leader-then-team hierarchy (like an org chart) reads
            // naturally on a wide screen with the developer row centered
            // above the contributor row — but on a phone-width screen,
            // wrapping cards two-per-row looked cramped, so narrow layouts
            // just stack every card one-per-row instead, per the
            // maintainer's own request.
            final isNarrow = constraints.maxWidth < AppBreakpoints.tablet;
            Widget group(List<Widget> cards, String label) {
              if (cards.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(label, style: labelStyle),
                  const SizedBox(height: AppSpacing.sm),
                  isNarrow
                      ? Column(
                        children: [
                          for (final card in cards)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: card,
                            ),
                        ],
                      )
                      : Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 16,
                        children: cards,
                      ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Divider(color: scheme.onSurface.withOpacity(0.1)),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Text(
                    AppTranslations.getText('aboutTeamHeading', language),
                    style: headingStyle,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                group(developerCards, developerLabel),
                if (developerCards.isNotEmpty && contributorCards.isNotEmpty)
                  const SizedBox(height: AppSpacing.lg),
                group(
                  contributorCards,
                  AppTranslations.getText('aboutContributorLabel', language),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Mirrors book_screen.dart/community_screen.dart's own helper of the same
  // name — the singular key only has an 'en' entry, so this check is
  // harmless for shn/mm (falls through to the plural key either way).
  String _songsCountLabel(int count, String language) {
    final key =
        count == 1 && language == 'en'
            ? 'songCountLabelSingular'
            : 'songsCountLabel';
    return AppTranslations.getText(key, language).replaceFirst(
      '{count}',
      '$count',
    );
  }

  // One "honor card" per person, styled after the maintainer's own
  // reference image — a colored gradient card with a circular avatar
  // overlapping its top edge, name, and role underneath. The color is
  // hashed from their name (same scheme as artist covers/chord roots
  // elsewhere), so it's a distinct, consistent identity per person rather
  // than a fixed color for the whole section.
  Widget _contributorCard(
    ColorScheme scheme,
    String name, {
    String? subtitle,
    // 0 = no badge yet, matching badge_tier.dart's own scale — same tiers
    // shown on Profile and the Community leaderboard, reused here so a
    // contributor with 10+ approved songs gets their star right under their
    // avatar on this page too.
    int tier = 0,
  }) {
    const avatarRadius = 28.0;
    const cardWidth = 168.0;
    final baseColor = colorForArtist(name);
    final deepColor = Color.lerp(baseColor, Colors.black, 0.35)!;

    return SizedBox(
      width: cardWidth,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            margin: const EdgeInsets.only(top: avatarRadius),
            width: cardWidth,
            // Fixed height (not just width) is what actually makes every
            // card the same size regardless of how long a name is — a
            // maintainer request after the first pass let card height
            // follow its own text and ended up visibly uneven card-to-card.
            // 128 rather than the original 108 — the extra 20px is the
            // reserved badge-star row below, always present (even at tier 0,
            // where BadgeIcon renders nothing) so a starred contributor's
            // card isn't taller than an unstarred one.
            height: 128,
            // Top padding clears the avatar's overlap (avatarRadius) plus a
            // real gap on top of that — centering the text block in the
            // full card height put it right up against the avatar's own
            // bottom edge with no breathing room at all.
            padding: const EdgeInsets.fromLTRB(12, avatarRadius + 14, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [baseColor, deepColor],
              ),
              boxShadow: AppShadows.subtle(scheme.onSurface),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 16,
                  child: Center(child: BadgeIcon(tier: tier, size: 14)),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: avatarRadius * 2,
            height: avatarRadius * 2,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surface,
            ),
            child: CircleAvatar(
              backgroundColor: baseColor,
              child: const FaIcon(FontAwesomeIcons.solidUser, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
