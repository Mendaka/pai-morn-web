import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pai_morn_web/auth/auth_provider.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/theme/app_theme.dart';
import 'package:pai_morn_web/utils/artist_palette.dart';
import 'package:pai_morn_web/utils/badge_tier.dart';

/// A small discussion board — post a thread, others reply underneath (see
/// community_thread_screen.dart for the comment view) — plus a Top
/// Contributors tab ranking users by their existing approvedSongCount/badge
/// tier (see utils/badge_tier.dart), reusing data the site already tracks
/// rather than adding anything new to compute. Anyone can browse without an
/// account; posting either a thread or a comment requires being signed in
/// (and not blocked — see firestore.rules), same gate as submitting a song.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  bool _showLeaderboard = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final language = context.watch<LocaleProvider>().currentLanguage;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [artistPalette[0], artistPalette[3]],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppTranslations.getText('communityLabel', language),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (!_showLeaderboard)
                    ElevatedButton.icon(
                      onPressed: () => _startNewThread(context, language),
                      icon: const FaIcon(FontAwesomeIcons.plus, size: 16),
                      label: Text(
                        AppTranslations.getText('newThreadButton', language),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTabToggle(scheme, language),
              const SizedBox(height: 16),
              Expanded(
                child:
                    _showLeaderboard
                        ? _buildLeaderboard(scheme, language)
                        : _buildThreadList(scheme, language),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabToggle(ColorScheme scheme, String language) {
    Widget pill(String label, bool selected, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? scheme.onSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  selected
                      ? scheme.onSurface
                      : scheme.onSurface.withOpacity(0.3),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? scheme.surface : scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pill(
          AppTranslations.getText('discussionsTabLabel', language),
          !_showLeaderboard,
          () => setState(() => _showLeaderboard = false),
        ),
        const SizedBox(width: 8),
        pill(
          AppTranslations.getText('topContributorsTabLabel', language),
          _showLeaderboard,
          () => setState(() => _showLeaderboard = true),
        ),
      ],
    );
  }

  Widget _buildThreadList(ColorScheme scheme, String language) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('communityThreads')
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return _emptyState(
            scheme,
            FontAwesomeIcons.comments,
            AppTranslations.getText('noThreadsYetMessage', language),
          );
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _ThreadTile(threadId: doc.id, data: data);
          },
        );
      },
    );
  }

  Widget _buildLeaderboard(ColorScheme scheme, String language) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .where('approvedSongCount', isGreaterThan: 0)
              .orderBy('approvedSongCount', descending: true)
              .limit(50)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return _emptyState(
            scheme,
            FontAwesomeIcons.trophy,
            AppTranslations.getText('noContributorsYetMessage', language),
          );
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final displayName = (data['displayName'] as String?) ?? '';
            final count = (data['approvedSongCount'] as int?) ?? 0;
            final tier = badgeTier(count);
            final rank = index + 1;
            // Gold/silver/bronze rank medal for the top 3 instead of a
            // plain gray number — the leaderboard's whole point is
            // celebrating the top contributors, so the #1/#2/#3 rows should
            // actually look like a podium at a glance.
            final medalColor = switch (rank) {
              1 => const Color(0xFFD4AF37),
              2 => const Color(0xFFA8A9AD),
              3 => const Color(0xFFCD7F32),
              _ => null,
            };
            final authorColor = colorForArtist(
              displayName.isEmpty ? '?' : displayName,
            );
            final monogram =
                displayName.trim().isEmpty
                    ? '?'
                    : displayName.trim().substring(0, 1).toUpperCase();
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child:
                          medalColor != null
                              ? Container(
                                width: 26,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: medalColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: medalColor.withOpacity(0.4),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '$rank',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                              : Text(
                                '$rank',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: scheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                    ),
                    const SizedBox(width: 10),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: authorColor,
                      child: Text(
                        monogram,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    if (tier > 0) ...[
                      BadgeIcon(tier: tier, size: 16),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      _songsCountLabel(count, language),
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Shared by both tabs' empty states — a bare line of text read as
  // unfinished next to the rest of the app's icon-paired empty states
  // (favorites, my songs).
  Widget _emptyState(ColorScheme scheme, IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: scheme.onSurface.withOpacity(0.25)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  // Only English marks singular/plural — Shan and Burmese use the same word
  // regardless of count (mirrors book_screen.dart's _songsCountLabel).
  String _songsCountLabel(int count, String language) {
    final key =
        count == 1 && language == 'en'
            ? 'songCountLabelSingular'
            : 'songsCountLabel';
    return AppTranslations.getText(
      key,
      language,
    ).replaceFirst('{count}', '$count');
  }

  void _startNewThread(BuildContext context, String language) {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      context.go('/login');
      return;
    }
    showDialog(
      context: context,
      builder: (dialogContext) => _NewThreadDialog(language: language),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.threadId, required this.data});

  final String threadId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final title = (data['title'] as String?) ?? '';
    final body = (data['body'] as String?) ?? '';
    final authorName = (data['authorName'] as String?) ?? '';
    final authorId = (data['authorId'] as String?) ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final canDelete =
        auth.isAdmin || (auth.isLoggedIn && auth.user!.uid == authorId);

    // Same colorForArtist hash used everywhere an identity needs a
    // consistent color (Home/SongBook/About/Profile) — here it ties a
    // thread's accent stripe and author avatar to that same author's color
    // wherever else they show up on the site, rather than every thread
    // looking like a generic gray card regardless of who posted it.
    final authorColor = colorForArtist(authorName.isEmpty ? '?' : authorName);
    final monogram =
        authorName.trim().isEmpty
            ? '?'
            : authorName.trim().substring(0, 1).toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/community/thread/$threadId'),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: authorColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: authorColor,
                            child: Text(
                              monogram,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                Text(
                                  createdAt != null
                                      ? '$authorName · ${_formatDate(createdAt.toDate())}'
                                      : authorName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurface.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (canDelete)
                            IconButton(
                              icon: FaIcon(FontAwesomeIcons.trashCan, color: scheme.error, size: 18),
                              tooltip: 'Delete',
                              onPressed:
                                  () => _confirmDelete(
                                    context,
                                    context.read<LocaleProvider>().currentLanguage,
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.onSurface.withOpacity(0.75)),
                      ),
                      const SizedBox(height: 10),
                      // Nothing on this list previously hinted which threads
                      // actually have any conversation going — every tile
                      // looked the same regardless of whether it had 0
                      // replies or 50. A cheap count() aggregate per visible
                      // tile, styled as a small pill instead of bare text.
                      FutureBuilder<AggregateQuerySnapshot>(
                        future:
                            FirebaseFirestore.instance
                                .collection('communityThreads')
                                .doc(threadId)
                                .collection('comments')
                                .count()
                                .get(),
                        builder: (context, snapshot) {
                          final count = snapshot.data?.count ?? 0;
                          if (count == 0) return const SizedBox.shrink();
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.onSurface.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  FontAwesomeIcons.comment,
                                  size: 12,
                                  color: scheme.onSurface.withOpacity(0.5),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmDelete(BuildContext context, String language) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            AppTranslations.getText('deletePostConfirmTitle', language),
          ),
          content: Text(
            AppTranslations.getText('deletePostConfirmMessage', language),
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
        .collection('communityThreads')
        .doc(threadId)
        .delete();
  }
}

class _NewThreadDialog extends StatefulWidget {
  const _NewThreadDialog({required this.language});

  final String language;

  @override
  State<_NewThreadDialog> createState() => _NewThreadDialogState();
}

class _NewThreadDialogState extends State<_NewThreadDialog> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(
        () =>
            _errorMessage = AppTranslations.getText(
              'pleaseFillAllFields',
              widget.language,
            ),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await FirebaseFirestore.instance.collection('communityThreads').add({
        'title': title,
        'body': body,
        'authorId': auth.user!.uid,
        'authorName': auth.displayName ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(AppTranslations.getText('newThreadButton', widget.language)),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: AppTranslations.getText(
                  'newThreadTitleHint',
                  widget.language,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _bodyController,
              minLines: 5,
              maxLines: 12,
              decoration: InputDecoration(
                labelText: AppTranslations.getText(
                  'newThreadBodyHint',
                  widget.language,
                ),
                alignLabelWithHint: true,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_errorMessage!, style: TextStyle(color: scheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(AppTranslations.getText('cancelButton', widget.language)),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child:
              _isSubmitting
                  ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.surface,
                    ),
                  )
                  : Text(
                    AppTranslations.getText('postButton', widget.language),
                  ),
        ),
      ],
    );
  }
}
