import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/theme/app_theme.dart';
import 'package:pai_morn_web/utils/artist_palette.dart';

/// A plain-text legal page — same aurora backdrop and card treatment as
/// About/Guide, rendering a heading + last-updated line + one long body
/// string, parameterized by l10n key so Privacy Policy and Terms of
/// Service (identical layout, different content) share one widget instead
/// of duplicating it. The body string uses a tiny convention rather than a
/// real markdown renderer (not worth pulling in a dependency for two
/// pages): blocks are separated by a blank line, and a block starting with
/// "## " is a section heading (the rest of that block is its body);
/// everything else renders as plain paragraph text, so a "- " bullet line
/// just reads as a normal line within its paragraph.
class LegalPageScreen extends StatelessWidget {
  const LegalPageScreen({
    super.key,
    required this.titleKey,
    required this.lastUpdatedKey,
    required this.bodyKey,
  });

  final String titleKey;
  final String lastUpdatedKey;
  final String bodyKey;

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

  List<(String? heading, String body)> _parseSections(String raw) {
    final blocks = raw.split('\n\n');
    return [
      for (final block in blocks)
        if (block.startsWith('## '))
          _splitHeadingBlock(block)
        else
          (null, block),
    ];
  }

  (String heading, String body) _splitHeadingBlock(String block) {
    final newlineIndex = block.indexOf('\n');
    if (newlineIndex == -1) return (block.substring(3), '');
    return (block.substring(3, newlineIndex), block.substring(newlineIndex + 1));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final language = context.watch<LocaleProvider>().currentLanguage;
    final sections = _parseSections(AppTranslations.getText(bodyKey, language));

    return Scaffold(
      body: Stack(
        children: [
          _backdrop(),
          SingleChildScrollView(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop =
                    constraints.maxWidth >= AppBreakpoints.desktop;
                final titleSize = isDesktop ? 36.0 : 26.0;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: isDesktop ? 90 : 56,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppTranslations.getText(titleKey, language),
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            AppTranslations.getText(lastUpdatedKey, language),
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(
                                color: scheme.onSurface.withOpacity(0.08),
                              ),
                              boxShadow: AppShadows.soft(scheme.onSurface),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var i = 0; i < sections.length; i++) ...[
                                  if (i > 0) const SizedBox(height: AppSpacing.lg),
                                  if (sections[i].$1 != null) ...[
                                    Text(
                                      sections[i].$1!,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  Text(
                                    sections[i].$2,
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.7,
                                      color: scheme.onSurface.withOpacity(0.75),
                                    ),
                                  ),
                                ],
                              ],
                            ),
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
}
