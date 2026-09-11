import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:web/web.dart' as web;

/// A small floating YouTube embed — deliberately NOT shrunk to nothing.
/// Fully hiding the iframe would also hide YouTube's own "Skip Ad" button
/// whenever a pre-roll ad plays, leaving no way to get past it; keeping a
/// real (if small) visible player means that button stays reachable. This
/// is a real embedded video player, not an audio-only stream — there's no
/// way to pull just the audio track out of a YouTube video without
/// violating YouTube's terms of service, so showing a small video instead
/// of hiding it entirely is the deliberate compromise, not a bug.
class YoutubeMiniPlayer extends StatefulWidget {
  const YoutubeMiniPlayer({
    super.key,
    required this.videoId,
    required this.onClose,
  });

  final String videoId;
  final VoidCallback onClose;

  @override
  State<YoutubeMiniPlayer> createState() => _YoutubeMiniPlayerState();
}

class _YoutubeMiniPlayerState extends State<YoutubeMiniPlayer> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    // Unique per mount (not just per video) so reopening the player after
    // closing it registers a fresh view factory/iframe instead of trying to
    // reuse one platform view registry has already discarded.
    _viewType =
        'youtube-mini-player-${widget.videoId}-${identityHashCode(this)}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe =
          web.HTMLIFrameElement()
            ..src =
                'https://www.youtube.com/embed/${widget.videoId}?autoplay=1'
            ..style.border = 'none'
            ..allow = 'autoplay; encrypted-media'
            ..allowFullscreen = true
            // Without this, YouTube's player fails to initialize inside a
            // Flutter web platform-view iframe with "Error 153" (a video
            // player configuration error tied to how it reads the
            // embedding page's referrer) — confirmed by testing the same
            // iframe both ways. A plain, non-Flutter page never needs this,
            // which is why the difference is easy to miss until it's
            // actually tested end to end.
            ..referrerPolicy = 'strict-origin';
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 220,
        height: 160,
        child: Stack(
          children: [
            Positioned.fill(child: HtmlElementView(viewType: _viewType)),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const FaIcon(
                    FontAwesomeIcons.xmark,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
