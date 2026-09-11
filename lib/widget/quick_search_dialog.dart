import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/theme/app_theme.dart';
import 'package:pai_morn_web/widget/app_search_field.dart';

/// Concatenates just the sung-lyric text of a song's `lyrics` array (chord
/// tokens skipped entirely) so search can match against what was actually
/// sung, not chord names — e.g. searching "rain" shouldn't hit a song just
/// because it happens to use an Am chord.
String _lyricsPlainText(List? lyrics) {
  if (lyrics == null) return '';
  final buffer = StringBuffer();
  for (final line in lyrics) {
    final content = line['content'] as List? ?? [];
    for (final item in content) {
      if (item['type'] == 'chord') continue;
      buffer.write((item['text'] ?? '').toString());
    }
    buffer.write('\n');
  }
  return buffer.toString();
}

/// The first authored lyric line containing [query] (case-insensitive),
/// used as the result subtitle when a song only matched via its lyrics —
/// otherwise the match would show up with no visible explanation of why.
String? _firstMatchingLyricLine(List? lyrics, String query) {
  if (lyrics == null) return null;
  for (final line in lyrics) {
    final content = line['content'] as List? ?? [];
    final buffer = StringBuffer();
    for (final item in content) {
      if (item['type'] == 'chord') continue;
      buffer.write((item['text'] ?? '').toString());
    }
    final text = buffer.toString().trim();
    if (text.isNotEmpty && text.toLowerCase().contains(query)) return text;
  }
  return null;
}

/// App-wide quick search — opened via the navbar's search icon or the
/// Ctrl+K / Cmd+K shortcut (see home_page.dart's CallbackShortcuts). Matches
/// against song name, artist, band, and now lyrics content — someone often
/// remembers a line they sang more clearly than the song's actual title.
/// Approved songs only, same as everywhere else public-facing.
void showQuickSearch(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) => const _QuickSearchDialog(),
  );
}

class _QuickSearchDialog extends StatefulWidget {
  const _QuickSearchDialog();

  @override
  State<_QuickSearchDialog> createState() => _QuickSearchDialogState();
}

class _QuickSearchDialogState extends State<_QuickSearchDialog> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openSong(String songId) {
    Navigator.of(context).pop();
    context.go('/songbook/song/$songId');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final language = context.watch<LocaleProvider>().currentLanguage;
    final query = _query.trim().toLowerCase();

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 96, left: 24, right: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: AppSearchField(
                controller: _controller,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                hintText: AppTranslations.getText(
                  'quickSearchHint',
                  language,
                ),
              ),
            ),
            Divider(height: 1, color: scheme.onSurface.withOpacity(0.1)),
            Flexible(
              child:
                  query.isEmpty
                      ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          AppTranslations.getText(
                            'quickSearchPrompt',
                            language,
                          ),
                          style: TextStyle(
                            color: scheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      )
                      : StreamBuilder<QuerySnapshot>(
                        stream:
                            FirebaseFirestore.instance
                                .collection('songs')
                                .where('status', isEqualTo: 'approved')
                                .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          final results =
                              snapshot.data!.docs.where((doc) {
                                final data =
                                    doc.data() as Map<String, dynamic>;
                                final songName =
                                    (data['songName'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                final artist =
                                    (data['artist'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                final band =
                                    (data['band'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                final lyricsText =
                                    _lyricsPlainText(
                                      data['lyrics'] as List?,
                                    ).toLowerCase();
                                return songName.contains(query) ||
                                    artist.contains(query) ||
                                    band.contains(query) ||
                                    lyricsText.contains(query);
                              }).toList()..sort((a, b) {
                                final an =
                                    (a.data()
                                            as Map<String, dynamic>)['songName']
                                        .toString();
                                final bn =
                                    (b.data()
                                            as Map<String, dynamic>)['songName']
                                        .toString();
                                return an.compareTo(bn);
                              });
                          if (results.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                AppTranslations.getText(
                                  'quickSearchNoResults',
                                  language,
                                ),
                                style: TextStyle(
                                  color: scheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: results.length.clamp(0, 30),
                            itemBuilder: (context, index) {
                              final doc = results[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final songName =
                                  (data['songName'] ?? '').toString();
                              final artist = (data['artist'] ?? '').toString();
                              final band = (data['band'] ?? '').toString();
                              final nameOrArtistMatch =
                                  songName.toLowerCase().contains(query) ||
                                  artist.toLowerCase().contains(query) ||
                                  band.toLowerCase().contains(query);
                              final matchedLyricLine =
                                  nameOrArtistMatch
                                      ? null
                                      : _firstMatchingLyricLine(
                                        data['lyrics'] as List?,
                                        query,
                                      );
                              final subtitle =
                                  matchedLyricLine ??
                                  [
                                    artist,
                                    band,
                                  ].where((s) => s.isNotEmpty).join(' · ');
                              return ListTile(
                                leading: FaIcon(
                                  FontAwesomeIcons.music,
                                  color: scheme.onSurface.withOpacity(0.6),
                                ),
                                title: Text(songName),
                                subtitle:
                                    subtitle.isEmpty ? null : Text(subtitle),
                                onTap: () => _openSong(doc.id),
                              );
                            },
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
