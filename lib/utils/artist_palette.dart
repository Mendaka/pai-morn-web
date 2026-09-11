import 'package:flutter/material.dart';

// Shared by the Home page (artist preview cards), SongBook (artist/band
// cover cards and song row accents), and the song reader (control panel and
// header accent) — using the same palette + hash everywhere is what makes
// "this artist's color" read as one consistent identity across the whole
// app instead of three screens independently inventing a color for the same
// person.
const List<Color> artistPalette = [
  Color(0xFF6C5CE7),
  Color(0xFF00B894),
  Color(0xFFE17055),
  Color(0xFF0984E3),
  Color(0xFFD63031),
  Color(0xFFE84393),
  Color(0xFF00CEC9),
  Color(0xFFFDA7DF),
];

// Deterministic per-name color (same name always hashes to the same palette
// entry) so an artist/band never needs a stored color of their own.
Color colorForArtist(String name) {
  if (name.isEmpty) return artistPalette.first;
  final hash = name.codeUnits.fold<int>(0, (acc, c) => acc + c);
  return artistPalette[hash % artistPalette.length];
}
