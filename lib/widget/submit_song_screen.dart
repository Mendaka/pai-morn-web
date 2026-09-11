import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:pai_morn_web/auth/auth_provider.dart';
import 'package:pai_morn_web/data/diatonic_chords.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/utils/category_labels.dart';
import 'package:pai_morn_web/utils/gender_labels.dart';
import 'package:pai_morn_web/utils/lyrics_parser.dart';
import 'package:pai_morn_web/widget/lyric_line_view.dart';
import 'package:pai_morn_web/theme/app_theme.dart';

const List<String> _sectionLabels = [
  'Key',
  'Intro',
  'Verse',
  'Chorus',
  'Bridge',
  'Solo',
  'Outro',
];

// One existing song, for the Song Name typeahead — shown with its artist
// alongside so a submitter can tell "this exact song already exists" (same
// name, same artist — likely a real duplicate) apart from "this name is
// just reused by a different artist" (not a duplicate at all).
class _SongOption {
  const _SongOption(this.songName, this.songNameLower, this.artistDisplay);
  final String songName;
  final String songNameLower;
  final String artistDisplay;
}

class _SubmitFormOptions {
  const _SubmitFormOptions({
    required this.categories,
    required this.genders,
    required this.bands,
    required this.songs,
  });
  final Set<String> categories;
  final Set<String> genders;
  final Set<String> bands;
  final List<_SongOption> songs;
}

// Pins the Key/chord-chip panel to the top of the form while scrolling, so
// it stays reachable while composing a long song instead of scrolling out
// of view (same pattern as song_reader_screen.dart's auto-scroll bar).
// `height` is a breakpoint estimate rather than a measured value — see the
// call site for why.
class _StickyPanelDelegate extends SliverPersistentHeaderDelegate {
  const _StickyPanelDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _StickyPanelDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}

// One row of the Artist typeahead — a song can credit several artists (a
// duet, a group), so the form holds a list of these instead of one fixed
// set of fields. Each entry manages its own suggestion search/selection
// completely independently of the others.
class _ArtistEntry {
  final controller = TextEditingController();
  String? selectedArtistId;
  List<QueryDocumentSnapshot> matches = [];
  bool showSuggestions = false;
  Timer? debounce;

  void dispose() {
    debounce?.cancel();
    controller.dispose();
  }
}

class SubmitSongScreen extends StatefulWidget {
  const SubmitSongScreen({
    super.key,
    this.editingSongId,
    this.editingSongData,
    this.isResubmission = false,
    this.isDraftContinuation = false,
  });

  /// When both are set, the form opens pre-filled with an existing song's
  /// data. Normally the submit action is admin's "release" (save + set
  /// status: approved) instead of a brand-new pending submission — see
  /// _submit — reached only from admin-only entry points (the pending-
  /// review dialog, or the "Edit" button on a song row while Edit Mode is
  /// on). Two cases let a normal user reach this mode too:
  /// [isResubmission]: the original author fixing up their own *rejected*
  /// song from My Songs to send it back for review — submit becomes
  /// "resubmit" (save + back to pending) instead of "release".
  /// [isDraftContinuation]: the author picking up a *draft* they saved
  /// earlier — "Save Draft" keeps re-saving the same doc as status: draft,
  /// and "Submit" promotes it to pending for the first time (going through
  /// the same artist-resolution/duplicate-check a brand-new submission
  /// does, since a draft's artist was never validated). Both are gated
  /// server-side in firestore.rules (author-owned, specific status
  /// transitions only).
  final String? editingSongId;
  final Map<String, dynamic>? editingSongData;
  final bool isResubmission;
  final bool isDraftContinuation;

  bool get isEditing => editingSongId != null;

  @override
  State<SubmitSongScreen> createState() => _SubmitSongScreenState();
}

class _SubmitSongScreenState extends State<SubmitSongScreen> {
  final _songwriterController = TextEditingController();
  final _bandController = TextEditingController();
  final _songNameController = TextEditingController();
  final _youtubeLinkController = TextEditingController();
  final _otherCategoryController = TextEditingController();
  final _otherGenderController = TextEditingController();
  final _lyricsController = TextEditingController();
  final _lyricsFocusNode = FocusNode();
  // Shared by the wide-layout CustomScrollView and (for consistency) the
  // narrow single-scroll fallback — lets _insertAtCursor restore the scroll
  // offset after a chip tap (see the comment there for why that's needed).
  final _bodyScrollController = ScrollController();

  // One song can credit several artists (a duet, a group) — each gets its
  // own typeahead field/suggestions/resolved-id, all independent of each
  // other. Always at least one entry; "+ Add artist" appends more, the "x"
  // on a row removes it (never below one).
  final List<_ArtistEntry> _artistEntries = [_ArtistEntry()];

  String _selectedRoot = 'C';
  bool _isMinorKey = false;

  String? _selectedCategory;
  String? _selectedGender;
  bool _categoryIsOther = false;
  bool _genderIsOther = false;

  bool _isSubmitting = false;
  String? _errorMessage;

  // Set once a draft exists as a real doc — either because we opened an
  // existing one (isDraftContinuation) or because "Save Draft" just created
  // one for the first time — so every later "Save Draft" tap updates that
  // same doc instead of creating a new one each time.
  String? _draftDocId;
  bool _draftSaving = false;

  @override
  void initState() {
    super.initState();
    _lyricsController.addListener(() => setState(() {}));
    if (widget.isDraftContinuation) _draftDocId = widget.editingSongId;
    final data = widget.editingSongData;
    if (data != null) {
      // New shape: parallel artistNames/artistIds arrays (one song, several
      // credited artists). Falls back to the old single artist/artistId
      // fields for any doc the one-time migration hasn't touched yet — see
      // gender_labels.dart's normalize* functions for the same kind of
      // defensive fallback applied to a different pre-migration field.
      final artistNamesData = (data['artistNames'] as List?)?.cast<String>();
      final artistIdsData = (data['artistIds'] as List?)?.cast<String>();
      if (artistNamesData != null && artistNamesData.isNotEmpty) {
        _artistEntries.clear();
        for (var i = 0; i < artistNamesData.length; i++) {
          final entry = _ArtistEntry()..controller.text = artistNamesData[i];
          final id =
              (artistIdsData != null && i < artistIdsData.length)
                  ? artistIdsData[i]
                  : null;
          // Blank ('', not null) means the artist was never actually
          // resolved — notably, a draft saved before an artist was picked/
          // created stores exactly this (see _saveDraft). Treating '' as
          // "already resolved" here previously made _resolveArtistIdFor's
          // `!= null` check skip re-resolving it entirely, silently
          // publishing a song with no artistId and therefore no artist card
          // in the SongBook grid at all.
          entry.selectedArtistId = (id != null && id.isNotEmpty) ? id : null;
          _artistEntries.add(entry);
        }
      } else {
        final entry = _artistEntries.first;
        entry.controller.text = (data['artist'] ?? '').toString();
        final storedArtistId = data['artistId'] as String?;
        entry.selectedArtistId =
            (storedArtistId != null && storedArtistId.isNotEmpty)
                ? storedArtistId
                : null;
      }
      _songwriterController.text = (data['songwriter'] ?? '').toString();
      _bandController.text = (data['band'] ?? '').toString();
      _songNameController.text = (data['songName'] ?? '').toString();
      _youtubeLinkController.text = (data['youtubeLink'] ?? '').toString();
      // Always seeded as "other" rather than trying to match a dropdown
      // item — the dynamic category/gender option lists are scanned live
      // from all songs and may not even contain this value at the moment
      // the form loads, and DropdownButtonFormField throws if initialValue
      // isn't among its items. "Other" pre-filled with the real value is
      // always safe and shows the same text either way.
      _categoryIsOther = true;
      _otherCategoryController.text = (data['category'] ?? '').toString();
      _genderIsOther = true;
      _otherGenderController.text = (data['gender'] ?? '').toString();
      _lyricsController.text = lyricsBlockToText(
        (data['lyrics'] as List?) ?? [],
      );
      // Pre-fill the key picker from the existing song, not the '(C',
      // major)' default — otherwise saving an edit to an unrelated field
      // would silently overwrite a real song's key with the picker's
      // untouched default value.
      final existingKey = data['key'] as String?;
      if (existingKey != null && existingKey.isNotEmpty) {
        _selectedRoot = existingKey;
      }
      _isMinorKey = data['keyIsMinor'] as bool? ?? false;
    }
  }

  @override
  void dispose() {
    for (final entry in _artistEntries) {
      entry.dispose();
    }
    _songwriterController.dispose();
    _bandController.dispose();
    _songNameController.dispose();
    _youtubeLinkController.dispose();
    _otherCategoryController.dispose();
    _otherGenderController.dispose();
    _lyricsController.dispose();
    _lyricsFocusNode.dispose();
    _bodyScrollController.dispose();
    super.dispose();
  }

  // ---- artist typeahead ----------------------------------------------

  void _onArtistTextChanged(_ArtistEntry entry, String text) {
    entry.selectedArtistId = null;
    entry.debounce?.cancel();
    final query = text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        entry.matches = [];
        entry.showSuggestions = false;
      });
      return;
    }
    entry.debounce = Timer(const Duration(milliseconds: 300), () async {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('artists')
              .where('nameLower', isGreaterThanOrEqualTo: query)
              .where('nameLower', isLessThan: '$query')
              .limit(8)
              .get();
      if (!mounted) return;
      setState(() {
        entry.matches = snapshot.docs;
        entry.showSuggestions = true;
      });
    });
  }

  void _selectArtistSuggestion(_ArtistEntry entry, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      entry.controller.text = data['name'] ?? '';
      entry.selectedArtistId = doc.id;
      entry.showSuggestions = false;
    });
  }

  // One artist row: the typeahead field, its own suggestions dropdown, and
  // (for every row past the first) a remove button — removing never drops
  // below one entry, since Artist is a required field.
  Widget _buildArtistEntryRow(
    _ArtistEntry entry,
    int index,
    ColorScheme scheme,
    String language,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: entry.controller,
                onChanged: (v) => _onArtistTextChanged(entry, v),
                decoration: InputDecoration(
                  labelText: AppTranslations.getText('artistLabel', language),
                ),
              ),
              if (entry.showSuggestions && entry.matches.isNotEmpty)
                _suggestionsBox(
                  scheme,
                  entry.matches.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      dense: true,
                      title: Text(data['name'] ?? ''),
                      onTap: () => _selectArtistSuggestion(entry, doc),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        if (_artistEntries.length > 1)
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
            tooltip: 'Remove',
            onPressed:
                () => setState(() {
                  entry.dispose();
                  _artistEntries.removeAt(index);
                }),
          ),
      ],
    );
  }

  // Resolves one artist entry's typed name to an artistId, creating a new
  // artists/{id} doc if needed. If the user typed a name that exactly
  // matches an existing artist without picking it from the suggestion list,
  // asks whether to reuse it or deliberately create a distinct new artist
  // with the same name — returns null if the user cancels the whole submit.
  Future<String?> _resolveArtistIdFor(_ArtistEntry entry, String language) async {
    // isNotEmpty, not just != null — an empty string is "not resolved
    // yet" same as null (see the initState comment on _artistEntries for
    // exactly how a blank-but-non-null value could otherwise sneak in here
    // and skip resolution entirely).
    if (entry.selectedArtistId != null && entry.selectedArtistId!.isNotEmpty) {
      return entry.selectedArtistId;
    }

    final name = entry.controller.text.trim();
    final nameLower = name.toLowerCase();
    final existing =
        await FirebaseFirestore.instance
            .collection('artists')
            .where('nameLower', isEqualTo: nameLower)
            .limit(1)
            .get();

    if (existing.docs.isNotEmpty) {
      if (!mounted) return null;
      final useExisting = await _confirmUseExistingArtist(name, language);
      if (useExisting == null) return null;
      if (useExisting) return existing.docs.first.id;
    }

    if (!mounted) return null;
    final auth = context.read<AuthProvider>();
    final ref = FirebaseFirestore.instance.collection('artists').doc();
    await ref.set({
      'name': name,
      'nameLower': nameLower,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': auth.user?.uid,
    });
    return ref.id;
  }

  // Resolves every non-blank artist entry in order — sequential, not
  // parallel, so the "this artist may already exist?" dialog above only
  // ever shows one at a time instead of stacking. Returns null (aborting
  // the whole submit) if the user cancels any single one of them, same as
  // the one-artist behavior before this.
  Future<List<String>?> _resolveArtistIds(String language) async {
    final ids = <String>[];
    for (final entry in _activeArtistEntries) {
      final id = await _resolveArtistIdFor(entry, language);
      if (id == null) return null;
      ids.add(id);
    }
    return ids;
  }

  // Entries with something actually typed in them — an artist row added via
  // "+ Add artist" and then left blank is silently dropped rather than
  // treated as an error, since adding the row doesn't commit to using it.
  List<_ArtistEntry> get _activeArtistEntries => _artistEntries
      .where((e) => e.controller.text.trim().isNotEmpty)
      .toList();

  List<String> get _activeArtistNames =>
      _activeArtistEntries.map((e) => e.controller.text.trim()).toList();

  Future<bool?> _confirmUseExistingArtist(String artistName, String language) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppTranslations.getText('artistExistsTitle', language)),
          content: Text(
            '"$artistName" ${AppTranslations.getText('artistExistsMessage', language)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(AppTranslations.getText('createNewAnyway', language)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                AppTranslations.getText('useExistingArtist', language),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---- lyrics editor insert helpers -----------------------------------

  void _insertAtCursor(String text) {
    final oldText = _lyricsController.text;
    final selection = _lyricsController.selection;
    var start = selection.start;
    var end = selection.end;
    if (start < 0 || end < 0) {
      start = oldText.length;
      end = oldText.length;
    }
    final newText = oldText.replaceRange(start, end, text);
    final newOffset = start + text.length;
    final preservedScrollOffset =
        _bodyScrollController.hasClients ? _bodyScrollController.offset : null;

    // Re-focusing the field synchronously here doesn't reliably reconnect
    // Flutter web's underlying platform text-input channel after focus was
    // just on a chip/button instead — subsequent real keystrokes can get
    // silently dropped. Requesting focus *and* setting the value on the
    // next frame (after the chip's own tap-handling settles) fixes it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lyricsFocusNode.requestFocus();
      _lyricsController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newOffset),
      );

      // Moving focus/cursor into the lyrics field makes Flutter try to
      // scroll it into view on its own — with the Key panel pinned as a
      // sliver header (wide layout), that "into view" calculation gets
      // confused by the pinned header's reserved space and yanks the
      // whole page back to the top, undoing the entire point of pinning
      // the panel (staying put while inserting into a long lyrics block).
      // Restoring the pre-tap offset shortly after overrides that jump —
      // a short real delay rather than another post-frame callback, since
      // Flutter's own auto-scroll may itself be an animation spanning
      // several frames.
      if (preservedScrollOffset != null) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (_bodyScrollController.hasClients) {
            _bodyScrollController.jumpTo(preservedScrollOffset);
          }
        });
      }
    });
  }

  void _insertChord(String chordName) => _insertAtCursor('[$chordName]');

  void _insertLabel(String label) => _insertAtCursor('$label ');

  // Flutter web's built-in text-selection toolbar (the little floating
  // Copy/Paste bubble) is unreliable in a long, auto-growing multi-line
  // field like this one — a real user reported it often not appearing at
  // all, on top of drag-selecting a specific range already being fiddly.
  // These two buttons do the same clipboard operations directly, so
  // repeating an earlier verse (select it, copy, jump to the bottom,
  // paste) doesn't depend on that toolbar ever showing up. Copy falls back
  // to the whole lyrics block when nothing is selected — copying "the
  // verse I'm looking at" only works if there's something selected first,
  // but copying everything is still a reasonable default action.
  Future<void> _copyLyricsSelection(String language) async {
    final text = _lyricsController.text;
    final selection = _lyricsController.selection;
    final hasSelection =
        selection.isValid && !selection.isCollapsed;
    final toCopy = hasSelection ? selection.textInside(text) : text;
    if (toCopy.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: toCopy));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppTranslations.getText(
            hasSelection ? 'copiedSelectionMessage' : 'copiedAllMessage',
            language,
          ),
        ),
      ),
    );
  }

  Future<void> _pasteLyricsClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    _insertAtCursor(text);
  }

  // ---- shared section styling (used by build() and _buildKeyPanel) -----

  Widget _sectionCard(ColorScheme scheme, Widget child) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: scheme.onSurface.withOpacity(0.08)),
      boxShadow: AppShadows.soft(scheme.onSurface),
    ),
    child: child,
  );

  Widget _sectionLabel(ColorScheme scheme, String text) => Text(
    text,
    style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurface),
  );

  // Key picker + diatonic chord chips. Pinned to the top on wide screens
  // (see the LayoutBuilder in build()) so it stays reachable while
  // scrolling through a long lyrics block. On narrow screens it's shown
  // inside a popup instead (see _openChordPopup) rather than pinned or
  // inline, since permanently pinning this many rows would eat most of a
  // small screen, and leaving it inline meant scrolling all the way back
  // up to insert every single chord while writing a whole song.
  //
  // [onKeyChanged] fires (in addition to the setState this already does
  // internally) whenever the root/major-minor selector changes. It's how
  // _openChordPopup's StatefulBuilder re-renders this panel's chord list
  // immediately — a plain setState() on this State doesn't rebuild content
  // already handed to showModalBottomSheet's builder.
  //
  // [onInserted] fires after any chord/separator/section-label tap — how
  // _openChordPopup closes itself right after a single selection, instead
  // of staying open waiting for another tap.
  Widget _buildKeyPanel(
    ColorScheme scheme,
    String language, {
    VoidCallback? onKeyChanged,
    VoidCallback? onInserted,
  }) {
    final chords = diatonicChordsForKey(_selectedRoot, isMinor: _isMinorKey);
    return _sectionCard(
      scheme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sectionLabel(scheme, AppTranslations.getText('keyLabel', language)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                value: _selectedRoot,
                items:
                    chromaticRoots
                        .map(
                          (r) => DropdownMenuItem(value: r, child: Text(r)),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedRoot = value);
                    onKeyChanged?.call();
                  }
                },
              ),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(
                      AppTranslations.getText('majorLabel', language),
                    ),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(
                      AppTranslations.getText('minorLabel', language),
                    ),
                  ),
                ],
                selected: {_isMinorKey},
                onSelectionChanged: (s) {
                  setState(() => _isMinorKey = s.first);
                  onKeyChanged?.call();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...chords.map((c) {
                return ActionChip(
                  label: Text('${c.chordName} (${c.degree})'),
                  onPressed: () {
                    _insertChord(c.chordName);
                    onInserted?.call();
                  },
                );
              }),
              // For chord-only lines (intro/solo/outro with no lyrics) —
              // inserts " / " so authors don't need to reach for the
              // keyboard between chord taps.
              Tooltip(
                message:
                    'Chord separator — for lines with no lyrics '
                    '(intro, solo, outro)',
                child: ActionChip(
                  label: const Text('/'),
                  onPressed: () {
                    _insertAtCursor(' / ');
                    onInserted?.call();
                  },
                ),
              ),
              // For half-step chord runs, e.g. [C]-[C#] — no surrounding
              // spaces, unlike the "/" separator above, since this sits
              // tight between two chord tags rather than between words.
              Tooltip(
                message: 'Half-step chord link, e.g. [C]-[C#]',
                child: ActionChip(
                  label: const Text('-'),
                  onPressed: () {
                    _insertAtCursor('-');
                    onInserted?.call();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _sectionLabels.map((label) {
                  return OutlinedButton(
                    onPressed: () {
                      _insertLabel(label);
                      onInserted?.call();
                    },
                    child: Text(label),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  // Mobile only: opens the Key/chord-chip panel (see _buildKeyPanel) as a
  // popup instead of pinning it or leaving it inline — one tap away from
  // anywhere in the lyrics without permanently eating screen space or
  // forcing a scroll back to the top for every chord insertion. Closes
  // itself the moment a chord/separator/section-label is tapped (see
  // onInserted) rather than staying open for more taps — picking the Key
  // or Major/Minor first doesn't close it, only an actual insertion does.
  void _openChordPopup(String language) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final scheme = Theme.of(sheetContext).colorScheme;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: SingleChildScrollView(
                  child: _buildKeyPanel(
                    scheme,
                    language,
                    onKeyChanged: () => setModalState(() {}),
                    onInserted: () => Navigator.pop(sheetContext),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---- category/gender dropdown ----------------------------------------

  Widget _buildOptionPicker({
    required String label,
    required List<String> options,
    required String? selected,
    required bool isOther,
    required TextEditingController otherController,
    required void Function(String? value, bool other) onChanged,
    // The dropdown's *value* (what's stored/compared) can differ from its
    // *display text* — used for the preset categories (category_labels.dart)
    // so the stored value stays a stable key while the label shown follows
    // the site's current language. Defaults to showing the value as-is,
    // which is what every other picker (Gender, freely-typed categories)
    // wants.
    String Function(String value)? displayLabel,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final language = context.watch<LocaleProvider>().currentLanguage;
    final display = displayLabel ?? (v) => v;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: isOther ? '__other__' : selected,
          decoration: InputDecoration(labelText: label),
          items: [
            ...options.map(
              (o) => DropdownMenuItem(value: o, child: Text(display(o))),
            ),
            DropdownMenuItem(
              value: '__other__',
              child: Text(AppTranslations.getText('otherOption', language)),
            ),
          ],
          onChanged: (value) {
            if (value == '__other__') {
              onChanged(null, true);
            } else {
              onChanged(value, false);
            }
          },
        ),
        if (isOther)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              controller: otherController,
              decoration: InputDecoration(
                labelText: AppTranslations.getText('otherOption', language),
              ),
            ),
          ),
        SizedBox(height: 4, child: ColoredBox(color: scheme.surface)),
      ],
    );
  }

  Stream<_SubmitFormOptions> _optionValuesStream() {
    // Must exclude drafts explicitly: firestore.rules only allows reading a
    // draft doc as its own author, so an unconstrained query over the
    // *whole* songs collection would get rejected outright the moment any
    // other user's draft exists (Firestore requires a query to be provably
    // safe for every document it could match, not just the ones actually
    // returned) — this filter is what makes that provable.
    return FirebaseFirestore.instance
        .collection('songs')
        .where('status', isNotEqualTo: 'draft')
        .snapshots()
        .map((snapshot) {
      // presetCategories (see category_labels.dart) are seeded regardless
      // of whether any song has used them yet — otherwise a category only
      // becomes selectable *after* someone has already typed it in via
      // "Other" once, which isn't how a picklist should work for values we
      // already know we want offered.
      final categories = <String>{...presetCategories};
      // presetGenders (see gender_labels.dart) seeded the same way, and for
      // the same reason.
      final genders = <String>{...presetGenders};
      final bands = <String>{};
      final songs = <_SongOption>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        // Normalized here too (not just at save time) so a straggler doc
        // that predates the write-time fix — or the one-time migration —
        // can't still show up as a duplicate, untranslated raw-text option.
        final category = normalizeCategoryValue(data['category'] as String?);
        final gender = normalizeGenderValue(data['gender'] as String?);
        if (category != null) categories.add(category);
        if (gender != null) genders.add(gender);
        final band = (data['band'] as String?)?.trim() ?? '';
        if (band.isNotEmpty) bands.add(band);
        final songName = (data['songName'] as String?)?.trim() ?? '';
        if (songName.isNotEmpty) {
          songs.add(
            _SongOption(
              songName,
              songName.toLowerCase(),
              (data['artist'] as String?)?.trim() ?? '',
            ),
          );
        }
      }
      return _SubmitFormOptions(
        categories: categories,
        genders: genders,
        bands: bands,
        songs: songs,
      );
    });
  }

  // Substring match (not prefix-only) so e.g. typing a distinctive middle
  // word of a long title still surfaces it — capped at a handful of
  // results since this is meant as a quick visual scan, not a full search.
  List<String> _matchingBands(String query, Set<String> bands) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return (bands.where((b) => b.toLowerCase().contains(q)).toList()..sort())
        .take(8)
        .toList();
  }

  List<_SongOption> _matchingSongs(String query, List<_SongOption> songs) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return songs.where((s) => s.songNameLower.contains(q)).take(8).toList();
  }

  // Shared styling for the Artist/Band/Song-Name suggestion dropdowns —
  // same boxed-list look everywhere a typeahead can show matches.
  Widget _suggestionsBox(ColorScheme scheme, List<Widget> tiles) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.onSurface.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: tiles),
    );
  }

  // ---- duplicate-song check + submit -----------------------------------

  Future<bool> _confirmDuplicateIfNeeded(
    List<String> artistIds,
    String songNameLower,
    String language, {
    String? excludeDocId,
  }) async {
    if (artistIds.isEmpty) return true;
    // status != draft for the same reason _optionValuesStream excludes it:
    // without it, this query would be rejected outright on the rare chance
    // it matches another user's private draft (needs a composite index —
    // see firestore.indexes.json). arrayContainsAny (max 10 values, plenty
    // for any realistic group size) matches a song sharing *any* credited
    // artist with this one, not just an exact same-lineup match.
    final dup =
        await FirebaseFirestore.instance
            .collection('songs')
            .where('artistIds', arrayContainsAny: artistIds)
            .where('songNameLower', isEqualTo: songNameLower)
            .where('status', isNotEqualTo: 'draft')
            .limit(excludeDocId == null ? 1 : 5)
            .get();
    // When editing, the song being saved is naturally its own "duplicate"
    // by name+artist — exclude it so re-saving without changing the name
    // doesn't trigger a pointless warning about itself.
    final realDup =
        excludeDocId == null
            ? dup.docs
            : dup.docs.where((d) => d.id != excludeDocId);
    if (realDup.isEmpty) return true;
    if (!mounted) return false;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppTranslations.getText('duplicateSongTitle', language)),
          content: Text(
            AppTranslations.getText('duplicateSongMessage', language),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(AppTranslations.getText('cancelButton', language)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(AppTranslations.getText('continueButton', language)),
            ),
          ],
        );
      },
    );
    return proceed ?? false;
  }

  // A normal user has no way to edit a submission after it's sent — editing
  // is admin-only (see SubmitSongScreen.isEditing) — so this is their one
  // chance to back out and double-check before it's locked in. Skipped
  // entirely when admin is editing/releasing a song, since that action is
  // already an explicit, correctable admin decision.
  Future<bool> _confirmReadyToSubmit(String language) async {
    if (!mounted) return false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppTranslations.getText('confirmSubmitTitle', language)),
          content: Text(
            AppTranslations.getText('confirmSubmitMessage', language),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(AppTranslations.getText('cancelButton', language)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                AppTranslations.getText('confirmSubmitButton', language),
              ),
            ),
          ],
        );
      },
    );
    return proceed ?? false;
  }

  Future<void> _submit(String language) async {
    final artistNames = _activeArtistNames;
    // Joined for the display-only "artist" field every other screen still
    // reads as one plain string (reader page, admin, My Songs, home page's
    // latest-songs preview) — see the doc comment on artistIds/artistNames
    // in the save methods below for why those didn't need to change too.
    final artistDisplay = artistNames.join(' & ');
    final band = _bandController.text.trim();
    final songwriter = _songwriterController.text.trim();
    final songName = _songNameController.text.trim();
    final youtubeLink = _youtubeLinkController.text.trim();
    // normalize*Value: a freeform "Other" entry (or a dropdown pick of an
    // old, not-yet-migrated raw value still present in the live-scanned
    // option list) that happens to match a known pre-preset raw value
    // (e.g. someone retyping "ၵူၼ်းၸၢႆး" from habit) is converted to the
    // stable key at the point of saving, so it doesn't reintroduce an
    // untranslatable duplicate option — see the doc comments on those
    // functions for the fuller rationale.
    final category = normalizeCategoryValue(
      _categoryIsOther ? _otherCategoryController.text.trim() : _selectedCategory,
    );
    final gender = normalizeGenderValue(
      _genderIsOther ? _otherGenderController.text.trim() : _selectedGender,
    );

    if (artistNames.isEmpty ||
        songName.isEmpty ||
        _lyricsController.text.trim().isEmpty) {
      setState(
        () =>
            _errorMessage = AppTranslations.getText(
              'pleaseFillRequiredFields',
              language,
            ),
      );
      return;
    }

    if (!widget.isEditing || widget.isResubmission || widget.isDraftContinuation) {
      final ready = await _confirmReadyToSubmit(language);
      if (!mounted) return;
      if (!ready) return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final artistIds = await _resolveArtistIds(language);
    if (!mounted) return;
    if (artistIds == null) {
      setState(() => _isSubmitting = false);
      return;
    }

    final songNameLower = songName.toLowerCase();
    final shouldContinue = await _confirmDuplicateIfNeeded(
      artistIds,
      songNameLower,
      language,
      excludeDocId: widget.editingSongId,
    );
    if (!mounted) return;
    if (!shouldContinue) {
      setState(() => _isSubmitting = false);
      return;
    }

    final lyrics = parseLyricsBlock(_lyricsController.text);

    if (widget.isEditing) {
      if (widget.isDraftContinuation) {
        await _submitDraftForReview(
          artistNames: artistNames,
          artistDisplay: artistDisplay,
          band: band,
          songwriter: songwriter,
          songName: songName,
          songNameLower: songNameLower,
          artistIds: artistIds,
          category: category,
          gender: gender,
          lyrics: lyrics,
          youtubeLink: youtubeLink,
        );
      } else if (widget.isResubmission) {
        await _saveResubmittedSong(
          artistNames: artistNames,
          artistDisplay: artistDisplay,
          band: band,
          songwriter: songwriter,
          songName: songName,
          songNameLower: songNameLower,
          artistIds: artistIds,
          category: category,
          gender: gender,
          lyrics: lyrics,
          youtubeLink: youtubeLink,
        );
      } else {
        await _saveEditedSong(
          artistNames: artistNames,
          artistDisplay: artistDisplay,
          band: band,
          songwriter: songwriter,
          songName: songName,
          songNameLower: songNameLower,
          artistIds: artistIds,
          category: category,
          gender: gender,
          lyrics: lyrics,
          youtubeLink: youtubeLink,
        );
      }
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppTranslations.getText(
              (widget.isResubmission || widget.isDraftContinuation)
                  ? 'submitSuccessMessage'
                  : 'songReleasedMessage',
              language,
            ),
          ),
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    final auth = context.read<AuthProvider>();
    final songRef = FirebaseFirestore.instance.collection('songs').doc();
    await songRef.set({
      'songName': songName,
      'songNameLower': songNameLower,
      'artist': artistDisplay,
      'artistIds': artistIds,
      'artistNames': artistNames,
      'band': band,
      'songwriter': songwriter,
      'youtubeLink': youtubeLink,
      'category': category,
      'gender': gender,
      'key': _selectedRoot,
      'keyIsMinor': _isMinorKey,
      'lyrics': lyrics,
      'status': 'pending',
      'authorId': auth.user?.uid,
      'authorName': auth.displayName ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppTranslations.getText('submitSuccessMessage', language),
        ),
        duration: const Duration(seconds: 6),
      ),
    );
    setState(() {
      for (final entry in _artistEntries) {
        entry.dispose();
      }
      _artistEntries
        ..clear()
        ..add(_ArtistEntry());
      _songwriterController.clear();
      _bandController.clear();
      _songNameController.clear();
      _otherCategoryController.clear();
      _otherGenderController.clear();
      _lyricsController.clear();
      _selectedCategory = null;
      _selectedGender = null;
      _categoryIsOther = false;
      _genderIsOther = false;
    });
  }

  // Saves an admin edit and "releases" the song: always ends in
  // status: 'approved' (whether it started pending — combining edit+approve
  // into one action — or was already approved and this is just a fix-up).
  // approvedSongCount only increments the first time a song becomes
  // approved, never again on a later edit of an already-approved song.
  Future<void> _saveEditedSong({
    required List<String> artistNames,
    required String artistDisplay,
    required String band,
    required String songwriter,
    required String songName,
    required String songNameLower,
    required List<String> artistIds,
    required String? category,
    required String? gender,
    required List<Map<String, dynamic>> lyrics,
    required String youtubeLink,
  }) async {
    final wasApproved = widget.editingSongData?['status'] == 'approved';
    final batch = FirebaseFirestore.instance.batch();
    batch.update(
      FirebaseFirestore.instance.collection('songs').doc(widget.editingSongId),
      {
        'songName': songName,
        'songNameLower': songNameLower,
        'artist': artistDisplay,
        'artistIds': artistIds,
        'artistNames': artistNames,
        'band': band,
        'songwriter': songwriter,
        'youtubeLink': youtubeLink,
        'category': category,
        'gender': gender,
        'key': _selectedRoot,
        'keyIsMinor': _isMinorKey,
        'lyrics': lyrics,
        'status': 'approved',
        // Only set the first time a song becomes approved — a later
        // fix-up edit of an already-approved song shouldn't reset when it
        // was originally published, same reasoning as approvedSongCount
        // only incrementing once below.
        if (!wasApproved) 'approvedAt': FieldValue.serverTimestamp(),
      },
    );
    if (!wasApproved) {
      final authorId = widget.editingSongData?['authorId'] as String?;
      if (authorId != null) {
        batch.update(
          FirebaseFirestore.instance.collection('users').doc(authorId),
          {'approvedSongCount': FieldValue.increment(1)},
        );
      }
    }
    await batch.commit();
  }

  // The author fixing up their own rejected song and sending it back for
  // review — always ends in status: 'pending' (never 'approved', that's
  // still admin-only) and clears the old rejectionReason, since it no
  // longer describes the (now-edited) content. firestore.rules enforces
  // the rejected -> pending transition and the author-owned/field-allowlist
  // restrictions server-side; this is just the client half.
  Future<void> _saveResubmittedSong({
    required List<String> artistNames,
    required String artistDisplay,
    required String band,
    required String songwriter,
    required String songName,
    required String songNameLower,
    required List<String> artistIds,
    required String? category,
    required String? gender,
    required List<Map<String, dynamic>> lyrics,
    required String youtubeLink,
  }) async {
    await FirebaseFirestore.instance
        .collection('songs')
        .doc(widget.editingSongId)
        .update({
          'songName': songName,
          'songNameLower': songNameLower,
          'artist': artistDisplay,
          'artistIds': artistIds,
          'artistNames': artistNames,
          'band': band,
          'songwriter': songwriter,
          'youtubeLink': youtubeLink,
          'category': category,
          'gender': gender,
          'key': _selectedRoot,
          'keyIsMinor': _isMinorKey,
          'lyrics': lyrics,
          'status': 'pending',
          'rejectionReason': FieldValue.delete(),
        });
  }

  // The author promoting their own draft to a real, reviewable submission
  // for the first time — a full overwrite (not a partial update) because a
  // draft's fields were never validated the way a fresh submission's are,
  // so this goes through the exact same shape as a brand-new submission
  // (see the songRef.set(...) a few lines up in _submit), just targeting
  // the draft's existing doc ID instead of creating a new one. createdAt is
  // reset to *now* rather than whenever the draft was first saved, since
  // that's what "Latest Songs" on the home page sorts by — an old
  // half-finished draft shouldn't rank as stale the moment it's submitted.
  Future<void> _submitDraftForReview({
    required List<String> artistNames,
    required String artistDisplay,
    required String band,
    required String songwriter,
    required String songName,
    required String songNameLower,
    required List<String> artistIds,
    required String? category,
    required String? gender,
    required List<Map<String, dynamic>> lyrics,
    required String youtubeLink,
  }) async {
    final auth = context.read<AuthProvider>();
    await FirebaseFirestore.instance
        .collection('songs')
        .doc(widget.editingSongId)
        .set({
          'songName': songName,
          'songNameLower': songNameLower,
          'artist': artistDisplay,
          'artistIds': artistIds,
          'artistNames': artistNames,
          'band': band,
          'songwriter': songwriter,
          'youtubeLink': youtubeLink,
          'category': category,
          'gender': gender,
          'key': _selectedRoot,
          'keyIsMinor': _isMinorKey,
          'lyrics': lyrics,
          'status': 'pending',
          'authorId': auth.user?.uid,
          'authorName': auth.displayName ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  // "Save Draft" — deliberately skips artist-resolution (_resolveArtistId,
  // which can create a real artists/{id} doc and prompts about duplicates)
  // and the duplicate-song check, since a draft may be nowhere near
  // finished and shouldn't pollute the artists collection or nag about
  // conflicts yet. That validation happens for real when the draft is
  // finally submitted (_submitDraftForReview, same path a fresh submission
  // takes). No required-field check either, per the user's own call — a
  // draft can be saved completely blank.
  Future<void> _saveDraft(String language) async {
    setState(() => _draftSaving = true);
    final auth = context.read<AuthProvider>();
    final lyrics = parseLyricsBlock(_lyricsController.text);
    final category = normalizeCategoryValue(
      _categoryIsOther ? _otherCategoryController.text.trim() : _selectedCategory,
    );
    final gender = normalizeGenderValue(
      _genderIsOther ? _otherGenderController.text.trim() : _selectedGender,
    );
    // Drafts skip resolution entirely (see the doc comment above) — each
    // active entry's artistId is stored as-is, blank ('') if that artist
    // was never picked/created yet, same as the old single-artist behavior.
    final activeEntries = _activeArtistEntries;
    final artistNames = activeEntries.map((e) => e.controller.text.trim()).toList();
    final artistIds = activeEntries.map((e) => e.selectedArtistId ?? '').toList();
    final data = {
      'songName': _songNameController.text.trim(),
      'songNameLower': _songNameController.text.trim().toLowerCase(),
      'artist': artistNames.join(' & '),
      'artistIds': artistIds,
      'artistNames': artistNames,
      'band': _bandController.text.trim(),
      'songwriter': _songwriterController.text.trim(),
      'youtubeLink': _youtubeLinkController.text.trim(),
      'category': category,
      'gender': gender,
      'key': _selectedRoot,
      'keyIsMinor': _isMinorKey,
      'lyrics': lyrics,
      'status': 'draft',
      'authorId': auth.user?.uid,
      'authorName': auth.displayName ?? '',
    };
    final existingId = _draftDocId;
    if (existingId == null) {
      final ref = FirebaseFirestore.instance.collection('songs').doc();
      await ref.set({...data, 'createdAt': FieldValue.serverTimestamp()});
      _draftDocId = ref.id;
    } else {
      await FirebaseFirestore.instance
          .collection('songs')
          .doc(existingId)
          .update(data);
    }
    if (!mounted) return;
    setState(() => _draftSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppTranslations.getText('draftSavedMessage', language)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final language = context.watch<LocaleProvider>().currentLanguage;
    final previewLines = parseLyricsBlock(_lyricsController.text);

    Widget sectionCard(Widget child) => _sectionCard(scheme, child);
    Widget sectionLabel(String text) => _sectionLabel(scheme, text);

    final topSection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.isEditing)
          Text(
            AppTranslations.getText('submitSongTitle', language),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
        if (!widget.isEditing) const SizedBox(height: AppSpacing.md),

        sectionCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Artist typeahead(s) — a song can credit several artists (a
              // duet, a group), each with its own independent suggestions
              // dropdown, plus a link to add more and a remove button on
              // any row beyond the first.
              for (var i = 0; i < _artistEntries.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == _artistEntries.length - 1 ? 0 : 8,
                  ),
                  child: _buildArtistEntryRow(
                    _artistEntries[i],
                    i,
                    scheme,
                    language,
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const FaIcon(FontAwesomeIcons.plus, size: 18),
                  label: Text(
                    AppTranslations.getText('addArtistButton', language),
                  ),
                  style: TextButton.styleFrom(foregroundColor: scheme.onSurface),
                  onPressed:
                      () => setState(() => _artistEntries.add(_ArtistEntry())),
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _songwriterController,
                decoration: InputDecoration(
                  labelText: AppTranslations.getText(
                    'songwriterLabel',
                    language,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              StreamBuilder<_SubmitFormOptions>(
                stream: _optionValuesStream(),
                builder: (context, snapshot) {
                  final options = snapshot.data;
                  final categories = (options?.categories ?? {}).toList()..sort();
                  final genders = (options?.genders ?? {}).toList()..sort();
                  final bandMatches = _matchingBands(
                    _bandController.text,
                    options?.bands ?? {},
                  );
                  final songMatches = _matchingSongs(
                    _songNameController.text,
                    options?.songs ?? const [],
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Shows existing songs whose name matches what's being
                      // typed, each with its artist — lets a submitter tell
                      // "this exact song already exists" (same artist, real
                      // duplicate) apart from "this name is just reused by a
                      // different artist" (not a duplicate) before they've
                      // even finished typing, rather than only finding out
                      // via the warning dialog at submit time.
                      TextField(
                        controller: _songNameController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: AppTranslations.getText(
                            'songNameLabel',
                            language,
                          ),
                        ),
                      ),
                      if (songMatches.isNotEmpty)
                        _suggestionsBox(
                          scheme,
                          songMatches
                              .map(
                                (s) => ListTile(
                                  dense: true,
                                  title: Text(s.songName),
                                  subtitle:
                                      s.artistDisplay.isEmpty
                                          ? null
                                          : Text(s.artistDisplay),
                                  onTap:
                                      () => setState(
                                        () =>
                                            _songNameController.text =
                                                s.songName,
                                      ),
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 12),

                      // Optional, separate from Artist — a song can credit a
                      // band in addition to (not instead of) the required
                      // Artist field. Suggestions here matter more than they
                      // look: picking the exact existing spelling is what
                      // keeps every song from the same band grouped under
                      // one SongBook card instead of splintering into a
                      // duplicate-looking card per spelling variant.
                      TextField(
                        controller: _bandController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: AppTranslations.getText(
                            'bandLabel',
                            language,
                          ),
                        ),
                      ),
                      if (bandMatches.isNotEmpty)
                        _suggestionsBox(
                          scheme,
                          bandMatches
                              .map(
                                (b) => ListTile(
                                  dense: true,
                                  title: Text(b),
                                  onTap:
                                      () => setState(
                                        () => _bandController.text = b,
                                      ),
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 12),

                      // Optional — powers the "listen to original" button on
                      // the reading page (song_reader_screen.dart), which
                      // plays the linked video's audio in a small floating
                      // player. Any standard youtube.com/watch, youtube.com/
                      // embed, or youtu.be link works — see
                      // utils/youtube_link.dart for the parsing.
                      TextField(
                        controller: _youtubeLinkController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.getText(
                            'youtubeLinkLabel',
                            language,
                          ),
                          hintText: AppTranslations.getText(
                            'youtubeLinkHint',
                            language,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildOptionPicker(
                              label: AppTranslations.getText(
                                'categoryLabel',
                                language,
                              ),
                              options: categories,
                              selected: _selectedCategory,
                              isOther: _categoryIsOther,
                              otherController: _otherCategoryController,
                              displayLabel:
                                  (v) => categoryDisplayLabel(v, language),
                              onChanged: (value, other) {
                                setState(() {
                                  _selectedCategory = value;
                                  _categoryIsOther = other;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildOptionPicker(
                              label: AppTranslations.getText(
                                'genderLabel',
                                language,
                              ),
                              options: genders,
                              selected: _selectedGender,
                              isOther: _genderIsOther,
                              otherController: _otherGenderController,
                              displayLabel:
                                  (v) => genderDisplayLabel(v, language),
                              onChanged: (value, other) {
                                setState(() {
                                  _selectedGender = value;
                                  _genderIsOther = other;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );

    // See _buildKeyPanel's doc comment for why wide vs. narrow screens
    // treat this panel so differently (pinned sliver vs. tap-to-open popup).
    final keyPanel = _buildKeyPanel(scheme, language);

    final bottomSection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  sectionLabel(
                    AppTranslations.getText('lyricsLabel', language),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _copyLyricsSelection(language),
                    icon: const FaIcon(FontAwesomeIcons.copy, size: 16),
                    label: Text(
                      AppTranslations.getText('copyButton', language),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pasteLyricsClipboard,
                    icon: const FaIcon(FontAwesomeIcons.paste, size: 16),
                    label: Text(
                      AppTranslations.getText('pasteButton', language),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _lyricsController,
                focusNode: _lyricsFocusNode,
                // Auto-grows with the content instead of a fixed 10-line
                // box — a real user reported the old fixed height being
                // unworkable for a full song's lyrics on both mobile and
                // desktop. Flutter has no draggable-resize handle for a
                // TextField (that's an HTML <textarea> affordance), so
                // auto-expand is the equivalent fix.
                minLines: 10,
                maxLines: null,
                style: const TextStyle(fontFamily: 'Courier New'),
                decoration: InputDecoration(
                  hintText: AppTranslations.getText('lyricsHint', language),
                ),
              ),
              const SizedBox(height: 20),

              // Live preview, using the same renderer book_screen.dart uses.
              sectionLabel(AppTranslations.getText('previewLabel', language)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.onSurface.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: scheme.onSurface.withOpacity(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      previewLines
                          .map(
                            (line) => buildLyricLine(
                              context,
                              line['content'] as List,
                              transposeSteps: 0,
                              fontScale: 1.0,
                              textColor: scheme.onSurface,
                            ),
                          )
                          .toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_errorMessage!, style: TextStyle(color: scheme.error)),
          ),
        Row(
          children: [
            // Only where "not yet submitted" is a meaningful state to be
            // in: a brand-new song, or continuing a draft. Admin edit/
            // release and rejected-song resubmission both act on a song
            // that's already past the draft stage.
            if (!widget.isResubmission &&
                (!widget.isEditing || widget.isDraftContinuation)) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _draftSaving ? null : () => _saveDraft(language),
                  child:
                      _draftSaving
                          ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onSurface,
                            ),
                          )
                          : Text(
                            AppTranslations.getText('saveDraftButton', language),
                          ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : () => _submit(language),
                child:
                    _isSubmitting
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.surface,
                          ),
                        )
                        : Text(
                          AppTranslations.getText(
                            (widget.isEditing &&
                                    !widget.isResubmission &&
                                    !widget.isDraftContinuation)
                                ? 'releaseSongButton'
                                : 'submitButton',
                            language,
                          ),
                        ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );

    final body = LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppBreakpoints.tablet;
        if (!isWide) {
          // Narrow screens: no pinning and no inline Key/chord panel — the
          // Key row + chord chips + section-label chips wrap onto several
          // rows at phone widths, and permanently pinning that many rows
          // would eat most of a small screen. Leaving it inline (the old
          // behavior) meant scrolling all the way back up to insert every
          // single chord while writing a whole song, so it's reachable via
          // the floating button instead (see _openChordPopup).
          return Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  controller: _bodyScrollController,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          topSection,
                          const SizedBox(height: AppSpacing.md),
                          bottomSection,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
                  heroTag: 'submitSongChordPopupFab',
                  tooltip: AppTranslations.getText('keyLabel', language),
                  onPressed: () => _openChordPopup(language),
                  child: const FaIcon(FontAwesomeIcons.guitar),
                ),
              ),
            ],
          );
        }

        // Wide screens: pin the Key/chord panel under the navbar. `height`
        // is a breakpoint estimate (tuned against real renders) rather than
        // a measured value, since Wrap's reflow makes the panel's natural
        // height depend on exact chip widths — good enough here since this
        // is an internal composing tool, not a pixel-critical public page.
        // (Original estimate of 190/230 overflowed by ~6px on a real
        // browser — OS/font-rendering metrics run a little taller than the
        // headless Chromium this was tuned against — bumped up with more
        // headroom so small variance like that doesn't clip again.)
        final keyPanelHeight =
            constraints.maxWidth >= AppBreakpoints.desktop ? 224.0 : 264.0;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: CustomScrollView(
              controller: _bodyScrollController,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(child: topSection),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.md),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyPanelDelegate(
                    height: keyPanelHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: keyPanel,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.md),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  sliver: SliverToBoxAdapter(child: bottomSection),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Reached via Navigator.push from admin_screen.dart or book_screen.dart
    // (an admin-only entry point, never part of the normal MenuItem-based
    // top-level navigation this screen otherwise lives in) — needs its own
    // Scaffold/AppBar for a back arrow, since there's no surrounding one
    // like there is when this screen is shown for a normal new submission.
    if (!widget.isEditing) return body;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.getText('editSongTitle', language)),
      ),
      body: body,
    );
  }
}
