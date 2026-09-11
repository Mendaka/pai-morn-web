import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';

/// The no-login, read-only view of a setlist someone shared (see the Share
/// button in setlist_detail_screen.dart) — reached via `/setlists/shared/
/// :ownerUid/:setlistId`, a URL anyone can open. No reorder/rename/delete/
/// remove here, just browse and tap into the reader, same as any other
/// public song content. If the owner later turns sharing back off, the
/// Firestore rule denies the read outright (not "not found" — a
/// permission error), so that's handled the same way as a missing doc.
class PublicSetlistScreen extends StatefulWidget {
  const PublicSetlistScreen({
    super.key,
    required this.ownerUid,
    required this.setlistId,
  });

  final String ownerUid;
  final String setlistId;

  @override
  State<PublicSetlistScreen> createState() => _PublicSetlistScreenState();
}

class _PublicSetlistScreenState extends State<PublicSetlistScreen> {
  final Map<String, Map<String, dynamic>> _songCache = {};
  List<String> _lastLoadedIds = [];

  DocumentReference<Map<String, dynamic>> get _setlistRef => FirebaseFirestore
      .instance
      .collection('users')
      .doc(widget.ownerUid)
      .collection('setlists')
      .doc(widget.setlistId);

  Future<void> _ensureSongsLoaded(List<String> ids) async {
    final unchanged =
        ids.length == _lastLoadedIds.length &&
        ids.every((id) => _lastLoadedIds.contains(id));
    if (unchanged) return;
    _lastLoadedIds = ids;
    final missing = ids.where((id) => !_songCache.containsKey(id)).toList();
    if (missing.isEmpty) return;
    final results = await Future.wait(
      missing.map(
        (id) => FirebaseFirestore.instance.collection('songs').doc(id).get(),
      ),
    );
    if (!mounted) return;
    setState(() {
      for (final doc in results) {
        if (doc.exists) _songCache[doc.id] = doc.data() as Map<String, dynamic>;
      }
    });
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LocaleProvider>().currentLanguage;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _setlistRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !(snapshot.data?.exists ?? false)) {
          return Scaffold(
            appBar: AppBar(leading: BackButton(onPressed: () => _goBack(context))),
            body: Center(
              child: Text(
                AppTranslations.getText('setlistNotFoundMessage', language),
              ),
            ),
          );
        }
        final data = snapshot.data!.data()!;
        final name = (data['name'] as String?) ?? '';
        final songIds = List<String>.from(data['songIds'] as List? ?? []);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _ensureSongsLoaded(songIds),
        );

        final songs =
            songIds
                .where((id) => _songCache.containsKey(id))
                .map((id) => MapEntry(id, _songCache[id]!))
                .toList();

        return Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: () => _goBack(context)),
            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future:
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.ownerUid)
                            .get(),
                    builder: (context, ownerSnapshot) {
                      final ownerName =
                          (ownerSnapshot.data?.data()?['displayName']
                              as String?) ??
                          '';
                      if (ownerName.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Text(
                          '${AppTranslations.getText('sharedByLabel', language)}: $ownerName',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    },
                  ),
                  if (songs.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed:
                              () => context.go(
                                '/songbook/song/${songs.first.key}',
                              ),
                          icon: const FaIcon(FontAwesomeIcons.play, size: 14),
                          label: Text(
                            AppTranslations.getText('playLabel', language),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: songs.length,
                      itemBuilder: (context, index) {
                        final entry = songs[index];
                        final songData = entry.value;
                        final songName =
                            (songData['songName'] as String?) ?? '';
                        final artist = (songData['artist'] as String?) ?? '';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(songName),
                            subtitle: Text(artist),
                            onTap:
                                () => context.go(
                                  '/songbook/song/${entry.key}',
                                ),
                          ),
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
