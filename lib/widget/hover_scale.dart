import 'package:flutter/material.dart';

/// Wraps a tappable card/tile so it scales up and lifts slightly under the
/// mouse cursor — the small "things react to you" motion seen across most
/// premium/SaaS sites. `MouseRegion` simply never fires on touch input, so
/// this is a no-op (and harmless) on mobile/tablet — nothing to disable
/// per-platform. Only wrap things that are actually tappable; Material's
/// `InkWell`/buttons already get their own hover feedback (a color overlay)
/// for free, so this is for the non-Material card/tile widgets built with
/// plain `GestureDetector` + `Container` that had no hover feedback at all.
class HoverScale extends StatefulWidget {
  const HoverScale({
    super.key,
    required this.child,
    this.scale = 1.03,
    this.lift = 4,
    this.duration = const Duration(milliseconds: 150),
  });

  final Widget child;
  final double scale;
  final double lift;
  final Duration duration;

  @override
  State<HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<HoverScale> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: widget.duration,
        curve: Curves.easeOut,
        transformAlignment: Alignment.center,
        transform:
            _hovering
                ? (Matrix4.identity()
                  ..translateByDouble(0.0, -widget.lift, 0.0, 1.0)
                  ..scaleByDouble(widget.scale, widget.scale, widget.scale, 1.0))
                : Matrix4.identity(),
        child: widget.child,
      ),
    );
  }
}
