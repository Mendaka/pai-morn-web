import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/widget/song_picker_dialog.dart';

/// The admin-only queue of "add the chords for me" requests from
/// request_song_screen.dart — oldest first (a real FIFO queue, per the
/// maintainer's own description of how they work through it), each with
/// its song link, the requester's lyrics, and a one-tap way to open their
/// contact link/email. Publishing the finished song still happens outside
/// this screen (the normal Submit/Edit flow) — but "Mark Fulfilled" here
/// links this request to that song (a picker, see song_picker_dialog.dart),
/// which is what lets onSongRequestFulfilled (functions/index.js) notify a
/// signed-in requester in-app. A fulfilled request stays visible with a
/// green badge instead of disappearing, same "resolved but not vanished"
/// treatment as admin_song_issue_reports_screen.dart — Delete remains for
/// actually disqualified/spam requests.
class AdminSongRequestsScreen extends StatelessWidget {
  const AdminSongRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final language = context.watch<LocaleProvider>().currentLanguage;

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('songRequests')
              .orderBy('createdAt', descending: false)
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
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppTranslations.getText('adminSongRequestsLabel', language),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (docs.isEmpty)
                    Text(
                      AppTranslations.getText('noSongRequestsYet', language),
                      style: TextStyle(color: scheme.onSurface.withOpacity(0.7)),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _RequestCard(
                            requestId: doc.id,
                            data: data,
                            index: index,
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

class _RequestCard extends StatefulWidget {
  const _RequestCard({
    required this.requestId,
    required this.data,
    required this.index,
    required this.language,
  });

  final String requestId;
  final Map<String, dynamic> data;
  final int index;
  final String language;

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _lyricsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final songLink = (widget.data['songLink'] as String?) ?? '';
    final lyrics = (widget.data['lyrics'] as String?) ?? '';
    final voteCount = (widget.data['voteCount'] as int?) ?? 0;
    final createdAt = widget.data['createdAt'] as Timestamp?;
    final fulfilledSongId = widget.data['fulfilledSongId'] as String?;
    final fulfilledSongName = widget.data['fulfilledSongName'] as String?;
    final isFulfilled = widget.data['status'] == 'fulfilled';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: scheme.onSurface.withOpacity(0.08),
                  child: Text(
                    '${widget.index + 1}',
                    style: TextStyle(fontSize: 12, color: scheme.onSurface),
                  ),
                ),
                const SizedBox(width: 10),
                if (createdAt != null)
                  Text(
                    _formatDate(createdAt.toDate()),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                const SizedBox(width: 10),
                FaIcon(
                  FontAwesomeIcons.solidThumbsUp,
                  size: 12,
                  color: scheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  '$voteCount',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const Spacer(),
                if (!isFulfilled)
                  IconButton(
                    icon: FaIcon(
                      FontAwesomeIcons.circleCheck,
                      color: Colors.green,
                      size: 18,
                    ),
                    tooltip: 'Mark Fulfilled',
                    onPressed: () => _markFulfilled(context),
                  ),
                IconButton(
                  icon: FaIcon(FontAwesomeIcons.trashCan, color: scheme.error, size: 18),
                  tooltip: 'Delete',
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ),
            if (isFulfilled && fulfilledSongName != null) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap:
                    fulfilledSongId == null
                        ? null
                        : () => context.go('/songbook/song/$fulfilledSongId'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        FontAwesomeIcons.circleCheck,
                        size: 14,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Fulfilled: $fulfilledSongName',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            _linkRow(scheme, FontAwesomeIcons.link, songLink, () => _openLink(songLink)),
            const SizedBox(height: 4),
            FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future:
                  FirebaseFirestore.instance
                      .collection('songRequests')
                      .doc(widget.requestId)
                      .collection('private')
                      .doc('info')
                      .get(),
              builder: (context, snapshot) {
                final contact =
                    (snapshot.data?.data()?['contact'] as String?) ?? '';
                if (contact.isEmpty) return const SizedBox.shrink();
                return _linkRow(
                  scheme,
                  contact.contains('@')
                      ? FontAwesomeIcons.envelope
                      : FontAwesomeIcons.link,
                  contact,
                  () => _openContact(contact),
                );
              },
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => setState(() => _lyricsExpanded = !_lyricsExpanded),
              child: Text(
                lyrics,
                maxLines: _lyricsExpanded ? null : 3,
                overflow: _lyricsExpanded ? null : TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onSurface.withOpacity(0.85)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linkRow(
    ColorScheme scheme,
    IconData icon,
    String value,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.onSurface.withOpacity(0.6)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.blueAccent,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _launch(Uri uri) async {
    try {
      await launchUrl(uri, webOnlyWindowName: '_blank');
    } catch (_) {
      // Best-effort — nothing more useful to do if the link is malformed.
    }
  }

  Future<void> _openLink(String value) async {
    final uri = Uri.tryParse(value.contains('://') ? value : 'https://$value');
    if (uri == null) return;
    await _launch(uri);
  }

  Future<void> _openContact(String value) async {
    if (value.contains('@') && !value.contains('://')) {
      await _launch(Uri(scheme: 'mailto', path: value));
    } else {
      await _openLink(value);
    }
  }

  // Links this request to whichever real song the admin just picked —
  // fulfilledSongName is denormalized onto the request doc (same reasoning
  // as songIssueReports' own songName field) so the badge above and the
  // notification this write triggers (onSongRequestFulfilled,
  // functions/index.js) don't need an extra read just to show a title.
  Future<void> _markFulfilled(BuildContext context) async {
    final picked = await showSongPickerDialog(context);
    if (picked == null) return;
    await FirebaseFirestore.instance
        .collection('songRequests')
        .doc(widget.requestId)
        .update({
          'status': 'fulfilled',
          'fulfilledSongId': picked.id,
          'fulfilledSongName': picked.name,
        });
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final language = widget.language;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            AppTranslations.getText('deleteRequestConfirmTitle', language),
          ),
          content: Text(
            AppTranslations.getText('deleteRequestConfirmMessage', language),
          ),
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
    final requestRef = FirebaseFirestore.instance
        .collection('songRequests')
        .doc(widget.requestId);
    await requestRef.collection('private').doc('info').delete();
    await requestRef.delete();
  }
}
