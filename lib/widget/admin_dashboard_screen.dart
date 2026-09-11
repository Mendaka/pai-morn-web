import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:pai_morn_web/auth/auth_provider.dart';
import 'package:pai_morn_web/theme/app_theme.dart';
import 'package:pai_morn_web/utils/artist_palette.dart';
import 'package:pai_morn_web/utils/badge_tier.dart';
import 'package:pai_morn_web/widget/app_search_field.dart';

/// Admin-only overview: site-wide stat cards plus a searchable user table
/// with per-user song counts (approved/pending/rejected) and block/admin
/// management actions. Reachability is gated by `AuthProvider.isAdmin` at
/// the routing level, same as AdminScreen.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _StatCardData {
  const _StatCardData(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 17),
                child: Text(
                  'Site overview and user management',
                  style: TextStyle(color: scheme.onSurface.withOpacity(0.55)),
                ),
              ),
              const SizedBox(height: 24),
              _buildStatsRow(scheme),
              const SizedBox(height: 36),
              Row(
                children: [
                  Icon(
                    FontAwesomeIcons.users,
                    size: 20,
                    color: scheme.onSurface.withOpacity(0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Users',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppSearchField(
                hintText: 'Search users by name...',
                onChanged:
                    (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                maxWidth: 360,
              ),
              const SizedBox(height: 16),
              _buildUsersTable(scheme),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Stat cards ------------------------------------------------------

  Widget _buildStatsRow(ColorScheme scheme) {
    return FutureBuilder<List<AggregateQuerySnapshot>>(
      future: Future.wait([
        FirebaseFirestore.instance.collection('users').count().get(),
        FirebaseFirestore.instance
            .collection('songs')
            .where('status', isEqualTo: 'approved')
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('songs')
            .where('status', isEqualTo: 'pending')
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('songs')
            .where('status', isEqualTo: 'rejected')
            .count()
            .get(),
        FirebaseFirestore.instance.collection('artists').count().get(),
        FirebaseFirestore.instance
            .collection('users')
            .where('blocked', isEqualTo: true)
            .count()
            .get(),
      ]),
      builder: (context, snapshot) {
        final counts = snapshot.data;
        int c(int i) => counts != null ? (counts[i].count ?? 0) : 0;
        final cards = [
          _StatCardData('Users', '${c(0)}', FontAwesomeIcons.users, artistPalette[0]),
          _StatCardData(
            'Approved Songs',
            '${c(1)}',
            FontAwesomeIcons.circleCheck,
            Colors.green,
          ),
          _StatCardData('Pending', '${c(2)}', FontAwesomeIcons.hourglassStart, Colors.orange),
          _StatCardData(
            'Rejected',
            '${c(3)}',
            FontAwesomeIcons.circleXmark,
            Colors.redAccent,
          ),
          _StatCardData(
            'Artists',
            '${c(4)}',
            FontAwesomeIcons.recordVinyl,
            artistPalette[3],
          ),
          _StatCardData('Blocked', '${c(5)}', FontAwesomeIcons.ban, Colors.red.shade900),
        ];
        // A fixed card width (the old design) left an awkward half-empty
        // row on common phone widths — two 150px cards plus spacing (316px)
        // doesn't quite fit a 360-390dp viewport once this screen's own
        // padding is subtracted, so `Wrap` dropped to one per row with a
        // big gap on the right (a real user reported exactly this). Sizing
        // each card as an even fraction of the actually available width
        // instead guarantees a full, gapless row at every breakpoint.
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth >= 700
                    ? 6
                    : constraints.maxWidth >= 420
                    ? 3
                    : 2;
            const spacing = 16.0;
            final cardWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final card in cards)
                  _statCard(scheme, card, width: cardWidth),
              ],
            );
          },
        );
      },
    );
  }

  Widget _statCard(ColorScheme scheme, _StatCardData data, {required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.subtle(scheme.onSurface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, color: data.color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            data.value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ---- User table --------------------------------------------------

  Widget _buildUsersTable(ColorScheme scheme) {
    final myUid = context.watch<AuthProvider>().user?.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('songs').snapshots(),
          builder: (context, songSnap) {
            if (!songSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            // Approved count is already denormalized on the user doc
            // (incremented on approve elsewhere in the app) — only pending/
            // rejected need to be tallied here, grouped by authorId.
            final pendingCount = <String, int>{};
            final rejectedCount = <String, int>{};
            for (final doc in songSnap.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final authorId = data['authorId'] as String?;
              if (authorId == null) continue;
              final status = data['status'] as String?;
              if (status == 'pending') {
                pendingCount[authorId] = (pendingCount[authorId] ?? 0) + 1;
              } else if (status == 'rejected') {
                rejectedCount[authorId] = (rejectedCount[authorId] ?? 0) + 1;
              }
            }

            var userDocs = userSnap.data!.docs;
            if (_searchQuery.isNotEmpty) {
              userDocs =
                  userDocs.where((doc) {
                    final name =
                        ((doc.data() as Map<String, dynamic>)['displayName'] ??
                                '')
                            .toString()
                            .toLowerCase();
                    return name.contains(_searchQuery);
                  }).toList();
            }

            if (userDocs.isEmpty) {
              return Text(
                'No users found.',
                style: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadows.subtle(scheme.onSurface),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    scheme.onSurface.withOpacity(0.035),
                  ),
                  dividerThickness: 0.5,
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Badge')),
                    DataColumn(label: Text('Approved')),
                    DataColumn(label: Text('Pending')),
                    DataColumn(label: Text('Rejected')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows:
                      userDocs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final uid = doc.id;
                        final isSelf = uid == myUid;
                        final name = (data['displayName'] ?? '').toString();
                        final displayName = name.isEmpty ? '(no name)' : name;
                        final approved =
                            (data['approvedSongCount'] as int?) ?? 0;
                        final pending = pendingCount[uid] ?? 0;
                        final rejected = rejectedCount[uid] ?? 0;
                        final isBlocked = data['blocked'] == true;
                        final isAdmin = data['isAdmin'] == true;
                        final tier = badgeTier(approved);
                        final avatarColor = colorForArtist(displayName);
                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: avatarColor,
                                    child: Text(
                                      displayName[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    displayName + (isSelf ? ' (you)' : ''),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              tier > 0
                                  ? BadgeIcon(tier: tier)
                                  : const Text('—'),
                            ),
                            DataCell(
                              Text(
                                '$approved',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '$pending',
                                style: TextStyle(
                                  color: pending > 0 ? Colors.orange : null,
                                  fontWeight:
                                      pending > 0 ? FontWeight.bold : null,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '$rejected',
                                style: TextStyle(
                                  color: rejected > 0 ? Colors.redAccent : null,
                                  fontWeight:
                                      rejected > 0 ? FontWeight.bold : null,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isAdmin)
                                    _statusChip(
                                      'Admin',
                                      artistPalette[3],
                                      FontAwesomeIcons.shield,
                                    ),
                                  if (isBlocked)
                                    _statusChip(
                                      'Blocked',
                                      scheme.error,
                                      FontAwesomeIcons.ban,
                                    ),
                                ],
                              ),
                            ),
                            DataCell(
                              // A self-lockout guard: an admin can't block or
                              // revoke their own admin rights from here —
                              // both would strand them (blocking yourself is
                              // pointless self-harm, and if you're the only
                              // admin, revoking yourself means nobody left
                              // who can grant admin back without going to
                              // the Firebase console).
                              isSelf
                                  ? const SizedBox.shrink()
                                  : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              isBlocked
                                                  ? Colors.green
                                                  : Colors.redAccent,
                                        ),
                                        onPressed:
                                            () =>
                                                _toggleBlocked(uid, !isBlocked),
                                        child: Text(
                                          isBlocked ? 'Unblock' : 'Block',
                                        ),
                                      ),
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              isAdmin
                                                  ? scheme.onSurface.withOpacity(
                                                    0.6,
                                                  )
                                                  : artistPalette[3],
                                        ),
                                        onPressed:
                                            () => _toggleAdmin(uid, !isAdmin),
                                        child: Text(
                                          isAdmin
                                              ? 'Revoke admin'
                                              : 'Make admin',
                                        ),
                                      ),
                                    ],
                                  ),
                            ),
                          ],
                        );
                      }).toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _statusChip(String label, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  Future<void> _toggleBlocked(String uid, bool newValue) async {
    final confirmed = await _confirm(
      newValue ? 'Block this user?' : 'Unblock this user?',
      newValue
          ? "They won't be able to submit new songs or artists anymore. "
              'They can still read/browse the site normally, and this can '
              'be undone later.'
          : 'They will be able to submit songs and artists again.',
    );
    if (!confirmed) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'blocked': newValue,
    });
  }

  Future<void> _toggleAdmin(String uid, bool newValue) async {
    final confirmed = await _confirm(
      newValue ? 'Grant admin rights?' : 'Revoke admin rights?',
      newValue
          ? 'They will be able to approve/reject songs, edit any song, and '
              'block/unblock users.'
          : 'They will lose access to the admin dashboard and moderation '
              'tools.',
    );
    if (!confirmed) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'isAdmin': newValue,
    });
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}
