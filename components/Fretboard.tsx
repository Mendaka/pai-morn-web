"use client";

import { useT } from "@/components/LanguageProvider";
import { useLeftHanded } from "@/lib/stored";

// Full-neck note map (port of fretboard_chart.dart): nut on the left, frets
// receding right, high E on top and low E on the bottom like tab notation.
// Every fret of every string shows its note, sharps and flats both spelled
// since this is a neutral reference, not tied to one key.

const NOTES: [string, string?][] = [
  ["C"],
  ["C♯", "D♭"],
  ["D"],
  ["D♯", "E♭"],
  ["E"],
  ["F"],
  ["F♯", "G♭"],
  ["G"],
  ["G♯", "A♭"],
  ["A"],
  ["A♯", "B♭"],
  ["B"],
];
// Standard tuning, high string -> low string.
const TUNING = [
  { label: "E", pitch: 4 },
  { label: "B", pitch: 11 },
  { label: "G", pitch: 7 },
  { label: "D", pitch: 2 },
  { label: "A", pitch: 9 },
  { label: "E", pitch: 4 },
];

const FRETS = 12;
const STRING_GAP = 42;
const CELL = 58;
const NUT = 12;
const LABEL_COL = 48;
const NOTE_R = 16;
const NUMBER_ROW = 28;
const BOARD_W = NUT + FRETS * CELL;
const BOARD_H = STRING_GAP * 6;
const SINGLE_INLAYS = [3, 5, 7, 9];

const noteColor = (pitch: number) => `hsl(${pitch * 30} 62% 44%)`;

export default function Fretboard() {
  const { t } = useT();
  const { leftHanded } = useLeftHanded();
  // Left-handed: strings swap rows (low E on top); frets still run left to right.
  const strings = leftHanded ? [...TUNING].reverse() : TUNING;

  return (
    <div className="overflow-x-auto rounded-3xl text-neutral-800 border border-black/5 bg-white p-4 shadow-[0_2px_24px_-8px_rgba(0,0,0,0.15)]">
      <svg
        viewBox={`0 0 ${LABEL_COL + BOARD_W} ${BOARD_H + NUMBER_ROW}`}
        width={LABEL_COL + BOARD_W}
        height={BOARD_H + NUMBER_ROW}
        role="img"
        aria-label={t("fretboardLabel")}
        className="mx-auto block max-w-none"
        fontFamily="inherit"
      >
        <defs>
          <linearGradient id="fb-wood" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#a06b3a" />
            <stop offset="0.25" stopColor="#8b5a2b" />
            <stop offset="0.5" stopColor="#6e4423" />
            <stop offset="0.75" stopColor="#8b5a2b" />
            <stop offset="1" stopColor="#a06b3a" />
          </linearGradient>
          <linearGradient id="fb-nut" x1="0" y1="0" x2="1" y2="0">
            <stop offset="0" stopColor="#f5f0e6" />
            <stop offset="1" stopColor="#d8cfbb" />
          </linearGradient>
          <linearGradient id="fb-string" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#ededed" />
            <stop offset="0.5" stopColor="#9a9a9a" />
            <stop offset="1" stopColor="#ededed" />
          </linearGradient>
        </defs>

        {/* open-string badges */}
        {strings.map((s, i) => (
          <g key={`open${i}`}>
            <circle cx={LABEL_COL / 2} cy={i * STRING_GAP + STRING_GAP / 2} r={NOTE_R + 2} fill="none" stroke="currentColor" strokeWidth={2} />
            <text x={LABEL_COL / 2} y={i * STRING_GAP + STRING_GAP / 2} textAnchor="middle" dominantBaseline="central" fontSize={15} fontWeight={700} fill="currentColor">
              {s.label}
            </text>
          </g>
        ))}

        <g transform={`translate(${LABEL_COL} 0)`}>
          <rect width={BOARD_W} height={BOARD_H} rx={4} fill="url(#fb-wood)" />
          {[0.12, 0.28, 0.5, 0.63, 0.82, 0.93].map((f) => (
            <line key={f} x1={0} x2={BOARD_W} y1={BOARD_H * f} y2={BOARD_H * f} stroke="#000" strokeOpacity={0.06} strokeWidth={1.2} />
          ))}

          {/* position inlays: single dots at 3/5/7/9, a pair at the octave */}
          {SINGLE_INLAYS.map((f) => (
            <Inlay key={f} cx={NUT + (f - 0.5) * CELL} cy={STRING_GAP * 3} />
          ))}
          <Inlay cx={NUT + (12 - 0.5) * CELL} cy={STRING_GAP * 2} />
          <Inlay cx={NUT + (12 - 0.5) * CELL} cy={STRING_GAP * 4} />

          <rect width={NUT} height={BOARD_H} fill="url(#fb-nut)" />
          {Array.from({ length: FRETS }, (_, i) => {
            const x = NUT + (i + 1) * CELL;
            return (
              <g key={`fret${i}`}>
                <line x1={x} x2={x} y1={0} y2={BOARD_H} stroke="#000" strokeOpacity={0.35} strokeWidth={2.5} />
                <line x1={x - 1} x2={x - 1} y1={0} y2={BOARD_H} stroke="#fff" strokeOpacity={0.55} strokeWidth={1} />
              </g>
            );
          })}

          {strings.map((_, i) => {
            // Thicker toward the low-E row (which is the top row when mirrored).
            const w = 1.2 + (leftHanded ? 5 - i : i) * 0.55;
            const y = i * STRING_GAP + STRING_GAP / 2;
            return <rect key={`str${i}`} x={0} y={y - w / 2} width={BOARD_W} height={w} fill="url(#fb-string)" />;
          })}

          {strings.map((s, i) =>
            Array.from({ length: FRETS }, (_, f) => {
              const [primary, alt] = NOTES[(s.pitch + f + 1) % 12];
              const cx = NUT + f * CELL + CELL / 2;
              const cy = i * STRING_GAP + STRING_GAP / 2;
              const pitch = (s.pitch + f + 1) % 12;
              return (
                <g key={`n${i}-${f}`}>
                  <circle cx={cx} cy={cy} r={NOTE_R} fill={noteColor(pitch)} stroke="#000" strokeOpacity={0.25} strokeWidth={0.5} />
                  <circle cx={cx - 5} cy={cy - 6} r={NOTE_R * 0.55} fill="#fff" fillOpacity={0.18} />
                  {alt ? (
                    <text x={cx} textAnchor="middle" fontSize={9} fontWeight={700} fill="#fff">
                      <tspan x={cx} y={cy - 2}>{primary}</tspan>
                      <tspan x={cx} y={cy + 8} fillOpacity={0.75}>{alt}</tspan>
                    </text>
                  ) : (
                    <text x={cx} y={cy} textAnchor="middle" dominantBaseline="central" fontSize={14} fontWeight={700} fill="#fff">
                      {primary}
                    </text>
                  )}
                </g>
              );
            }),
          )}
        </g>

        {Array.from({ length: FRETS }, (_, i) => (
          <text
            key={`num${i}`}
            x={LABEL_COL + NUT + i * CELL + CELL / 2}
            y={BOARD_H + NUMBER_ROW / 2 + 2}
            textAnchor="middle"
            dominantBaseline="central"
            fontSize={14}
            fontWeight={700}
            fill="currentColor"
          >
            {i + 1}
          </text>
        ))}
      </svg>
    </div>
  );
}

function Inlay({ cx, cy }: { cx: number; cy: number }) {
  return (
    <>
      <circle cx={cx} cy={cy + 1} r={6} fill="#000" fillOpacity={0.15} />
      <circle cx={cx} cy={cy} r={6} fill="#fff" fillOpacity={0.85} />
    </>
  );
}
