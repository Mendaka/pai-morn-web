// Port of lib/utils/badge_tier.dart. 0 = no badge yet, 1 = bronze (10+
// approved songs), 2 = silver (100+), 3 = gold (500+).
export const TIER_THRESHOLDS: readonly number[] = [10, 100, 500];

export function badgeTier(approvedSongCount: number): 0 | 1 | 2 | 3 {
  if (approvedSongCount >= 500) return 3;
  if (approvedSongCount >= 100) return 2;
  if (approvedSongCount >= 10) return 1;
  return 0;
}

const LABELS = ["", "Bronze", "Silver", "Gold"] as const;
const COLORS = ["", "#CD7F32", "#A8A9AD", "#FFD700"] as const;

export const badgeLabel = (tier: number): string => LABELS[tier] ?? "";
export const badgeColor = (tier: number): string | null => COLORS[tier] || null;

/** What's left to reach the next tier, or null once at gold. */
export function nextTier(approvedSongCount: number): { label: string; target: number; remaining: number } | null {
  const tier = badgeTier(approvedSongCount);
  if (tier >= 3) return null;
  const target = TIER_THRESHOLDS[tier]!;
  return { label: badgeLabel(tier + 1), target, remaining: target - approvedSongCount };
}
