import 'dart:math';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pai_morn_web/data/chord_shapes.dart';
import 'package:pai_morn_web/data/ukulele_chord_shapes.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/theme/app_theme.dart';
import 'package:pai_morn_web/utils/artist_palette.dart';
import 'package:pai_morn_web/utils/chord_transposer.dart';
import 'package:pai_morn_web/utils/chord_sound.dart';
import 'package:pai_morn_web/utils/instrument_mode.dart';
import 'package:pai_morn_web/widget/chord_diagram_painter.dart';
import 'package:pai_morn_web/widget/fretboard_chart.dart';
import 'package:pai_morn_web/utils/recently_looked_up_chords.dart';
import 'package:pai_morn_web/widget/app_search_field.dart';
import 'package:pai_morn_web/widget/hover_scale.dart';

/// A browsable reference of every chord diagram the app knows how to draw
/// (see data/chord_shapes.dart) — the same fret-position diagrams shown
/// when tapping a chord inside a song, but laid out all at once like a
/// printed "chord poster" a beginner keeps by their music stand to look up
/// how to hold a shape they don't already know.
class ChordsScreen extends StatefulWidget {
  const ChordsScreen({super.key});

  @override
  State<ChordsScreen> createState() => _ChordsScreenState();
}

enum _ChordsPageMode { chords, fretboard, quiz }

class _ChordsScreenState extends State<ChordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  // Only meaningful below AppBreakpoints.tablet — the fixed 150px card width
  // used above that leaves a comfortable natural wrap (~6 per row at this
  // page's 1040 max width), but on a narrow phone a card that size only
  // ever fits one per row, wasting the other half of the screen. A user
  // reported exactly that. Letting them pick the column count (rather than
  // silently forcing 2) covers both very narrow phones and the wider ones
  // where 3 still fits comfortably.
  int _narrowColumns = 2;
  _ChordsPageMode _mode = _ChordsPageMode.chords;
  final ChordSound _chordSound = ChordSound();

  // "Recently Looked Up" — chords tapped from inside a song reader (see
  // chord_diagram_dialog.dart), surfaced here so a shape someone just had
  // to look up mid-song is right there next time instead of needing a
  // search. Fetched once per page load like the other device-local lists
  // on this page; re-navigating to /chords re-reads it fresh.
  List<String> _recentlyLookedUp = [];

  // A simple 4-choice "name this chord" quiz — shows one chord's diagram
  // with no label and 3 wrong names mixed in with the real one. Session-
  // only score (not persisted); a fresh question is generated on entering
  // Quiz mode and after every answer.
  final _quizRandom = Random();
  String? _quizAnswer;
  ChordShape? _quizShape;
  List<String> _quizChoices = [];
  String? _quizSelected;
  int _quizScore = 0;
  int _quizTotal = 0;

  // Chords a learner is actively practicing, pinned to the front of the
  // list so they don't have to scroll/search for the same handful of shapes
  // every time. Device-local only (SharedPreferences) — this is a personal
  // study aid, not something that needs to follow an account across
  // devices or be visible to anyone else.
  static const _pinnedChordsPrefsKey = 'pinned_chords';
  Set<String> _pinnedChords = {};

  // Applies to both the chord-diagram cards and the fretboard chart — one
  // "I'm left-handed" preference for the whole page rather than two
  // separate toggles, since it's the same physical fact about the player
  // either way.
  static const _leftHandedPrefsKey = 'chords_left_handed';
  bool _leftHanded = false;

  @override
  void initState() {
    super.initState();
    _loadPinnedChords();
    _loadLeftHanded();
    _loadRecentlyLookedUp();
    final isUkulele =
        Provider.of<InstrumentModeProvider>(context, listen: false).isUkulele;
    _startNewQuizQuestion(isUkulele ? ukuleleChordShapes : chordShapes);
  }

  Future<void> _loadRecentlyLookedUp() async {
    final names = await loadRecentlyLookedUpChords();
    if (!mounted) return;
    setState(() => _recentlyLookedUp = names);
  }

  void _startNewQuizQuestion(Map<String, ChordShape> shapes) {
    final allNames = shapes.keys.toList();
    final correct = allNames[_quizRandom.nextInt(allNames.length)];
    final distractors = <String>{};
    while (distractors.length < 3 && distractors.length < allNames.length - 1) {
      final candidate = allNames[_quizRandom.nextInt(allNames.length)];
      if (candidate != correct) distractors.add(candidate);
    }
    final choices = [correct, ...distractors]..shuffle(_quizRandom);
    setState(() {
      _quizAnswer = correct;
      _quizShape = shapes[correct];
      _quizChoices = choices;
      _quizSelected = null;
    });
  }

  void _selectQuizChoice(String choice) {
    if (_quizSelected != null) return; // already answered this question
    setState(() {
      _quizSelected = choice;
      _quizTotal++;
      if (choice == _quizAnswer) _quizScore++;
    });
  }

  Future<void> _loadPinnedChords() async {
    final prefs = await SharedPreferences.getInstance();
    final pinned = prefs.getStringList(_pinnedChordsPrefsKey) ?? [];
    if (!mounted) return;
    setState(() => _pinnedChords = pinned.toSet());
  }

  Future<void> _loadLeftHanded() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_leftHandedPrefsKey) ?? false;
    if (!mounted) return;
    setState(() => _leftHanded = value);
  }

  Future<void> _toggleLeftHanded() async {
    setState(() => _leftHanded = !_leftHanded);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_leftHandedPrefsKey, _leftHanded);
  }

  Future<void> _togglePin(String chordName) async {
    setState(() {
      if (_pinnedChords.contains(chordName)) {
        _pinnedChords = {..._pinnedChords}..remove(chordName);
      } else {
        _pinnedChords = {..._pinnedChords, chordName};
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_pinnedChordsPrefsKey, _pinnedChords.toList());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final language = context.watch<LocaleProvider>().currentLanguage;
    final isUkulele = context.watch<InstrumentModeProvider>().isUkulele;
    final activeShapes = isUkulele ? ukuleleChordShapes : chordShapes;
    final query = _query.trim().toLowerCase();
    // chordShapes iterates root-by-root (C, C#, D, ...), and within each
    // root every quality in a fixed order (major, m, 7, maj7, m7, sus2,
    // sus4, dim) — see data/chord_shapes.dart — so this listing already
    // reads like a real chord poster with no extra sorting needed. Pinned
    // chords are then partitioned to the front (not a comparator-based
    // sort, which would risk relying on Dart's sort stability) — each
    // group keeps that same original relative order.
    final matchingEntries =
        activeShapes.entries
            .where((e) => query.isEmpty || e.key.toLowerCase().contains(query))
            .toList();
    final entries = [
      ...matchingEntries.where((e) => _pinnedChords.contains(e.key)),
      ...matchingEntries.where((e) => !_pinnedChords.contains(e.key)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [artistPalette[0], artistPalette[3]],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppTranslations.getText('chordsLabel', language),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  _modeToggle(scheme, language, isUkulele),
                  _instrumentToggle(scheme, isUkulele),
                  _leftHandedToggle(scheme),
                ],
              ),
              const SizedBox(height: 20),
              if (_mode == _ChordsPageMode.fretboard && !isUkulele)
                Center(child: FretboardChart(mirrored: _leftHanded))
              else if (_mode == _ChordsPageMode.quiz)
                _buildQuizView(scheme, language, activeShapes)
              else ...[
                if (_recentlyLookedUp.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTranslations.getText(
                            'recentlyLookedUpChordsLabel',
                            language,
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final name in _recentlyLookedUp)
                              if (activeShapes[name] != null)
                                _chordCard(
                                  scheme,
                                  name,
                                  activeShapes[name]!,
                                  110,
                                  isUkulele: isUkulele,
                                ),
                          ],
                        ),
                      ],
                    ),
                  ),
                AppSearchField(
                  controller: _searchController,
                  hintText: AppTranslations.getText(
                    'searchChordsHint',
                    language,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                  maxWidth: 360,
                ),
                const SizedBox(height: 24),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      AppTranslations.getText('noChordsFound', language),
                      style: TextStyle(
                        color: scheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow =
                          constraints.maxWidth < AppBreakpoints.tablet;
                      if (!isNarrow) {
                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            for (final entry in entries)
                              _chordCard(
                                scheme,
                                entry.key,
                                entry.value,
                                150,
                                isUkulele: isUkulele,
                              ),
                          ],
                        );
                      }
                      const spacing = 12.0;
                      final cardWidth =
                          (constraints.maxWidth -
                              spacing * (_narrowColumns - 1)) /
                          _narrowColumns;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _columnsPicker(scheme),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: [
                              for (final entry in entries)
                                _chordCard(
                                  scheme,
                                  entry.key,
                                  entry.value,
                                  cardWidth,
                                  isUkulele: isUkulele,
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chordCard(
    ColorScheme scheme,
    String name,
    ChordShape shape,
    double width, {
    required bool isUkulele,
  }) {
    // Colored by root note (via the same hash-based palette the rest of the
    // site uses for artists/bands) so every voicing of, say, every "A"
    // chord shares one color at a glance — a poster you can scan by root
    // the way a real wall chart groups chords, without a second palette.
    final root = parseChordRoot(name) ?? name;
    final color = colorForArtist(root);
    // ChordDiagramPainter always draws at its own fixed pixel size (it
    // doesn't scale with the CustomPaint's canvas size) — FittedBox is what
    // actually lets the diagram shrink or grow to fit whatever card width
    // the column-count picker below computes, while keeping its aspect
    // ratio and the painter itself untouched.
    final preferredSize = ChordDiagramPainter.preferredSizeFor(shape.frets.length);
    final diagramWidth = width - 20;
    final diagramHeight =
        diagramWidth * preferredSize.height / preferredSize.width;
    final isPinned = _pinnedChords.contains(name);
    return HoverScale(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap:
                () => _chordSound.strum(
                  shape,
                  openStringHz:
                      isUkulele
                          ? ChordSound.ukuleleOpenStringHz
                          : ChordSound.guitarOpenStringHz,
                ),
            child: Container(
              width: width,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.onSurface.withOpacity(0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Hints the card is now tappable (plays a synthesized strum
                      // — see utils/chord_sound.dart) — nothing about a plain
                      // chord-diagram card otherwise suggested it did anything on
                      // tap.
                      FaIcon(
                        FontAwesomeIcons.volumeHigh,
                        size: 16,
                        color: scheme.onSurface.withOpacity(0.4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: diagramWidth,
                    height: diagramHeight,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: preferredSize.width,
                        height: preferredSize.height,
                        child: CustomPaint(
                          painter: ChordDiagramPainter(
                            shape: shape,
                            lineColor: scheme.onSurface.withOpacity(0.6),
                            dotColor: color,
                            textColor: scheme.onSurface,
                            mirrored: _leftHanded,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => _togglePin(name),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: FaIcon(
                  isPinned ? FontAwesomeIcons.solidStar : FontAwesomeIcons.star,
                  size: 20,
                  color:
                      isPinned
                          ? Colors.amber
                          : scheme.onSurface.withOpacity(0.25),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // One tap cycles 2 → 3 → 4 → back to 2, rather than a row of separate
  // number pills — a user asked for exactly this, comparing it to a
  // desktop file browser's single "view" toggle. The icon itself changes
  // with the count (fewer/bigger squares → more/smaller ones) so the
  // current density is visible without reading the number.
  static const List<IconData> _columnsIcons = [
    FontAwesomeIcons.tableList,
    FontAwesomeIcons.tableCellsLarge,
    FontAwesomeIcons.grip,
  ];

  Widget _columnsPicker(ColorScheme scheme) {
    final icon = _columnsIcons[_narrowColumns - 2];
    return InkWell(
      onTap: () {
        setState(() {
          _narrowColumns = _narrowColumns >= 4 ? 2 : _narrowColumns + 1;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Tooltip(
        message: '$_narrowColumns per row — tap to change',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.onSurface.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: scheme.onSurface),
              const SizedBox(width: 8),
              Text(
                '$_narrowColumns',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Switches this page between the existing chord-diagram poster and the
  // fretboard note-map (FretboardChart) — both are "look something up"
  // reference tools for the same instrument, so they share this one page
  // and its header rather than needing a separate route.
  Widget _modeToggle(ColorScheme scheme, String language, bool isUkulele) {
    Widget segment(String label, bool selected, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? scheme.onSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? scheme.surface : scheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.onSurface.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment(
            AppTranslations.getText('chordsLabel', language),
            _mode == _ChordsPageMode.chords,
            () => setState(() => _mode = _ChordsPageMode.chords),
          ),
          // The fretboard note-map is a 6-string guitar neck with no
          // ukulele equivalent built yet — hidden rather than shown
          // incorrectly while a ukulele shape is selected everywhere else
          // on this page.
          if (!isUkulele)
            segment(
              AppTranslations.getText('fretboardLabel', language),
              _mode == _ChordsPageMode.fretboard,
              () => setState(() => _mode = _ChordsPageMode.fretboard),
            ),
          segment(
            AppTranslations.getText('quizLabel', language),
            _mode == _ChordsPageMode.quiz,
            () {
              // Entering Quiz mode always regenerates the question against
              // whichever instrument is active — without this, switching
              // instrument while NOT already in Quiz mode left a stale
              // question/choices from the other dictionary's shapes on
              // screen the next time Quiz was opened (only the "toggle
              // instrument while already in Quiz" path refreshed it).
              _startNewQuizQuestion(isUkulele ? ukuleleChordShapes : chordShapes);
              setState(() => _mode = _ChordsPageMode.quiz);
            },
          ),
        ],
      ),
    );
  }

  // A random chord's diagram with no name shown, 4 multiple-choice names
  // (1 correct + 3 distractors) — turns the reference page into a quick
  // self-test instead of only a lookup tool. Session-only score, resets on
  // page reload; a new question generates automatically after every answer
  // shows its feedback color for a moment via the Next button below.
  Widget _buildQuizView(
    ColorScheme scheme,
    String language,
    Map<String, ChordShape> activeShapes,
  ) {
    final shape = _quizShape;
    if (shape == null) return const SizedBox.shrink();
    final preferredSize = ChordDiagramPainter.preferredSizeFor(shape.frets.length);
    final diagramWidth = 200.0;
    final diagramHeight =
        diagramWidth * preferredSize.height / preferredSize.width;

    Color? choiceColor(String choice) {
      if (_quizSelected == null) return null;
      if (choice == _quizAnswer) return Colors.green;
      if (choice == _quizSelected) return Colors.redAccent;
      return null;
    }

    return Center(
      child: Column(
        children: [
          Text(
            '${AppTranslations.getText('quizScoreLabel', language)}: $_quizScore / $_quizTotal',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: scheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.onSurface.withOpacity(0.08)),
            ),
            child: SizedBox(
              width: diagramWidth,
              height: diagramHeight,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: preferredSize.width,
                  height: preferredSize.height,
                  child: CustomPaint(
                    painter: ChordDiagramPainter(
                      shape: shape,
                      lineColor: scheme.onSurface.withOpacity(0.6),
                      dotColor: scheme.onSurface,
                      textColor: scheme.onSurface,
                      mirrored: _leftHanded,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final choice in _quizChoices)
                OutlinedButton(
                  onPressed: () => _selectQuizChoice(choice),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: choiceColor(choice),
                    foregroundColor:
                        choiceColor(choice) != null
                            ? Colors.white
                            : scheme.onSurface,
                    side: BorderSide(color: scheme.onSurface.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    choice,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          if (_quizSelected != null) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _startNewQuizQuestion(activeShapes),
              child: Text(AppTranslations.getText('quizNextLabel', language)),
            ),
          ],
        ],
      ),
    );
  }

  // A real accessibility feature, not decoration — mirrors both the
  // chord-diagram cards and the fretboard chart for a left-handed player,
  // see ChordDiagramPainter.mirrored / FretboardChart.mirrored.
  Widget _leftHandedToggle(ColorScheme scheme) {
    return Tooltip(
      message: 'Left-handed',
      child: InkWell(
        onTap: _toggleLeftHanded,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _leftHanded ? scheme.onSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.onSurface.withOpacity(0.2)),
          ),
          child: FaIcon(
            FontAwesomeIcons.hand,
            size: 18,
            color: _leftHanded ? scheme.surface : scheme.onSurface,
          ),
        ),
      ),
    );
  }

  // Guitar/Ukulele — the one global instrument preference (see
  // utils/instrument_mode.dart) that decides which chord dictionary this
  // whole page (and the tap-a-chord popup, and the song reader's faint
  // chord background) draws from. Switching away from ukulele while the
  // Fretboard sub-mode is guitar-only doesn't need special handling (that
  // segment is simply hidden in ukulele mode, see _modeToggle); switching
  // mid-quiz regenerates the question so the diagram on screen actually
  // matches the newly-selected instrument's shape data instead of showing
  // a stale one drawn from the other dictionary.
  Widget _instrumentToggle(ColorScheme scheme, bool isUkulele) {
    Widget segment(String label, bool selected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? scheme.onSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? scheme.surface : scheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return InkWell(
      onTap: () async {
        final provider = Provider.of<InstrumentModeProvider>(
          context,
          listen: false,
        );
        await provider.toggle();
        if (!mounted) return;
        if (provider.isUkulele && _mode == _ChordsPageMode.fretboard) {
          setState(() => _mode = _ChordsPageMode.chords);
        }
        if (_mode == _ChordsPageMode.quiz) {
          _startNewQuizQuestion(
            provider.isUkulele ? ukuleleChordShapes : chordShapes,
          );
        }
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: scheme.onSurface.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            segment('Guitar', !isUkulele),
            segment('Uke', isUkulele),
          ],
        ),
      ),
    );
  }
}
