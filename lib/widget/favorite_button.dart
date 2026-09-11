import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:pai_morn_web/auth/auth_provider.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';

/// A heart toggle reflecting whether the signed-in user has favorited
/// [songId] — membership is just the existence of a
/// `users/{uid}/favorites/{songId}` doc (see firestore.rules), not a field
/// on the song itself, so favoriting never needs write access to a song a
/// user doesn't own. Renders nothing for a signed-out visitor rather than a
/// disabled heart, since there's no per-user favorites list to toggle
/// membership in until they're signed in.
class FavoriteButton extends StatefulWidget {
  const FavoriteButton({super.key, required this.songId, this.size = 24, this.color});

  final String songId;
  final double size;

  // Color for the *unfavorited* (outline) state. Previously left this to
  // IconButton's own `color:` shorthand, which turned out to render
  // correctly in a plain ListTile but stayed near-invisible when the same
  // button sat in an AppBar's actions — IconButton's foreground-color
  // resolution apparently gets overridden by the AppBar's action icon
  // theming in a way `color:` doesn't survive. Rendering a bare `Icon`
  // ourselves (below) sidesteps that entirely: nothing merges over an
  // Icon's own explicit `color`.
  final Color? color;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton>
    with SingleTickerProviderStateMixin {
  // A small "ลูกเล่น" (flair) touch — a quick bounce/pop on the heart icon
  // itself when *favoriting* (not un-favoriting, which stays a plain
  // instant swap — the pop reads as a reward for a positive action, not for
  // its reverse). Pure scale animation on the existing icon rather than a
  // particle burst or new dependency, since a compact heart in an AppBar or
  // list row has little room for anything larger without overlapping
  // neighboring content.
  late final AnimationController _popController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.5,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.5,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 65,
      ),
    ]).animate(_popController);
  }

  @override
  void dispose() {
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid;
    if (uid == null) return const SizedBox.shrink();
    final language = context.watch<LocaleProvider>().currentLanguage;
    final scheme = Theme.of(context).colorScheme;

    final favRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(widget.songId);

    return StreamBuilder<DocumentSnapshot>(
      stream: favRef.snapshots(),
      builder: (context, snapshot) {
        final isFavorited = snapshot.data?.exists ?? false;
        return Tooltip(
          message: AppTranslations.getText(
            isFavorited ? 'removeFromFavorites' : 'addToFavorites',
            language,
          ),
          child: InkResponse(
            radius: widget.size,
            onTap: () {
              if (isFavorited) {
                favRef.delete();
              } else {
                favRef.set({'addedAt': FieldValue.serverTimestamp()});
                _popController.forward(from: 0);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: AnimatedBuilder(
                animation: _scale,
                builder:
                    (context, child) =>
                        Transform.scale(scale: _scale.value, child: child),
                child: FaIcon(
                  isFavorited
                      ? FontAwesomeIcons.solidHeart
                      : FontAwesomeIcons.heart,
                  size: widget.size,
                  color:
                      isFavorited
                          ? Colors.redAccent
                          : (widget.color ?? scheme.onSurface),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
