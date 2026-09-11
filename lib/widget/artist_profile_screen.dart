import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:pai_morn_web/theme/app_theme.dart';
import 'package:pai_morn_web/utils/artist_palette.dart';

/// A public profile page for one artist — photo (or the same deterministic
/// color-hash fallback Home/SongBook already use for that name), an
/// optional bio, and every approved song crediting them. Reached by tapping
/// an artist card on Home (see home_screen.dart's `_artistTile`) — SongBook's
/// own artist filter is left as its own in-place filtering, unchanged,
/// since it's combined there with Category/Key filters in a way a
/// dedicated page would complicate rather than simplify.
///
/// `photoUrl`/`bio` are only ever written by an admin (admin_artists_screen.
/// dart, matching firestore.rules' artists/{id} update rule) — a plain
/// signed-in user can still create a brand-new artist via the submit-song
/// typeahead, just without either field, which this page treats the same
/// as "not set yet" rather than an error.
class ArtistProfileScreen extends StatelessWidget {
  const ArtistProfileScreen({super.key, required this.artistId});

  final String artistId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection('artists')
                .doc(artistId)
                .snapshots(),
        builder: (context, artistSnap) {
          if (!artistSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!artistSnap.data!.exists) {
            return Center(
              child: Text(
                'Artist not found',
                style: TextStyle(color: scheme.onSurface),
              ),
            );
          }
          final data = artistSnap.data!.data() ?? {};
          final name = (data['name'] as String?) ?? '';
          final bio = (data['bio'] as String?)?.trim() ?? '';
          final photoUrl = (data['photoUrl'] as String?)?.trim() ?? '';
          final baseColor = colorForArtist(name);
          final deepColor = Color.lerp(baseColor, Colors.black, 0.35)!;

          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const FaIcon(FontAwesomeIcons.arrowLeft),
                        onPressed:
                            () =>
                                context.canPop()
                                    ? context.pop()
                                    : context.go('/'),
                      ),
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient:
                                    photoUrl.isEmpty
                                        ? LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [baseColor, deepColor],
                                        )
                                        : null,
                                boxShadow: AppShadows.soft(scheme.onSurface),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child:
                                  photoUrl.isEmpty
                                      ? const Center(
                                        child: FaIcon(
                                          FontAwesomeIcons.recordVinyl,
                                          color: Colors.white,
                                          size: 44,
                                        ),
                                      )
                                      : CachedNetworkImage(
                                        imageUrl: photoUrl,
                                        fit: BoxFit.cover,
                                        width: 120,
                                        height: 120,
                                      ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
                            ),
                            if (bio.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                bio,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.6,
                                  color: scheme.onSurface.withOpacity(0.75),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildSongs(context, scheme),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSongs(BuildContext context, ColorScheme scheme) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('songs')
              .where('status', isEqualTo: 'approved')
              .where('artistIds', arrayContains: artistId)
              .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        if (snapshot.hasData && docs.isEmpty) {
          return Text(
            'No songs yet.',
            style: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
          );
        }
        final sorted =
            docs.toList()..sort((a, b) {
              final an = (a.data()['songName'] as String?) ?? '';
              final bn = (b.data()['songName'] as String?) ?? '';
              return an.compareTo(bn);
            });
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Songs',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            for (final doc in sorted)
              _SongRow(
                songId: doc.id,
                songName: (doc.data()['songName'] as String?) ?? '',
              ),
          ],
        );
      },
    );
  }
}

class _SongRow extends StatelessWidget {
  const _SongRow({required this.songId, required this.songName});

  final String songId;
  final String songName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.go('/songbook/song/$songId'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            FaIcon(
              FontAwesomeIcons.music,
              size: 14,
              color: scheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                songName,
                style: TextStyle(fontSize: 15, color: scheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
