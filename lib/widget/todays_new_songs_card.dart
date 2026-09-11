import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/utils/app_day.dart';
import 'package:pai_morn_web/utils/artist_palette.dart';

/// A daily highlight card for Home — "N new songs today", the newest few
/// by name/artist, and a Share button. Queries `approvedAt` (not
/// `createdAt`) so a song submitted days ago but only approved just now
/// correctly counts as today's — the reason `approvedAt` was added to the
/// admin-approve/edit-and-release write paths this round. Renders nothing
/// at all when the count is zero, rather than an empty-looking "0 new
/// songs" card — there's nothing worth a whole card section to say yet.
class TodaysNewSongsCard extends StatelessWidget {
  const TodaysNewSongsCard({super.key});

  Future<void> _share(BuildContext context) async {
    // A dedicated URL (not the bare homepage) so the shared link's own
    // preview card shows *today's* count/highlights — see
    // dailyUpdatePreview/dailyUpdateCard in functions/index.js. The date
    // query param doesn't change what dailyUpdatePreview renders (it
    // always queries live) — it exists purely so link-preview crawlers
    // (Facebook, LINE, ...) see a URL they've never scraped before each
    // day, instead of replaying whatever snapshot they cached the first
    // time this exact URL was ever shared (a real bug: without this, the
    // shared card silently never updated after its first share). Same
    // Web-Share-with-clipboard-fallback pattern as song_reader_screen.
    // dart's _shareSong, so this behaves identically to every other share
    // button in the app instead of introducing a second convention.
    final url =
        'https://song-and-chord.web.app/daily-update?d=${appDayLabel()}';
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
      // Clipboard access can be denied too — nothing more to do.
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LocaleProvider>().currentLanguage;

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('songs')
              .where('status', isEqualTo: 'approved')
              .where(
                'approvedAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfAppDayUtc()),
              )
              .orderBy('approvedAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) return const SizedBox.shrink();

        final highlighted = docs.take(3).toList();
        final moreCount = docs.length - highlighted.length;

        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(28),
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
                  AppTranslations.getText('todayNewSongsLabel', language),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                for (final doc in highlighted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      onTap: () => context.go('/songbook/song/${doc.id}'),
                      child: Text(
                        _songLine(doc.data() as Map<String, dynamic>),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white38,
                        ),
                      ),
                    ),
                  ),
                if (moreCount > 0)
                  Text(
                    AppTranslations.getText(
                      'todayMoreSongsLabel',
                      language,
                    ).replaceFirst('{count}', '$moreCount'),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: artistPalette[0],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _share(context),
                  icon: const FaIcon(FontAwesomeIcons.facebook, size: 16),
                  label: Text(
                    AppTranslations.getText('shareButtonLabel', language),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _songLine(Map<String, dynamic> data) {
    final songName = (data['songName'] as String?) ?? '';
    final artist = (data['artist'] as String?) ?? '';
    return artist.isEmpty ? songName : '$songName — $artist';
  }
}
