import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pai_morn_web/auth/auth_provider.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/widget/submit_song_screen.dart';

/// A logged-in user's own submission history — every song they've ever
/// submitted, regardless of status, so they can see what's still pending,
/// what got published, and why anything was rejected (reachable only when
/// logged in; gated at the routing level in home_page.dart like the other
/// account-only screens).
class MySongsScreen extends StatelessWidget {
  const MySongsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final language = context.watch<LocaleProvider>().currentLanguage;
    final auth = context.watch<AuthProvider>();
    final uid = auth.user?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('songs')
              .where('authorId', isEqualTo: uid)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs =
            snapshot.data!.docs.toList()..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = aData['createdAt'] as Timestamp?;
              final bTime = bData['createdAt'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppTranslations.getText('mySongsTitle', language),
                    style: TextStyle(
                      fontSize: 22,

                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (docs.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FaIcon(
                              FontAwesomeIcons.recordVinyl,
                              size: 40,
                              color: scheme.onSurface.withOpacity(0.25),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              AppTranslations.getText(
                                'noSubmissionsYet',
                                language,
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: scheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
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
                          return _SongStatusTile(
                            songId: doc.id,
                            data: data,
                            language: language,
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

class _SongStatusTile extends StatelessWidget {
  const _SongStatusTile({
    required this.songId,
    required this.data,
    required this.language,
  });

  final String songId;
  final Map<String, dynamic> data;
  final String language;

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'pending';
    final statusColor = switch (status) {
      'approved' => Colors.green,
      'rejected' => Colors.redAccent,
      'draft' => Colors.grey,
      _ => Colors.orange,
    };
    final statusKey = switch (status) {
      'approved' => 'statusApproved',
      'rejected' => 'statusRejected',
      'draft' => 'statusDraft',
      _ => 'statusPending',
    };
    final reason = data['rejectionReason'] as String?;
    final showReason =
        status == 'rejected' && reason != null && reason.isNotEmpty;

    final isRejected = status == 'rejected';
    final isDraft = status == 'draft';
    // A draft can be saved with nothing filled in yet (see
    // SubmitSongScreen._saveDraft), so the usual songName/artist text may
    // both be blank — fall back to a placeholder rather than showing an
    // empty-looking tile.
    final songName = (data['songName'] as String?) ?? '';
    final artist = (data['artist'] as String?) ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(songName.isNotEmpty ? songName : 'Untitled draft'),
        // Rejection reason moved from "hidden behind a tap" (the old
        // detail dialog) to always visible right here — a tap on anything
        // but a rejected/draft song opens the full reader (same one
        // SongBook uses), which has no concept of "why was this rejected",
        // so that info needs to live on the tile itself or it's lost.
        subtitle:
            showReason
                ? Text(
                  '$artist\n'
                  '${AppTranslations.getText('rejectionReasonLabel', language)}: $reason',
                  style: const TextStyle(color: Colors.redAccent),
                )
                : Text(artist),
        isThreeLine: showReason,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                AppTranslations.getText(statusKey, language),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            // A rejected song is the author's own to fix and resend (see
            // SubmitSongScreen.isResubmission), and a draft is entirely
            // theirs to keep editing (isDraftContinuation) — everything
            // else (pending, approved) is still read-only for them, so
            // these icons only show up for those two statuses.
            if (isRejected || isDraft)
              IconButton(
                icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 18),
                tooltip: isDraft ? 'Continue editing' : 'Edit & resubmit',
                onPressed: () => _openEditForm(context, songId, data, isDraft),
              ),
            if (isDraft)
              IconButton(
                icon: const FaIcon(FontAwesomeIcons.trashCan, size: 18),
                tooltip: 'Delete draft',
                onPressed: () => _confirmDeleteDraft(context, songId),
              ),
          ],
        ),
        onTap: () {
          if (isDraft || isRejected) {
            _openEditForm(context, songId, data, isDraft);
          } else {
            context.go('/songbook/song/$songId');
          }
        },
      ),
    );
  }

  void _openEditForm(
    BuildContext context,
    String songId,
    Map<String, dynamic> data,
    bool isDraft,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => SubmitSongScreen(
              editingSongId: songId,
              editingSongData: data,
              isResubmission: !isDraft,
              isDraftContinuation: isDraft,
            ),
      ),
    );
  }

  Future<void> _confirmDeleteDraft(BuildContext context, String songId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete this draft?'),
          content: const Text('This can\'t be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await FirebaseFirestore.instance.collection('songs').doc(songId).delete();
  }
}
