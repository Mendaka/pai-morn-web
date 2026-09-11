import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pai_morn_web/widget/lyric_line_view.dart';
import 'package:pai_morn_web/widget/submit_song_screen.dart';

/// Admin-only moderation queue — lists every `pending` song submission,
/// lets the admin preview the full lyrics, edit it (e.g. fix a small typo)
/// before releasing it, approve/reject, or block a repeatedly bad-faith
/// submitter. Reachability is gated by `AuthProvider.isAdmin` at the
/// routing level (home_page.dart), not here — this widget assumes it's
/// only ever shown to an admin.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('songs')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No pending songs',
              style: TextStyle(color: scheme.onSurface),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(data['songName'] ?? ''),
                subtitle: Text(
                  '${data['artist'] ?? ''} · submitted by ${data['authorName'] ?? 'unknown'}',
                ),
                trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 16),
                onTap: () => _showReviewDialog(context, doc, data),
              ),
            );
          },
        );
      },
    );
  }

  void _showReviewDialog(
    BuildContext context,
    QueryDocumentSnapshot doc,
    Map<String, dynamic> data,
  ) {
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) =>
              _ReviewDialog(outerContext: context, doc: doc, data: data),
    );
  }
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({
    required this.outerContext,
    required this.doc,
    required this.data,
  });

  final BuildContext outerContext;
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _reasonController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = widget.data;
    final lyrics = (data['lyrics'] as List?) ?? [];
    final authorId = data['authorId'] as String?;
    final authorName = data['authorName'] ?? 'unknown';

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data['songName'] ?? '',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${data['artist'] ?? ''} · ${data['category'] ?? '-'} / ${data['gender'] ?? '-'}',
                style: TextStyle(color: scheme.onSurface.withOpacity(0.7)),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Submitted by $authorName',
                      style: TextStyle(
                        color: scheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                  if (authorId != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.error,
                      ),
                      onPressed: _busy ? null : () => _blockUser(authorId),
                      child: const Text('Block this user'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        lyrics
                            .map(
                              (line) => buildLyricLine(
                                context,
                                line['content'] as List,
                                transposeSteps: 0,
                                fontScale: 1.0,
                                textColor: scheme.onSurface,
                              ),
                            )
                            .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText:
                      'Reason (optional, shown to submitter if rejected)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              // Wrap, not Row — on a narrow (mobile) dialog width, four
              // buttons in a plain Row overflowed off the right edge,
              // pushing Approve out where it couldn't be tapped at all. Wrap
              // drops extra buttons to a second line instead.
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : _editSong,
                    child: const Text('Edit'),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : _reject,
                    child: const Text('Reject'),
                  ),
                  ElevatedButton(
                    onPressed: _busy ? null : _approve,
                    child: const Text('Approve'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editSong() {
    Navigator.of(context).pop();
    Navigator.of(widget.outerContext).push(
      MaterialPageRoute(
        builder:
            (_) => SubmitSongScreen(
              editingSongId: widget.doc.id,
              editingSongData: widget.data,
            ),
      ),
    );
  }

  Future<void> _reject() async {
    setState(() => _busy = true);
    final reason = _reasonController.text.trim();
    await widget.doc.reference.update({
      'status': 'rejected',
      if (reason.isNotEmpty) 'rejectionReason': reason,
    });
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _approve() async {
    setState(() => _busy = true);
    final batch = FirebaseFirestore.instance.batch();
    batch.update(widget.doc.reference, {
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
    });
    final authorId = widget.data['authorId'] as String?;
    if (authorId != null) {
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(authorId),
        {'approvedSongCount': FieldValue.increment(1)},
      );
    }
    await batch.commit();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _blockUser(String authorId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirmContext) {
        final scheme = Theme.of(confirmContext).colorScheme;
        return AlertDialog(
          title: const Text('Block this user?'),
          content: const Text(
            "They won't be able to submit new songs or artists anymore. "
            'They can still read/browse the site normally, and this can be '
            'undone later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(confirmContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.of(confirmContext).pop(true),
              child: const Text('Block'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    await FirebaseFirestore.instance.collection('users').doc(authorId).update({
      'blocked': true,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('User blocked.')));
  }
}
