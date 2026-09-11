import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pai_morn_web/auth/auth_provider.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/theme/app_theme.dart';

/// Navbar bell icon + red-dot unread indicator, backed by a live stream on
/// `users/{uid}/notifications` (see firestore.rules and functions/index.js's
/// onSongStatusChange/onCommentCreated triggers, the only things ever
/// allowed to create a doc there). Hidden entirely when signed out — there's
/// nothing to show and no uid to query with.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.textColor});

  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isLoggedIn) return const SizedBox.shrink();
    final uid = auth.user!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('notifications')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final hasUnread = docs.any(
          (doc) => (doc.data() as Map<String, dynamic>)['read'] != true,
        );
        return IconButton(
          tooltip: AppTranslations.getText(
            'notificationsTitle',
            context.watch<LocaleProvider>().currentLanguage,
          ),
          onPressed: () => _openNotifications(context, uid, docs),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              FaIcon(FontAwesomeIcons.bell, color: textColor, size: 18),
              if (hasUnread)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _openNotifications(
    BuildContext context,
    String uid,
    List<QueryDocumentSnapshot> docs,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _NotificationsDialog(uid: uid),
    );
  }
}

class _NotificationsDialog extends StatelessWidget {
  const _NotificationsDialog({required this.uid});

  final String uid;

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications');

  Future<void> _markAllRead(List<QueryDocumentSnapshot> docs) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['read'] != true) {
        batch.update(doc.reference, {'read': true});
      }
    }
    await batch.commit();
  }

  void _openNotification(BuildContext context, Map<String, dynamic> data) {
    Navigator.of(context).pop();
    final type = data['type'] as String?;
    if (type == 'songApproved' ||
        type == 'songRejected' ||
        type == 'songRequestFulfilled') {
      final songId = data['songId'] as String?;
      if (songId != null) context.push('/songbook/song/$songId');
    } else if (type == 'threadReply') {
      final threadId = data['threadId'] as String?;
      if (threadId != null) context.push('/community/thread/$threadId');
    }
  }

  String _messageFor(String language, Map<String, dynamic> data) {
    final type = data['type'] as String?;
    switch (type) {
      case 'songApproved':
        return AppTranslations.getText(
          'notificationSongApprovedMessage',
          language,
        ).replaceFirst('{songName}', (data['songName'] ?? '').toString());
      case 'songRejected':
        return AppTranslations.getText(
          'notificationSongRejectedMessage',
          language,
        ).replaceFirst('{songName}', (data['songName'] ?? '').toString());
      case 'songRequestFulfilled':
        return AppTranslations.getText(
          'notificationSongRequestFulfilledMessage',
          language,
        ).replaceFirst('{songName}', (data['songName'] ?? '').toString());
      case 'threadReply':
        return AppTranslations.getText(
          'notificationThreadReplyMessage',
          language,
        )
            .replaceFirst(
              '{commenterName}',
              (data['commenterName'] ?? '').toString(),
            )
            .replaceFirst(
              '{threadTitle}',
              (data['threadTitle'] ?? '').toString(),
            );
      default:
        return '';
    }
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'songApproved':
        return FontAwesomeIcons.circleCheck;
      case 'songRejected':
        return FontAwesomeIcons.circleXmark;
      case 'songRequestFulfilled':
        return FontAwesomeIcons.gift;
      case 'threadReply':
        return FontAwesomeIcons.comments;
      default:
        return FontAwesomeIcons.bell;
    }
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final language = context.watch<LocaleProvider>().currentLanguage;

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 96, left: 24, right: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 480),
        child: StreamBuilder<QuerySnapshot>(
          stream:
              _collection
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppTranslations.getText(
                            'notificationsTitle',
                            language,
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (docs.isNotEmpty)
                        TextButton(
                          onPressed: () => _markAllRead(docs),
                          child: Text(
                            AppTranslations.getText(
                              'markAllReadButton',
                              language,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Divider(height: 1, color: scheme.onSurface.withOpacity(0.1)),
                Flexible(
                  child:
                      !snapshot.hasData
                          ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          )
                          : docs.isEmpty
                          ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              AppTranslations.getText(
                                'noNotificationsYetMessage',
                                language,
                              ),
                              style: TextStyle(
                                color: scheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          )
                          : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              final data =
                                  doc.data() as Map<String, dynamic>;
                              final isRead = data['read'] == true;
                              final createdAt =
                                  data['createdAt'] as Timestamp?;
                              return ListTile(
                                leading: Icon(
                                  _iconFor(data['type'] as String?),
                                  color:
                                      isRead
                                          ? scheme.onSurface.withOpacity(0.4)
                                          : scheme.primary,
                                ),
                                title: Text(
                                  _messageFor(language, data),
                                  style: TextStyle(
                                    fontWeight:
                                        isRead
                                            ? FontWeight.normal
                                            : FontWeight.w600,
                                  ),
                                ),
                                subtitle:
                                    createdAt != null
                                        ? Text(
                                          _relativeTime(createdAt.toDate()),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: scheme.onSurface
                                                .withOpacity(0.5),
                                          ),
                                        )
                                        : null,
                                trailing:
                                    isRead
                                        ? null
                                        : Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                onTap: () {
                                  if (!isRead) {
                                    doc.reference.update({'read': true});
                                  }
                                  _openNotification(context, data);
                                },
                              );
                            },
                          ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
