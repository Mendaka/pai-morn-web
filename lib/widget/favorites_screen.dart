import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pai_morn_web/auth/auth_provider.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/utils/artist_palette.dart';
import 'package:pai_morn_web/widget/favorite_button.dart';

/// A logged-in user's saved songs — membership comes from the
/// `users/{uid}/favorites` subcollection (see favorite_button.dart), listed
/// newest-favorited-first. Reachable only when logged in; gated at the
/// routing level in main.dart like the other account-only screens.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final language = context.watch<LocaleProvider>().currentLanguage;
    final uid = context.watch<AuthProvider>().user?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('favorites')
              .orderBy('addedAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final favoriteIds = snapshot.data!.docs.map((doc) => doc.id).toList();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppTranslations.getText('favoritesTitle', language),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (favoriteIds.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FaIcon(
                              FontAwesomeIcons.heart,
                              size: 40,
                              color: scheme.onSurface.withOpacity(0.25),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              AppTranslations.getText(
                                'noFavoritesYet',
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
                        itemCount: favoriteIds.length,
                        itemBuilder: (context, index) {
                          return _FavoriteSongTile(songId: favoriteIds[index]);
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

class _FavoriteSongTile extends StatelessWidget {
  const _FavoriteSongTile({required this.songId});

  final String songId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('songs')
              .doc(songId)
              .snapshots(),
      builder: (context, snapshot) {
        // Covers both "still loading" and "this song was deleted after
        // being favorited" — skip the row rather than show a broken-looking
        // blank tile. A still-loading doc briefly looks the same as a
        // deleted one; an acceptable trade for not needing a separate
        // per-row loading state.
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final songName = (data['songName'] as String?) ?? '';
        final artist = (data['artist'] as String?) ?? '';
        // Same per-artist identity color used on Home/SongBook/the reader —
        // this list was previously a plain, colorless stack of rows with
        // nothing visually tying it to the rest of the app.
        final accent = colorForArtist(artist.isNotEmpty ? artist : songName);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: accent,
              child: const FaIcon(FontAwesomeIcons.music, color: Colors.white, size: 18),
            ),
            title: Text(songName),
            subtitle: artist.isEmpty ? null : Text(artist),
            trailing: FavoriteButton(songId: songId),
            onTap: () => context.go('/songbook/song/$songId'),
          ),
        );
      },
    );
  }
}
