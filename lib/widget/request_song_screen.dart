import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pai_morn_web/auth/auth_provider.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/theme/app_theme.dart';

/// A no-login-required "do it for me" request: someone who can't work out
/// guitar chords themselves sends a song link plus the lyrics they've
/// already typed out, and a way to reach them back — an admin fills in the
/// chords and publishes it as a real song (via the existing Submit/Edit
/// flow), then contacts the requester directly using the link/email they
/// gave. Deliberately not required to log in: the target audience is a
/// one-time visitor who doesn't want to register just to ask once — but if
/// the requester happens to be signed in already, their uid is recorded
/// (privately, alongside contact info) so they can be notified in-app once
/// an admin links a fulfilled request to the real song (see
/// admin_song_requests_screen.dart and functions/index.js's
/// onSongRequestFulfilled); an anonymous request just has no uid to notify.
/// Requests are never shown publicly — only in the admin's Song Requests
/// queue.
class RequestSongScreen extends StatefulWidget {
  const RequestSongScreen({super.key});

  @override
  State<RequestSongScreen> createState() => _RequestSongScreenState();
}

class _RequestSongScreenState extends State<RequestSongScreen> {
  final _linkController = TextEditingController();
  final _lyricsController = TextEditingController();
  final _contactController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _submitted = false;

  @override
  void dispose() {
    _linkController.dispose();
    _lyricsController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submit(String language) async {
    final link = _linkController.text.trim();
    final lyrics = _lyricsController.text.trim();
    final contact = _contactController.text.trim();
    if (link.isEmpty || lyrics.isEmpty || contact.isEmpty) {
      setState(
        () =>
            _errorMessage = AppTranslations.getText(
              'requestSongPleaseFillFields',
              language,
            ),
      );
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      // Split across two docs so the requester's contact info can stay
      // admin-only while the rest (song link, lyrics, vote count) is
      // public/voteable — see firestore.rules' songRequests/{id}/private
      // subcollection. `createdAt` uses the same server timestamp value on
      // both, matching each doc's own `== request.time` rule check.
      final requestRef =
          FirebaseFirestore.instance.collection('songRequests').doc();
      final createdAt = FieldValue.serverTimestamp();
      // Only present when the requester happens to already be logged in —
      // never required, never prompted for; see the class doc comment.
      final requesterUid = context.read<AuthProvider>().user?.uid;
      final batch = FirebaseFirestore.instance.batch();
      batch.set(requestRef, {
        'songLink': link,
        'lyrics': lyrics,
        'voteCount': 0,
        'createdAt': createdAt,
      });
      batch.set(requestRef.collection('private').doc('info'), {
        'contact': contact,
        'createdAt': createdAt,
        if (requesterUid != null) 'requesterUid': requesterUid,
      });
      await batch.commit();
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitted = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString();
      });
    }
  }

  // Shows a fixed reference screenshot (assets/images/preview.png) of how
  // to format lyrics — a real example the maintainer supplied, not a
  // render of whatever the requester has typed so far. Tapping outside the
  // image dismisses it (showDialog's default barrier behavior); no extra
  // chrome is layered on top since the image already reads as a complete
  // "note" on its own.
  void _showPreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 700),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/preview.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final language = context.watch<LocaleProvider>().currentLanguage;

    // A scroll container the form's own height can never overflow, however
    // long the lyrics text or however little vertical space is left after
    // the navbar/footer — a real bug this page had before: on a short
    // mobile viewport the (non-scrollable) form's bottom, including the
    // Submit button, silently overflowed past its box and got painted over
    // by whatever rendered after it in the page's Column. LayoutBuilder +
    // a minHeight constraint keeps the original centered-on-a-tall-screen
    // look for short content while still allowing real scrolling once the
    // content is taller than the viewport.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child:
                      _submitted
                          ? _buildSuccess(scheme, language)
                          : _buildForm(scheme, language),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuccess(ColorScheme scheme, String language) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FaIcon(FontAwesomeIcons.circleCheck, size: 56, color: Colors.green),
        const SizedBox(height: 16),
        Text(
          AppTranslations.getText('requestSongSuccessMessage', language),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: scheme.onSurface),
        ),
      ],
    );
  }

  Widget _buildForm(ColorScheme scheme, String language) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 5,
              height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF6C5CE7), Color(0xFF0984E3)],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              AppTranslations.getText('requestSongLabel', language),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          AppTranslations.getText('requestSongIntro', language),
          style: TextStyle(color: scheme.onSurface.withOpacity(0.7)),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go('/song-requests/vote'),
            icon: const FaIcon(FontAwesomeIcons.thumbsUp, size: 16),
            label: Text(
              AppTranslations.getText('voteSongRequestsTitle', language),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        TextField(
          controller: _linkController,
          decoration: InputDecoration(
            labelText: AppTranslations.getText('requestSongLinkLabel', language),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _lyricsController,
          minLines: 8,
          maxLines: 20,
          decoration: InputDecoration(
            labelText: AppTranslations.getText(
              'requestSongLyricsLabel',
              language,
            ),
            hintText: AppTranslations.getText(
              'requestSongLyricsHint',
              language,
            ),
            alignLabelWithHint: true,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _showPreview(context),
            icon: const FaIcon(FontAwesomeIcons.eye, size: 18),
            label: Text(AppTranslations.getText('viewExampleLabel', language)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _contactController,
          decoration: InputDecoration(
            labelText: AppTranslations.getText(
              'requestSongContactLabel',
              language,
            ),
            hintText: AppTranslations.getText(
              'requestSongContactHint',
              language,
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_errorMessage!, style: TextStyle(color: scheme.error)),
        ],
        const SizedBox(height: AppSpacing.lg),
        ElevatedButton(
          onPressed: _isSubmitting ? null : () => _submit(language),
          child:
              _isSubmitting
                  ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.surface,
                    ),
                  )
                  : Text(
                    AppTranslations.getText('requestSongSubmitButton', language),
                  ),
        ),
      ],
    );
  }
}
