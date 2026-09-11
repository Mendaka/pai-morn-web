import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// 0 = no badge yet, 1 = bronze (10+ approved songs), 2 = silver (100+),
/// 3 = gold (500+).
int badgeTier(int approvedSongCount) {
  if (approvedSongCount >= 500) return 3;
  if (approvedSongCount >= 100) return 2;
  if (approvedSongCount >= 10) return 1;
  return 0;
}

const Map<int, Color> _tierColors = {
  1: Color(0xFFCD7F32), // bronze
  2: Color(0xFFA8A9AD), // silver
  3: Color(0xFFFFD700), // gold
};

const Map<int, String> _tierLabels = {1: 'Bronze', 2: 'Silver', 3: 'Gold'};

/// Human-readable tier name, e.g. "Bronze". Empty string for tier 0.
String badgeTierLabel(int tier) => _tierLabels[tier] ?? '';

/// The tier's medal color (bronze/silver/gold) — null for tier 0, letting
/// callers fall back to a neutral color instead of a meaningless one.
Color? badgeTierColor(int tier) => _tierColors[tier];

/// Small star icon reflecting a contributor's badge tier. Renders nothing
/// for tier 0 — a placeholder visual treatment, easy to swap for a nicer
/// medal/ribbon asset later.
class BadgeIcon extends StatelessWidget {
  const BadgeIcon({super.key, required this.tier, this.size = 14});

  final int tier;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (tier <= 0) return const SizedBox.shrink();
    return Tooltip(
      message: '${_tierLabels[tier]} contributor',
      child: FaIcon(
        FontAwesomeIcons.solidStar,
        size: size,
        color: _tierColors[tier],
      ),
    );
  }
}
