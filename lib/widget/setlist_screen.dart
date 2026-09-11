import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pai_morn_web/auth/auth_provider.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';

/// A logged-in user's own setlists — private groupings of songs (e.g. for a
/// gig or a practice session) they can reorder and step through from the
/// song reader. See users/{uid}/setlists/{id} in firestore.rules for the
/// owner-only read/write scope.
class SetlistScreen extends StatelessWidget {
  const SetlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final language = context.watch<LocaleProvider>().currentLanguage;
    final auth = context.watch<AuthProvider>();
    final uid = auth.user?.uid;
    if (uid == null) return const SizedBox.shrink();

    final setlistsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('setlists');

    return StreamBuilder<QuerySnapshot>(
      stream: setlistsRef.orderBy('updatedAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppTranslations.getText('setlistsTitle', language),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed:
                            () => _createSetlist(context, setlistsRef, language),
                        icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
                        label: Text(
                          AppTranslations.getText('newSetlistTitle', language),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (docs.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FaIcon(
                              FontAwesomeIcons.listCheck,
                              size: 40,
                              color: scheme.onSurface.withOpacity(0.25),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              AppTranslations.getText(
                                'noSetlistsYet',
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
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final name = (data['name'] as String?) ?? '';
                          final songIds = List<String>.from(
                            data['songIds'] as List? ?? [],
                          );
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: const FaIcon(FontAwesomeIcons.listCheck),
                              title: Text(name),
                              subtitle: Text(
                                _songsCountLabel(songIds.length, language),
                              ),
                              trailing: IconButton(
                                icon: const FaIcon(
                                  FontAwesomeIcons.trashCan,
                                  size: 18,
                                ),
                                onPressed:
                                    () => _confirmDelete(
                                      context,
                                      doc.reference,
                                      language,
                                    ),
                              ),
                              onTap: () => context.go('/setlists/${doc.id}'),
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

  // Only English marks singular/plural — Shan and Burmese use the same word
  // regardless of count (mirrors book_screen.dart's _songsCountLabel).
  String _songsCountLabel(int count, String language) {
    final key =
        count == 1 && language == 'en'
            ? 'songCountLabelSingular'
            : 'songsCountLabel';
    return AppTranslations.getText(key, language).replaceFirst(
      '{count}',
      '$count',
    );
  }

  Future<void> _createSetlist(
    BuildContext context,
    CollectionReference setlistsRef,
    String language,
  ) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppTranslations.getText('newSetlistTitle', language)),
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
    if (name == null || name.isEmpty) return;
    final doc = await setlistsRef.add({
      'name': name,
      'songIds': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (context.mounted) context.go('/setlists/${doc.id}');
  }

  Future<void> _confirmDelete(
    BuildContext context,
    DocumentReference ref,
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
    if (confirmed != true) return;
    await ref.delete();
  }
}
