import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pai_morn_web/auth/auth_provider.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/theme/app_theme.dart';

/// One community thread — its full body plus every comment underneath,
/// oldest first (a normal conversation reads top-to-bottom). Reached by a
/// real URL (`/community/thread/:id`, see main.dart) the same way a song's
/// reading page is, rather than staying an in-page dialog/expansion — so a
/// thread can be linked to directly and survives a refresh.
class CommunityThreadScreen extends StatelessWidget {
  const CommunityThreadScreen({super.key, required this.threadId});

  final String threadId;

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/community');
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LocaleProvider>().currentLanguage;
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('communityThreads')
              .doc(threadId)
              .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final title = (data?['title'] as String?) ?? '';
        return Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: () => _goBack(context)),
            title: Text(
              title.isEmpty
                  ? AppTranslations.getText('communityLabel', language)
                  : title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body:
              snapshot.hasData && data == null
                  ? Center(
                    child: Text(
                      AppTranslations.getText('noThreadsYetMessage', language),
                    ),
                  )
                  : !snapshot.hasData
                  ? const Center(child: CircularProgressIndicator())
                  : _ThreadBody(threadId: threadId, data: data!),
        );
      },
    );
  }
}

/// Which comment (if any) the composer is currently replying to — captured
/// entirely client-side at the moment "Reply" is tapped (author name + a
/// short snippet of the body) rather than re-fetched later, so showing it
/// back on the posted comment needs no extra read.
class _ReplyTarget {
  const _ReplyTarget({
    required this.commentId,
    required this.authorName,
    required this.snippet,
  });

  final String commentId;
  final String authorName;
  final String snippet;
}

class _ThreadBody extends StatefulWidget {
  const _ThreadBody({required this.threadId, required this.data});

  final String threadId;
  final Map<String, dynamic> data;

  @override
  State<_ThreadBody> createState() => _ThreadBodyState();
}

class _ThreadBodyState extends State<_ThreadBody> {
  _ReplyTarget? _replyTarget;

  void _startReply(String commentId, String authorName, String body) {
    setState(
      () => _replyTarget = _ReplyTarget(
        commentId: commentId,
        authorName: authorName,
        snippet: body.length > 60 ? '${body.substring(0, 60)}…' : body,
      ),
    );
  }

  void _cancelReply() => setState(() => _replyTarget = null);

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final language = context.watch<LocaleProvider>().currentLanguage;
    final body = (widget.data['body'] as String?) ?? '';
    final authorName = (widget.data['authorName'] as String?) ?? '';
    final createdAt = widget.data['createdAt'] as Timestamp?;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    createdAt != null
                        ? '$authorName · ${_formatDate(createdAt.toDate())}'
                        : authorName,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(body, style: TextStyle(fontSize: 15, height: 1.5)),
                  const SizedBox(height: 24),
                  Divider(color: scheme.onSurface.withOpacity(0.1)),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('communityThreads')
                            .doc(widget.threadId)
                            .collection('comments')
                            .orderBy('createdAt', descending: false)
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            AppTranslations.getText(
                              'noCommentsYetMessage',
                              language,
                            ),
                            style: TextStyle(
                              color: scheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final doc in docs)
                            _CommentTile(
                              threadId: widget.threadId,
                              commentId: doc.id,
                              data: doc.data() as Map<String, dynamic>,
                              onReply: _startReply,
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            _CommentComposer(
              threadId: widget.threadId,
              replyTarget: _replyTarget,
              onCancelReply: _cancelReply,
              onSubmitted: _cancelReply,
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatefulWidget {
  const _CommentTile({
    required this.threadId,
    required this.commentId,
    required this.data,
    required this.onReply,
  });

  final String threadId;
  final String commentId;
  final Map<String, dynamic> data;
  final void Function(String commentId, String authorName, String body)
  onReply;

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _isEditing = false;
  late final TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(
      text: (widget.data['body'] as String?) ?? '',
    );
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _startEdit() {
    _editController.text = (widget.data['body'] as String?) ?? '';
    setState(() => _isEditing = true);
  }

  Future<void> _saveEdit() async {
    final newBody = _editController.text.trim();
    if (newBody.isEmpty) return;
    setState(() => _isEditing = false);
    await FirebaseFirestore.instance
        .collection('communityThreads')
        .doc(widget.threadId)
        .collection('comments')
        .doc(widget.commentId)
        .update({'body': newBody, 'editedAt': FieldValue.serverTimestamp()});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final language = context.read<LocaleProvider>().currentLanguage;
    final body = (widget.data['body'] as String?) ?? '';
    final authorName = (widget.data['authorName'] as String?) ?? '';
    final authorId = (widget.data['authorId'] as String?) ?? '';
    final createdAt = widget.data['createdAt'] as Timestamp?;
    final editedAt = widget.data['editedAt'] as Timestamp?;
    final replyToAuthorName = widget.data['replyToAuthorName'] as String?;
    final replyToSnippet = widget.data['replyToSnippet'] as String?;
    final isOwner = auth.isLoggedIn && auth.user!.uid == authorId;
    final canDelete = auth.isAdmin || isOwner;
    final likeCount = (widget.data['likeCount'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  createdAt != null
                      ? '$authorName · ${_formatDate(createdAt.toDate())}'
                      : authorName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface.withOpacity(0.6),
                  ),
                ),
                if (replyToAuthorName != null && replyToAuthorName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.onSurface.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                        border: Border(
                          left: BorderSide(
                            color: scheme.onSurface.withOpacity(0.25),
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        '${AppTranslations.getText('replyingToLabel', language)} $replyToAuthorName'
                        '${(replyToSnippet ?? '').isEmpty ? '' : ': $replyToSnippet'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: scheme.onSurface.withOpacity(0.55),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 2),
                if (_isEditing)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _editController,
                        minLines: 1,
                        maxLines: 4,
                        autofocus: true,
                        style: TextStyle(color: scheme.onSurface),
                        decoration: const InputDecoration(isDense: true),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: _saveEdit,
                            child: Text(
                              AppTranslations.getText('saveButton', language),
                            ),
                          ),
                          TextButton(
                            onPressed:
                                () => setState(() => _isEditing = false),
                            child: Text(
                              AppTranslations.getText(
                                'cancelButton',
                                language,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Text(body, style: TextStyle(color: scheme.onSurface)),
                if (!_isEditing) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _CommentLikeButton(
                        threadId: widget.threadId,
                        commentId: widget.commentId,
                        likeCount: likeCount,
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap:
                            () => widget.onReply(
                              widget.commentId,
                              authorName,
                              body,
                            ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Text(
                            AppTranslations.getText('replyButton', language),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface.withOpacity(0.55),
                            ),
                          ),
                        ),
                      ),
                      if (editedAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          AppTranslations.getText('editedLabel', language),
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: scheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isOwner && !_isEditing)
            IconButton(
              icon: FaIcon(
                FontAwesomeIcons.penToSquare,
                size: 16,
                color: scheme.onSurface.withOpacity(0.5),
              ),
              tooltip: AppTranslations.getText('editButton', language),
              onPressed: _startEdit,
            ),
          if (canDelete && !_isEditing)
            IconButton(
              icon: FaIcon(FontAwesomeIcons.trashCan, size: 18, color: scheme.error),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(context, language),
            ),
        ],
      ),
    );
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
        .doc(widget.threadId)
        .collection('comments')
        .doc(widget.commentId)
        .delete();
  }
}

/// A heart toggle for one comment — membership is just whether
/// `.../comments/{commentId}/likes/{uid}` exists (same shape as
/// `favorite_button.dart`'s song favorites, just owned by the comment
/// instead of the user). [likeCount] comes from the comment doc's own
/// denormalized field (maintained server-side by onCommentLikeAdded/
/// onCommentLikeRemoved), which the caller already has from the same
/// `comments` collection snapshot driving the whole list — no separate
/// count query needed here.
class _CommentLikeButton extends StatefulWidget {
  const _CommentLikeButton({
    required this.threadId,
    required this.commentId,
    required this.likeCount,
  });

  final String threadId;
  final String commentId;
  final int likeCount;

  @override
  State<_CommentLikeButton> createState() => _CommentLikeButtonState();
}

class _CommentLikeButtonState extends State<_CommentLikeButton>
    with SingleTickerProviderStateMixin {
  // Same small scale-bounce-on-like pattern as favorite_button.dart, for
  // one consistent "liking something" feel across the app.
  late final AnimationController _popController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.4,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.4,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 65,
      ),
    ]).animate(_popController);
  }

  @override
  void dispose() {
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = context.watch<AuthProvider>().user?.uid;

    // Signed-out visitor can still see the count, just can't toggle it —
    // there's no per-user "have I liked this" doc to check without a uid.
    if (uid == null) {
      return _heartRow(scheme, isLiked: false, count: widget.likeCount);
    }

    final likeRef = FirebaseFirestore.instance
        .collection('communityThreads')
        .doc(widget.threadId)
        .collection('comments')
        .doc(widget.commentId)
        .collection('likes')
        .doc(uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: likeRef.snapshots(),
      builder: (context, snapshot) {
        final isLiked = snapshot.data?.exists ?? false;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (isLiked) {
              likeRef.delete();
            } else {
              likeRef.set({'createdAt': FieldValue.serverTimestamp()});
              _popController.forward(from: 0);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: _heartRow(scheme, isLiked: isLiked, count: widget.likeCount),
          ),
        );
      },
    );
  }

  Widget _heartRow(
    ColorScheme scheme, {
    required bool isLiked,
    required int count,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _scale,
          builder:
              (context, child) =>
                  Transform.scale(scale: _scale.value, child: child),
          child: FaIcon(
            isLiked ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
            size: 15,
            color:
                isLiked ? Colors.redAccent : scheme.onSurface.withOpacity(0.4),
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              color:
                  isLiked
                      ? Colors.redAccent
                      : scheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ],
    );
  }
}

class _CommentComposer extends StatefulWidget {
  const _CommentComposer({
    required this.threadId,
    required this.replyTarget,
    required this.onCancelReply,
    required this.onSubmitted,
  });

  final String threadId;
  final _ReplyTarget? replyTarget;
  final VoidCallback onCancelReply;
  final VoidCallback onSubmitted;

  @override
  State<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<_CommentComposer> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    final auth = context.read<AuthProvider>();
    final replyTarget = widget.replyTarget;
    setState(() => _isSubmitting = true);
    try {
      await FirebaseFirestore.instance
          .collection('communityThreads')
          .doc(widget.threadId)
          .collection('comments')
          .add({
            'body': body,
            'authorId': auth.user!.uid,
            'authorName': auth.displayName ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            if (replyTarget != null) ...{
              'replyToCommentId': replyTarget.commentId,
              'replyToAuthorName': replyTarget.authorName,
              'replyToSnippet': replyTarget.snippet,
            },
          });
      if (!mounted) return;
      _controller.clear();
      widget.onSubmitted();
    } catch (_) {
      if (!mounted) return;
      final language = context.read<LocaleProvider>().currentLanguage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppTranslations.getText('postFailedMessage', language)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final language = context.watch<LocaleProvider>().currentLanguage;
    final replyTarget = widget.replyTarget;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.onSurface.withOpacity(0.1)),
        ),
      ),
      child:
          auth.isLoggedIn
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (replyTarget != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${AppTranslations.getText('replyingToLabel', language)} ${replyTarget.authorName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: widget.onCancelReply,
                            child: FaIcon(
                              FontAwesomeIcons.xmark,
                              size: 14,
                              color: scheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: AppTranslations.getText(
                              'commentHint',
                              language,
                            ),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        icon:
                            _isSubmitting
                                ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: scheme.onSurface,
                                  ),
                                )
                                : FaIcon(FontAwesomeIcons.paperPlane, color: scheme.onSurface, size: 18),
                        onPressed: _isSubmitting ? null : _submit,
                      ),
                    ],
                  ),
                ],
              )
              : Center(
                child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(
                    AppTranslations.getText('loginToPostMessage', language),
                  ),
                ),
              ),
    );
  }
}
