import type { ChordShape } from "@/lib/chord-shapes";

// SVG port of ChordDiagramPainter — same fixed grid geometry, so shapes look
// identical to the Flutter app's: a 5-fret grid, dots on pressed strings,
// O / X above open / muted strings, and an "Nfr" label when the shape is a
// movable one that doesn't start at the nut. String count comes from the
// shape, so 4-string ukulele diagrams are just narrower.

const LEFT = 22;
const TOP = 28;
const STRING_GAP = 18;
const FRET_GAP = 20;
const ROWS = 5;

export const diagramSize = (strings: number) => ({
  width: LEFT + (strings - 1) * STRING_GAP + 26,
  height: TOP + ROWS * FRET_GAP + 14,
});

export default function ChordDiagram({
  shape,
  mirrored = false,
  dotColor = "#2563eb",
  className,
  label,
}: {
  shape: ChordShape;
  /** Left-handed: string x-positions flip, text stays upright. */
  mirrored?: boolean;
  dotColor?: string;
  className?: string;
  label?: string;
}) {
  const n = shape.frets.length;
  const { width, height } = diagramSize(n);
  const gridWidth = (n - 1) * STRING_GAP;
  const open = shape.baseFret <= 1;
  const x = (s: number) => LEFT + (mirrored ? n - 1 - s : s) * STRING_GAP;

  return (
    <svg
      viewBox={`0 0 ${width} ${height}`}
      className={className}
      role="img"
      aria-label={label ?? "Chord diagram"}
      fontFamily="inherit"
    >
      <g stroke="currentColor" strokeOpacity={0.6} strokeWidth={1.2}>
        {Array.from({ length: n }, (_, s) => (
          <line key={`s${s}`} x1={x(s)} x2={x(s)} y1={TOP} y2={TOP + ROWS * FRET_GAP} />
        ))}
        {Array.from({ length: ROWS + 1 }, (_, f) => {
          const nut = f === 0 && open;
          return (
            <line
              key={`f${f}`}
              x1={LEFT}
              x2={LEFT + gridWidth}
              y1={TOP + f * FRET_GAP}
              y2={TOP + f * FRET_GAP}
              strokeWidth={nut ? 4 : 1.2}
              strokeOpacity={nut ? 0.85 : 0.6}
            />
          );
        })}
      </g>

      {!open && (
        <text x={LEFT + gridWidth + 6} y={TOP - 6} fontSize={11} fontWeight={700} fill="currentColor" dominantBaseline="central">
          {shape.baseFret}fr
        </text>
      )}

      {shape.frets.map((fret, s) => {
        if (fret === null || (open && fret === 0)) {
          return (
            <text
              key={s}
              x={x(s)}
              y={TOP - 16}
              fontSize={11}
              fontWeight={700}
              textAnchor="middle"
              dominantBaseline="central"
              fill="currentColor"
            >
              {fret === null ? "X" : "O"}
            </text>
          );
        }
        const row = open ? fret : fret - shape.baseFret + 1;
        if (row < 1 || row > ROWS) return null;
        return <circle key={s} cx={x(s)} cy={TOP + (row - 0.5) * FRET_GAP} r={6.5} fill={dotColor} />;
      })}
    </svg>
  );
}
