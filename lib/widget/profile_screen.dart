import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pai_morn_web/auth/auth_provider.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/utils/badge_tier.dart';
import 'package:pai_morn_web/utils/image_resize.dart';
import 'package:pai_morn_web/theme/app_theme.dart';
import 'package:pai_morn_web/widget/submit_song_screen.dart';

/// A logged-in user's own profile — display name (editable, matching the
/// Firestore rule that only ever lets a user touch their own
/// displayName/photoUrl), a profile photo, badge tier, approved-song count,
/// and their own songs at a glance. Reachable only when logged in (gated at
/// the routing level in home_page.dart like the other account-only
/// screens).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.startInEditMode = false});

  // Set via the `/profile?edit=1` route (see main.dart) — the account
  // drawer's "Change profile name" item is the only entry point that opens
  // straight into the inline name editor now; the page itself no longer
  // shows a pencil icon at all times (a user found that cluttered).
  final bool startInEditMode;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const double _bannerHeight = 96;
  static const double _avatarRadius = 48;

  // A fixed gradient for this page only — deliberately NOT colorForArtist's
  // per-name hash (used everywhere else: Home/SongBook/About), since a user
  // disliked the specific color their own name happened to hash to and
  // recoloring the shared palette would ripple across every one of those
  // other surfaces. This makes the page look the same, deliberately-chosen
  // way for every user instead of a random per-name result.
  static const Color _accentStart = Color(0xFF0984E3); // blue
  static const Color _accentEnd = Color(0xFFC2185B); // dark pink

  final _nameController = TextEditingController();
  bool _editingName = false;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _seededName;

  // Confetti celebration when a contributor crosses into a new badge tier
  // (Bronze/Silver/Gold) — a delight touch requested alongside a batch of
  // other small "ลูกเล่น" ideas. Tier itself is a pure function of
  // approvedSongCount (badge_tier.dart), so "just reached a new tier" isn't
  // an event anything fires — it has to be detected here by comparing the
  // current tier against the last tier this device has ever recorded for
  // this user (see _maybeCelebrateBadge). Kept per-device in
  // SharedPreferences rather than a Firestore field: this is a one-time
  // celebratory animation, not data anything else needs to read, and every
  // existing contributor's first load after this feature ships must NOT
  // retroactively celebrate a tier they already had.
  late final ConfettiController _confettiController;
  int? _lastCheckedTier;

  @override
  void initState() {
    super.initState();
    _editingName = widget.startInEditMode;
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _maybeCelebrateBadge(String uid, int tier) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'badge_tier_seen_$uid';
    final seenTier = prefs.getInt(key);
    if (seenTier == null) {
      // First time this device has ever checked for this user — record
      // where they already stand without celebrating, so an existing Gold
      // contributor doesn't get a confetti blast just for loading the app
      // after this feature shipped.
      await prefs.setInt(key, tier);
      return;
    }
    if (tier <= seenTier) return;
    await prefs.setInt(key, tier);
    if (!mounted) return;
    _confettiController.play();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 ยินดีด้วย! คุณได้ตรา ${badgeTierLabel(tier)} แล้ว'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _saveName(String uid) async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;
    setState(() => _saving = true);
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'displayName': newName,
    });
    if (!mounted) return;
    setState(() {
      _saving = false;
      _editingName = false;
    });
  }

  String _formatJoinDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Future<void> _pickAndUploadPhoto(String uid) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 95, // final compression still happens in resizeImageForUpload
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final originalBytes = await picked.readAsBytes();
      // Client-side guard before spending time resizing/uploading — Storage
      // rules enforce the real 5MB cap server-side regardless.
      if (originalBytes.lengthInBytes > 15 * 1024 * 1024) {
        throw 'That image is too large. Please choose a smaller photo.';
      }
      final resizedBytes = await resizeImageForUpload(originalBytes);
      final ref = FirebaseStorage.instance.ref('profile_photos/$uid');
      await ref.putData(
        resizedBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'photoUrl': url,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final uid = auth.user?.uid;
    if (uid == null) return const SizedBox.shrink();

    // Seed the name field once per real name change (not every rebuild,
    // which would stomp on in-progress typing).
    final currentName = auth.displayName ?? '';
    if (_seededName != currentName) {
      _seededName = currentName;
      _nameController.text = currentName;
    }

    final tier = badgeTier(auth.approvedSongCount);
    if (_lastCheckedTier != tier) {
      _lastCheckedTier = tier;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _maybeCelebrateBadge(uid, tier),
      );
    }
    final tierColor = badgeTierColor(tier);
    final monogram =
        currentName.trim().isEmpty
            ? '?'
            : currentName.trim().substring(0, 1).toUpperCase();
    final hasPhoto = auth.photoUrl?.isNotEmpty ?? false;

    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              // A single elevated "card" for the whole profile (banner +
              // details) rather than the banner floating loose on the plain
              // page background — a soft shadow and rounded card is what
              // actually reads as a premium panel instead of a stack of
              // separate flat blocks. The banner itself no longer carries
              // its own border radius; this outer clip rounds it instead,
              // so the banner's bottom edge sits flush with the details
              // section beneath it.
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.soft(scheme.onSurface),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        height: _bannerHeight,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_accentStart, _accentEnd],
                          ),
                          // Experimental: user asked to try this bundled
                          // brand asset as the cover photo — painted over
                          // the gradient (the gradient stays as a fallback/
                          // base in case this doesn't read well and gets
                          // reverted). pickup2.jpg (blue background, white
                          // pick) reads far better here than pickup.jpg's
                          // stark black-on-white version did.
                          image: DecorationImage(
                            image: AssetImage('assets/images/pickup2.jpg'),
                            fit: BoxFit.cover,
                          ),
                        ),
                        // Two soft, low-opacity highlight blobs — a cheap
                        // (no BackdropFilter/blur needed) way to give the
                        // flat gradient some depth/sheen instead of reading
                        // as a single flat-colored rectangle.
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: -30,
                              right: -20,
                              child: _glowBlob(120, Colors.white.withOpacity(0.14)),
                            ),
                            Positioned(
                              bottom: -40,
                              left: -30,
                              child: _glowBlob(100, Colors.black.withOpacity(0.10)),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: _bannerHeight - _avatarRadius,
                        child: GestureDetector(
                          onTap:
                              _uploadingPhoto
                                  ? null
                                  : () => _pickAndUploadPhoto(uid),
                          child: Container(
                            width: _avatarRadius * 2,
                            height: _avatarRadius * 2,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.surface,
                              boxShadow: AppShadows.soft(Colors.black),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _accentStart,
                                    border:
                                        tierColor != null
                                            ? Border.all(
                                              color: tierColor,
                                              width: 3,
                                            )
                                            : null,
                                  ),
                                  child:
                                      hasPhoto
                                          ? ClipOval(
                                            child: CachedNetworkImage(
                                              imageUrl: auth.photoUrl!,
                                              fit: BoxFit.cover,
                                              width: _avatarRadius * 2 - 8,
                                              height: _avatarRadius * 2 - 8,
                                            ),
                                          )
                                          : Text(
                                            monogram,
                                            style: const TextStyle(
                                              fontSize: 40,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                ),
                                if (_uploadingPhoto)
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black45,
                                      ),
                                      child: const Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _accentEnd,
                                      border: Border.all(
                                        color: scheme.surface,
                                        width: 2,
                                      ),
                                    ),
                                    child: const FaIcon(
                                      FontAwesomeIcons.camera,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: _avatarRadius + 16),
                  if (_editingName)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            autofocus: true,
                            decoration: const InputDecoration(isDense: true),
                            onSubmitted: (_) => _saveName(uid),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _saving
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : IconButton(
                              icon: const FaIcon(FontAwesomeIcons.check, size: 18),
                              onPressed: () => _saveName(uid),
                            ),
                      ],
                    )
                  else
                    Text(
                      currentName.isEmpty ? '(no name)' : currentName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                  if (auth.createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Member since ${_formatJoinDate(auth.createdAt!)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (tier > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: tierColor!.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: tierColor.withOpacity(0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: tierColor.withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BadgeIcon(tier: tier, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '${badgeTierLabel(tier)} contributor',
                            style: TextStyle(
                              color: tierColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          scheme,
                          icon: FontAwesomeIcons.music,
                          value: '${auth.approvedSongCount}',
                          label: 'Approved songs',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          scheme,
                          icon: FontAwesomeIcons.fire,
                          value: '${auth.currentStreak}',
                          label: 'Day streak',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _MySongsGrid(uid: uid),
                ],
              ),
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 30,
              colors: const [
                Colors.amber,
                Colors.pinkAccent,
                Colors.lightBlueAccent,
                Colors.greenAccent,
                Colors.orangeAccent,
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Purely decorative — a soft, blurless "glow" circle (a plain radial
  // gradient fading to transparent reads close enough to a real blur at
  // this size/opacity without the cost of a BackdropFilter) used to break
  // up the banner's single flat gradient fill.
  Widget _glowBlob(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
        ),
      ),
    );
  }

  Widget _statCard(
    ColorScheme scheme, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accentStart.withOpacity(0.08),
            _accentEnd.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.onSurface.withOpacity(0.08)),
        boxShadow: AppShadows.subtle(scheme.onSurface),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_accentStart, _accentEnd],
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }
}

// Compact "at a glance" view of the user's own songs, embedded directly on
// Profile instead of only a link out to the full MySongsScreen (which keeps
// its own detailed row — rejection reasons, deleting drafts — this is
// deliberately lighter). MySongsScreen's own row widget is private to that
// file and assumes a bounded-height ListView ancestor, neither of which fit
// here, hence a small dedicated widget instead of reusing it directly.
class _MySongsGrid extends StatelessWidget {
  const _MySongsGrid({required this.uid});

  final String uid;

  Color _statusColor(String status) => switch (status) {
    'approved' => Colors.green,
    'rejected' => Colors.redAccent,
    'draft' => Colors.grey,
    _ => Colors.orange,
  };

  void _openSong(
    BuildContext context,
    String songId,
    Map<String, dynamic> data,
  ) {
    final status = data['status'] as String? ?? 'pending';
    final isDraft = status == 'draft';
    final isRejected = status == 'rejected';
    if (isDraft || isRejected) {
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
    } else {
      context.go('/songbook/song/$songId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final language = context.watch<LocaleProvider>().currentLanguage;

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('songs')
              .where('authorId', isEqualTo: uid)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs =
            snapshot.data!.docs.toList()..sort((a, b) {
              final aTime =
                  (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              final bTime =
                  (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _ProfileScreenState._accentStart,
                        _ProfileScreenState._accentEnd,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppTranslations.getText('mySongsTitle', language),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              Text(
                AppTranslations.getText('noSubmissionsYet', language),
                style: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final doc in docs)
                    _SongChip(
                      songName:
                          ((doc.data() as Map<String, dynamic>)['songName']
                              as String?) ??
                          '',
                      statusColor: _statusColor(
                        (doc.data() as Map<String, dynamic>)['status']
                                as String? ??
                            'pending',
                      ),
                      onTap:
                          () => _openSong(
                            context,
                            doc.id,
                            doc.data() as Map<String, dynamic>,
                          ),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => context.go('/my-songs'),
                child: const Text('View all in My Songs'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SongChip extends StatelessWidget {
  const _SongChip({
    required this.songName,
    required this.statusColor,
    required this.onTap,
  });

  final String songName;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.onSurface.withOpacity(0.04),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border(left: BorderSide(color: statusColor, width: 3)),
          boxShadow: AppShadows.subtle(scheme.onSurface),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(FontAwesomeIcons.music, size: 16, color: statusColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                songName.isNotEmpty ? songName : 'Untitled draft',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onSurface, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
