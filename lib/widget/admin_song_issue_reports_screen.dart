import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';

/// The admin-only queue of "this song's chords/lyrics look wrong" reports
/// from song_reader_screen.dart's report-issue button — oldest first, same
/// FIFO convention as admin_song_requests_screen.dart. Marking a report
/// resolved just flips a field (kept for a visual record of what's already
/// been handled) rather than deleting it outright; delete is still there
/// for a report that turns out to be spam/invalid.
class AdminSongIssueReportsScreen extends StatelessWidget {
  const AdminSongIssueReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final language = context.watch<LocaleProvider>().currentLanguage;

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('songIssueReports')
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
                    AppTranslations.getText('adminIssueReportsLabel', language),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (docs.isEmpty)
                    Text(
                      AppTranslations.getText('noIssueReportsYet', language),
                      style: TextStyle(color: scheme.onSurface.withOpacity(0.7)),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _ReportCard(
                            reportId: doc.id,
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

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.reportId,
    required this.data,
    required this.language,
  });

  final String reportId;
  final Map<String, dynamic> data;
  final String language;

  static const _issueTypeKeys = {
    'wrongChords': 'issueTypeWrongChords',
    'wrongLyrics': 'issueTypeWrongLyrics',
    'other': 'issueTypeOther',
  };

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final songId = (data['songId'] as String?) ?? '';
    final songName = (data['songName'] as String?) ?? '';
    final issueType = (data['issueType'] as String?) ?? 'other';
    final description = (data['description'] as String?) ?? '';
    final resolved = data['resolved'] as bool? ?? false;
    final createdAt = data['createdAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap:
                        songId.isEmpty
                            ? null
                            : () => context.go('/songbook/song/$songId'),
                    child: Text(
                      songName.isEmpty ? '(untitled)' : songName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                if (createdAt != null)
                  Text(
                    _formatDate(createdAt.toDate()),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withOpacity(0.5),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange),
              ),
              child: Text(
                AppTranslations.getText(
                  _issueTypeKeys[issueType] ?? 'issueTypeOther',
                  language,
                ),
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(color: scheme.onSurface.withOpacity(0.85)),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (resolved)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Text(
                      AppTranslations.getText('resolvedLabel', language),
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: () => _markResolved(),
                    icon: const FaIcon(FontAwesomeIcons.check, size: 14),
                    label: Text(
                      AppTranslations.getText('markResolvedLabel', language),
                    ),
                  ),
                const Spacer(),
                IconButton(
                  icon: FaIcon(
                    FontAwesomeIcons.trashCan,
                    color: scheme.error,
                    size: 18,
                  ),
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markResolved() async {
    await FirebaseFirestore.instance
        .collection('songIssueReports')
        .doc(reportId)
        .update({'resolved': true});
  }

  Future<void> _confirmDelete(BuildContext context) async {
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
              child: Text(AppTranslations.getText('cancelButton', language)),
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
    await FirebaseFirestore.instance
        .collection('songIssueReports')
        .doc(reportId)
        .delete();
  }
}
