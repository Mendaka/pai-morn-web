import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pai_morn_web/auth/auth_provider.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';

/// The public, voteable half of "add the chords for me" requests (the
/// other half, the requester's contact info, stays admin-only — see
/// firestore.rules' songRequests/{id}/private subcollection). Anyone can
/// browse and see what's been asked for; voting requires an account so one
/// visitor can't inflate a request's rank with repeat anonymous votes.
/// Sorted by vote count, highest first — this is the "what should get
/// chorded next" signal for whoever's working through
/// admin_song_requests_screen.dart's queue.
class SongRequestsVoteScreen extends StatelessWidget {
  const SongRequestsVoteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final language = context.watch<LocaleProvider>().currentLanguage;

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('songRequests')
              .orderBy('voteCount', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppTranslations.getText(
                          'voteSongRequestsTitle',
                          language,
                        ),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/request-song'),
                        child: Text(
                          AppTranslations.getText(
                            'requestSongLabel',
                            language,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (docs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Center(
                        child: Text(
                          AppTranslations.getText(
                            'noSongRequestsYet',
                            language,
                          ),
                          style: TextStyle(
                            color: scheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _RequestVoteCard(
                            requestId: doc.id,
                            songLink: (data['songLink'] as String?) ?? '',
                            lyrics: (data['lyrics'] as String?) ?? '',
                            voteCount: (data['voteCount'] as int?) ?? 0,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RequestVoteCard extends StatelessWidget {
  const _RequestVoteCard({
    required this.requestId,
    required this.songLink,
    required this.lyrics,
    required this.voteCount,
  });

  final String requestId;
  final String songLink;
  final String lyrics;
  final int voteCount;

  Future<void> _openLink(String value) async {
    final uri = Uri.tryParse(value.contains('://') ? value : 'https://$value');
    if (uri == null) return;
    try {
      await launchUrl(uri, webOnlyWindowName: '_blank');
    } catch (_) {
      // Best-effort — nothing more useful to do if the link is malformed.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lyricsPreview =
        lyrics.length > 140 ? '${lyrics.substring(0, 140)}…' : lyrics;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _VoteButton(requestId: requestId, voteCount: voteCount),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => _openLink(songLink),
                    child: Text(
                      songLink,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lyricsPreview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSurface.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({required this.requestId, required this.voteCount});

  final String requestId;
  final int voteCount;

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid;
    final scheme = Theme.of(context).colorScheme;

    if (uid == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.thumbsUp, size: 18),
            onPressed: () => context.go('/login'),
          ),
          Text('$voteCount', style: TextStyle(color: scheme.onSurface)),
        ],
      );
    }

    final voteRef = FirebaseFirestore.instance
        .collection('songRequests')
        .doc(requestId)
        .collection('votes')
        .doc(uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: voteRef.snapshots(),
      builder: (context, snapshot) {
        final hasVoted = snapshot.data?.exists ?? false;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: FaIcon(
                hasVoted
                    ? FontAwesomeIcons.solidThumbsUp
                    : FontAwesomeIcons.thumbsUp,
                size: 18,
                color: hasVoted ? Colors.blueAccent : scheme.onSurface,
              ),
              onPressed: () {
                if (hasVoted) {
                  voteRef.delete();
                } else {
                  voteRef.set({'votedAt': FieldValue.serverTimestamp()});
                }
              },
            ),
            Text(
              '$voteCount',
              style: TextStyle(
                color: hasVoted ? Colors.blueAccent : scheme.onSurface,
                fontWeight: hasVoted ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      },
    );
  }
}
