import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pai_morn_web/theme/app_theme.dart';
import 'package:pai_morn_web/widget/app_search_field.dart';

/// A small "search and pick one approved song" dialog — used by
/// admin_song_requests_screen.dart to link a song request to the actual
/// song that fulfilled it. Deliberately a new, small widget rather than
/// reusing quick_search_dialog.dart: that dialog is a private class with no
/// constructor params, hardcoded to `context.go()` straight to the song
/// reader on tap — there's no injection point for "give me back the
/// selection instead of navigating," and retrofitting one would touch a
/// widget used app-wide just for this one admin-only callback shape.
/// Matches on name/artist/band only (no lyrics search) — an admin linking a
/// request already knows the song's title, unlike Ctrl+K's "I half-remember
/// a lyric" use case.
Future<({String id, String name})?> showSongPickerDialog(
  BuildContext context,
) {
  return showDialog<({String id, String name})>(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) => const _SongPickerDialog(),
  );
}

class _SongPickerDialog extends StatefulWidget {
  const _SongPickerDialog();

  @override
  State<_SongPickerDialog> createState() => _SongPickerDialogState();
}

class _SongPickerDialogState extends State<_SongPickerDialog> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                hintText: 'Search song name or artist...',
              ),
            ),
            Divider(height: 1, color: scheme.onSurface.withOpacity(0.1)),
            Flexible(
              child:
                  query.isEmpty
                      ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Type a song name to search.',
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
                                return songName.contains(query) ||
                                    artist.contains(query) ||
                                    band.contains(query);
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
                                'No songs match that search.',
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
                              final subtitle = [
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
                                onTap:
                                    () => Navigator.of(context).pop((
                                      id: doc.id,
                                      name: songName,
                                    )),
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
