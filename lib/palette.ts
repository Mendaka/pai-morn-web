// Deterministic gradient per seed (artist id / song id), so every artist and
// cover placeholder keeps the same colors everywhere without storing any.
const GRADIENTS: [string, string][] = [
  ["#6366f1", "#8b5cf6"],
  ["#0ea5e9", "#2563eb"],
  ["#14b8a6", "#0d9488"],
  ["#f43f5e", "#e11d48"],
  ["#f59e0b", "#ea580c"],
  ["#ec4899", "#c026d3"],
  ["#22c55e", "#15803d"],
  ["#64748b", "#334155"],
];

function hash(seed: string): number {
  let h = 2166136261;
  for (let i = 0; i < seed.length; i++) {
    h ^= seed.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

export function gradientFor(seed: string): string {
  const [a, b] = GRADIENTS[hash(seed) % GRADIENTS.length];
  return `linear-gradient(135deg, ${a}, ${b})`;
}
