import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pai_morn_web/utils/artist_palette.dart';
import 'package:pai_morn_web/utils/image_resize.dart';
import 'package:pai_morn_web/widget/app_search_field.dart';

/// Admin-only artist management — search an artist (created automatically
/// the first time anyone types a new name into the submit-song typeahead,
/// see submit_song_screen.dart's `_resolveArtistIdFor`), then set a photo
/// and bio for their public profile page (artist_profile_screen.dart).
/// Editing is intentionally admin-only end to end: firestore.rules already
/// restricted `artists/{id}` updates to `isAdmin()` before this screen
/// existed (a plain user can only ever *create* a bare artist doc via the
/// typeahead), and storage.rules' new `artist_photos/{artistId}` path
/// mirrors that same admin-only check via a cross-service Firestore read.
class AdminArtistsScreen extends StatefulWidget {
  const AdminArtistsScreen({super.key});

  @override
  State<AdminArtistsScreen> createState() => _AdminArtistsScreenState();
}

class _AdminArtistsScreenState extends State<AdminArtistsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final query = _query.trim().toLowerCase();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Artists',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              AppSearchField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                hintText: 'Search artist name...',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('artists')
                          .orderBy('name')
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs =
                        snapshot.data!.docs.where((d) {
                          if (query.isEmpty) return true;
                          final name =
                              (d.data()['name'] as String? ?? '')
                                  .toLowerCase();
                          return name.contains(query);
                        }).toList();
                    if (docs.isEmpty) {
                      return Text(
                        'No artists found.',
                        style: TextStyle(
                          color: scheme.onSurface.withOpacity(0.6),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder:
                          (context, index) => _ArtistRow(
                            artistId: docs[index].id,
                            data: docs[index].data(),
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
  }
}

class _ArtistRow extends StatelessWidget {
  const _ArtistRow({required this.artistId, required this.data});

  final String artistId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = (data['name'] as String?) ?? '';
    final bio = (data['bio'] as String?) ?? '';
    final photoUrl = (data['photoUrl'] as String?)?.trim() ?? '';
    final color = colorForArtist(name);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: color,
          backgroundImage:
              photoUrl.isEmpty ? null : CachedNetworkImageProvider(photoUrl),
          child:
              photoUrl.isEmpty
                  ? const FaIcon(
                    FontAwesomeIcons.recordVinyl,
                    color: Colors.white,
                    size: 16,
                  )
                  : null,
        ),
        title: Text(name),
        subtitle:
            bio.isEmpty
                ? null
                : Text(
                  bio,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
                ),
        trailing: IconButton(
          icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 16),
          tooltip: 'Edit',
          onPressed:
              () => showDialog(
                context: context,
                builder:
                    (_) => _EditArtistDialog(
                      artistId: artistId,
                      name: name,
                      bio: bio,
                      photoUrl: photoUrl,
                    ),
              ),
        ),
      ),
    );
  }
}

class _EditArtistDialog extends StatefulWidget {
  const _EditArtistDialog({
    required this.artistId,
    required this.name,
    required this.bio,
    required this.photoUrl,
  });

  final String artistId;
  final String name;
  final String bio;
  final String photoUrl;

  @override
  State<_EditArtistDialog> createState() => _EditArtistDialogState();
}

class _EditArtistDialogState extends State<_EditArtistDialog> {
  late final _bioController = TextEditingController(text: widget.bio);
  bool _uploadingPhoto = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  // Same pick -> resize -> upload -> write-download-URL flow as
  // profile_screen.dart's own photo upload, sharing the extracted
  // resizeImageForUpload helper — only the Storage path and the
  // destination Firestore doc differ (artist_photos/{id} + artists/{id}
  // instead of profile_photos/{uid} + users/{uid}).
  Future<void> _pickAndUploadPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _uploadingPhoto = true;
      _error = null;
    });
    try {
      final originalBytes = await picked.readAsBytes();
      if (originalBytes.lengthInBytes > 15 * 1024 * 1024) {
        throw 'That image is too large. Please choose a smaller photo.';
      }
      final resizedBytes = await resizeImageForUpload(originalBytes);
      final ref = FirebaseStorage.instance.ref(
        'artist_photos/${widget.artistId}',
      );
      await ref.putData(
        resizedBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('artists')
          .doc(widget.artistId)
          .update({'photoUrl': url});
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = '$e'.replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _saveBio() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await FirebaseFirestore.instance
          .collection('artists')
          .doc(widget.artistId)
          .update({'bio': _bioController.text.trim()});
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = colorForArtist(widget.name);
    return AlertDialog(
      title: Text(widget.name),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: color,
              backgroundImage:
                  widget.photoUrl.isEmpty
                      ? null
                      : CachedNetworkImageProvider(widget.photoUrl),
              child:
                  widget.photoUrl.isEmpty
                      ? const FaIcon(
                        FontAwesomeIcons.recordVinyl,
                        color: Colors.white,
                      )
                      : null,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _uploadingPhoto ? null : _pickAndUploadPhoto,
              icon:
                  _uploadingPhoto
                      ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const FaIcon(FontAwesomeIcons.camera, size: 14),
              label: Text(
                widget.photoUrl.isEmpty ? 'Upload photo' : 'Change photo',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: "A short line about this artist...",
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _saveBio,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}
