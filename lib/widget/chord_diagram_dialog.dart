import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pai_morn_web/data/chord_shapes.dart';
import 'package:pai_morn_web/data/ukulele_chord_shapes.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/utils/instrument_mode.dart';
import 'package:pai_morn_web/utils/recently_looked_up_chords.dart';
import 'package:pai_morn_web/widget/chord_diagram_painter.dart';

/// Shows a small popup with the fret-position diagram for [chordName], or a
/// "not found" message if it isn't in the common-chord dictionary. Draws
/// from whichever instrument (guitar/ukulele) is currently selected via
/// InstrumentModeProvider — same shared preference the Chords reference
/// page and the song reader's chord background respect.
void showChordDiagramDialog(BuildContext context, String chordName) {
  final isUkulele =
      Provider.of<InstrumentModeProvider>(context, listen: false).isUkulele;
  final shape =
      isUkulele
          ? lookupUkuleleChordShape(chordName)
          : lookupChordShape(chordName);
  final language =
      Provider.of<LocaleProvider>(context, listen: false).currentLanguage;
  final scheme = Theme.of(context).colorScheme;

  // Only a chord this dictionary actually recognized is worth resurfacing
  // later on the Chords page's "Recently Looked Up" row — recording the
  // canonical name (not necessarily how the song itself spelled it) so it
  // re-resolves to the same dictionary entry there.
  final canonicalName = canonicalChordName(chordName);
  if (canonicalName != null) {
    recordLookedUpChord(canonicalName);
  }

  showDialog(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                chordName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              if (shape != null)
                SizedBox(
                  width:
                      ChordDiagramPainter.preferredSizeFor(
                        shape.frets.length,
                      ).width,
                  height:
                      ChordDiagramPainter.preferredSizeFor(
                        shape.frets.length,
                      ).height,
                  child: CustomPaint(
                    painter: ChordDiagramPainter(
                      shape: shape,
                      lineColor: scheme.onSurface.withOpacity(0.6),
                      dotColor: Colors.blueAccent,
                      textColor: scheme.onSurface,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    AppTranslations.getText('chordNotFound', language),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurface.withOpacity(0.8)),
                  ),
                ),
              const SizedBox(height: 16),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: scheme.onSurface),
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
