import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pai_morn_web/auth/auth_provider.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';

/// One setlist's ordered song list — reorder by drag, remove a song, rename
/// or delete the whole list, and jump into the reader for any song with
/// Next/Previous wired to step through this same order (see
/// SongReaderScreen's `setlistId` param). Reached by a real URL
/// (`/setlists/:id`, see main.dart), matching CommunityThreadScreen's shape.
class SetlistDetailScreen extends StatefulWidget {
  const SetlistDetailScreen({super.key, required this.setlistId});

  final String setlistId;

  @override
  State<SetlistDetailScreen> createState() => _SetlistDetailScreenState();
}

class _SetlistDetailScreenState extends State<SetlistDetailScreen> {
  List<String> _songIds = [];
  final Map<String, Map<String, dynamic>> _songCache = {};

  DocumentReference<Map<String, dynamic>> _setlistRef(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('setlists')
          .doc(widget.setlistId);

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/setlists');
    }
  }

  // The reader's Next/Previous only steps through ids already loaded here,
  // so only sync when the actual membership changed (added/removed
  // elsewhere) — a reorder written by this screen itself would otherwise
  // fight with the stream echoing it straight back.
  void _syncSongIds(List<String> incoming) {
    final sameSet =
        incoming.length == _songIds.length &&
        incoming.toSet().containsAll(_songIds);
    if (!sameSet) {
      setState(() => _songIds = incoming);
    }
    _ensureSongsLoaded(incoming);
  }

  Future<void> _ensureSongsLoaded(List<String> ids) async {
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

  Future<void> _persistOrder(String uid) async {
    await _setlistRef(uid).update({
      'songIds': _songIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _removeSong(String uid, String songId) async {
    setState(() => _songIds.remove(songId));
    await _persistOrder(uid);
  }

  Future<void> _rename(
    BuildContext context,
    String uid,
    String currentName,
    String language,
  ) async {
    final controller = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppTranslations.getText('renameSetlistTitle', language)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: AppTranslations.getText('setlistNameHint', language),
            ),
            onSubmitted:
                (value) => Navigator.of(dialogContext).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppTranslations.getText('cancelButton', language)),
            ),
            ElevatedButton(
              onPressed:
                  () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(AppTranslations.getText('saveButton', language)),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    await _setlistRef(
      uid,
    ).update({'name': name, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> _share(
    BuildContext context,
    String uid,
    bool isPublic,
    String language,
  ) async {
    if (!isPublic) {
      await _setlistRef(
        uid,
      ).update({'public': true, 'updatedAt': FieldValue.serverTimestamp()});
    }
    if (!context.mounted) return;
    final url = 'https://song-and-chord.web.app/setlists/shared/$uid/${widget.setlistId}';
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppTranslations.getText('shareSetlistTitle', language)),
          content: SelectableText(url),
          actions: [
            TextButton(
              onPressed: () async {
                await _setlistRef(uid).update({
                  'public': false,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: Text(
                AppTranslations.getText('stopSharingLabel', language),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: Text(AppTranslations.getText('copyLinkLabel', language)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String uid,
    String language,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            AppTranslations.getText('deleteSetlistConfirmTitle', language),
          ),
          content: Text(
            AppTranslations.getText('deleteSetlistConfirmMessage', language),
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
    if (confirmed != true || !context.mounted) return;
    await _setlistRef(uid).delete();
    if (context.mounted) context.go('/setlists');
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LocaleProvider>().currentLanguage;
    final scheme = Theme.of(context).colorScheme;
    final uid = context.watch<AuthProvider>().user?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _setlistRef(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.data!.exists) {
          // Deleted from elsewhere (e.g. another tab) — bounce back to the
          // list rather than rendering a broken detail page.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) _goBack(context);
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!.data()!;
        final name = (data['name'] as String?) ?? '';
        final isPublic = data['public'] as bool? ?? false;
        final incoming = List<String>.from(data['songIds'] as List? ?? []);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _syncSongIds(incoming),
        );

        final songs =
            _songIds
                .where((id) => _songCache.containsKey(id))
                .map((id) => MapEntry(id, _songCache[id]!))
                .toList();

        return Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: () => _goBack(context)),
            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                icon: FaIcon(
                  isPublic
                      ? FontAwesomeIcons.solidShareFromSquare
                      : FontAwesomeIcons.shareFromSquare,
                  size: 18,
                ),
                tooltip: AppTranslations.getText('shareSetlistTitle', language),
                onPressed: () => _share(context, uid, isPublic, language),
              ),
              IconButton(
                icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 18),
                onPressed: () => _rename(context, uid, name, language),
              ),
              IconButton(
                icon: const FaIcon(FontAwesomeIcons.trashCan, size: 18),
                onPressed: () => _confirmDelete(context, uid, language),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                children: [
                  if (songs.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed:
                              () => context.go(
                                '/songbook/song/${songs.first.key}'
                                '?setlist=${widget.setlistId}',
                              ),
                          icon: const FaIcon(FontAwesomeIcons.play, size: 14),
                          label: Text(
                            AppTranslations.getText('playLabel', language),
                          ),
                        ),
                      ),
                    ),
                  if (songs.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FaIcon(
                              FontAwesomeIcons.music,
                              size: 40,
                              color: scheme.onSurface.withOpacity(0.25),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              AppTranslations.getText(
                                'noSongsInSetlistMessage',
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
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: songs.length,
                        onReorder: (oldIndex, newIndex) {
                          if (newIndex > oldIndex) newIndex -= 1;
                          setState(() {
                            final id = _songIds.removeAt(oldIndex);
                            _songIds.insert(newIndex, id);
                          });
                          _persistOrder(uid);
                        },
                        itemBuilder: (context, index) {
                          final entry = songs[index];
                          final songId = entry.key;
                          final songData = entry.value;
                          final songName =
                              (songData['songName'] as String?) ?? '';
                          final artist = (songData['artist'] as String?) ?? '';
                          return Card(
                            key: ValueKey(songId),
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              title: Text(songName),
                              subtitle: Text(artist),
                              trailing: IconButton(
                                icon: const FaIcon(
                                  FontAwesomeIcons.xmark,
                                  size: 18,
                                ),
                                onPressed: () => _removeSong(uid, songId),
                              ),
                              onTap:
                                  () => context.go(
                                    '/songbook/song/$songId'
                                    '?setlist=${widget.setlistId}',
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
