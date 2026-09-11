import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pai_morn_web/auth/auth_provider.dart';
import 'package:pai_morn_web/data/chord_shapes.dart';
import 'package:pai_morn_web/data/ukulele_chord_shapes.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/theme/app_theme.dart';
import 'package:pai_morn_web/utils/fullscreen_controller.dart';
import 'package:pai_morn_web/utils/instrument_mode.dart';
import 'package:pai_morn_web/utils/metronome_sound.dart';
import 'package:pai_morn_web/utils/recently_viewed_songs.dart';
import 'package:pai_morn_web/utils/song_view_recorder.dart';
import 'package:pai_morn_web/utils/youtube_link.dart';
import 'package:pai_morn_web/widget/chord_diagram_painter.dart';
import 'package:pai_morn_web/widget/favorite_button.dart';
import 'package:pai_morn_web/widget/lyric_line_view.dart';
import 'package:pai_morn_web/widget/youtube_mini_player.dart';

// Fixed-extent sliver header used to pin the auto-scroll play/pause/speed/
// stop bar to the top of the lyrics view once it scrolls that far.
class _StickyBarDelegate extends SliverPersistentHeaderDelegate {
  const _StickyBarDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _StickyBarDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}

/// The full-featured song reading page — transpose, font-size, auto-scroll,
/// metronome, compact layout, fullscreen. Originally lived inline
/// inside `book_screen.dart`'s `_BookScreenState`, entangled with artist/
/// song browsing; extracted into its own route/screen so it can be reached
/// (and deep-linked to, via `/songbook/song/:songId`) from anywhere — the
/// SongBook browsing flow, My Songs, or a shared URL — instead of only from
/// BookScreen's own internal selection state. Fetches its own data by ID
/// (`StreamBuilder` on `songs/{songId}`) rather than being handed the song
/// doc by a parent, which is what makes it independently reachable.
class SongReaderScreen extends StatefulWidget {
  const SongReaderScreen({super.key, required this.songId, this.setlistId});

  final String songId;

  // Present when opened from a setlist (see SetlistDetailScreen) — enables
  // the Next/Previous controls that step through that setlist's song order.
  final String? setlistId;

  @override
  State<SongReaderScreen> createState() => _SongReaderScreenState();
}

class _SongReaderScreenState extends State<SongReaderScreen>
    with TickerProviderStateMixin {
  int _transposeSteps = 0;
  double _lyricsFontScale = 1.0;

  final ScrollController _lyricsScrollController = ScrollController();
  Ticker? _scrollTicker;
  bool _isAutoScrolling = false;
  double _scrollSpeedLevel = 40;
  double _scrollStartOffset = 0;
  bool _controlBarExpanded = false;
  bool _compactLyrics = false;

  final MetronomeSound _metronomeSound = MetronomeSound();
  bool _metronomeEnabled = false;
  double _metronomeBpm = 80;
  Timer? _metronomeTimer;

  final FullscreenController _fullscreenController = FullscreenController();
  bool _isFullscreenView = false;

  bool _showYoutubePlayer = false;

  // Loaded once (not streamed — a setlist changing mid-read is rare, and
  // Next/Previous just needs a snapshot of the order at open time).
  List<String>? _setlistSongIds;

  @override
  void initState() {
    super.initState();
    _fullscreenController.onChange(() {
      if (mounted) {
        setState(() => _isFullscreenView = _fullscreenController.isActive);
      }
    });
    // Recorded from the widget's own songId, not the StreamBuilder's loaded
    // data below — this only needs to happen once per screen open, and
    // waiting on the first snapshot would also mean re-triggering (harmless
    // here since recordViewedSong is idempotent-ish, but pointless) on every
    // later live update to the same song doc.
    recordViewedSong(widget.songId);
    recordSongView(widget.songId);
    _loadSetlist();
  }

  Future<void> _loadSetlist() async {
    final setlistId = widget.setlistId;
    if (setlistId == null) return;
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('setlists')
            .doc(setlistId)
            .get();
    if (!mounted) return;
    setState(() {
      _setlistSongIds = List<String>.from(doc.data()?['songIds'] as List? ?? []);
    });
  }

  Future<void> _showReportIssueDialog(
    BuildContext context,
    String songId,
    String songName,
  ) async {
    final language = context.read<LocaleProvider>().currentLanguage;
    var issueType = 'wrongChords';
    final descriptionController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(
                AppTranslations.getText('reportIssueTitle', language),
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.getText('issueTypeLabel', language),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: Theme.of(dialogContext).colorScheme.onSurface,
                      title: Text(
                        AppTranslations.getText(
                          'issueTypeWrongChords',
                          language,
                        ),
                      ),
                      value: 'wrongChords',
                      groupValue: issueType,
                      onChanged:
                          (v) => setDialogState(() => issueType = v!),
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: Theme.of(dialogContext).colorScheme.onSurface,
                      title: Text(
                        AppTranslations.getText(
                          'issueTypeWrongLyrics',
                          language,
                        ),
                      ),
                      value: 'wrongLyrics',
                      groupValue: issueType,
                      onChanged:
                          (v) => setDialogState(() => issueType = v!),
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: Theme.of(dialogContext).colorScheme.onSurface,
                      title: Text(
                        AppTranslations.getText('issueTypeOther', language),
                      ),
                      value: 'other',
                      groupValue: issueType,
                      onChanged:
                          (v) => setDialogState(() => issueType = v!),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: AppTranslations.getText(
                          'issueDescriptionHint',
                          language,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(
                    AppTranslations.getText('cancelButton', language),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    AppTranslations.getText('submitReportButton', language),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (submitted != true) return;
    await FirebaseFirestore.instance.collection('songIssueReports').add({
      'songId': songId,
      'songName': songName,
      'issueType': issueType,
      'description': descriptionController.text.trim(),
      'resolved': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppTranslations.getText('reportIssueSuccessMessage', language),
        ),
      ),
    );
  }

  Future<void> _showAddToSetlistDialog(
    BuildContext context,
    String songId,
  ) async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;
    final language = context.read<LocaleProvider>().currentLanguage;
    final setlistsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('setlists');
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppTranslations.getText('addToSetlistTitle', language)),
          content: SizedBox(
            width: 320,
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  setlistsRef
                      .orderBy('updatedAt', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final docs = snapshot.data!.docs;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['name'] as String?) ?? '';
                      final songIds = List<String>.from(
                        data['songIds'] as List? ?? [],
                      );
                      final checked = songIds.contains(songId);
                      return CheckboxListTile(
                        value: checked,
                        title: Text(name),
                        onChanged: (value) {
                          if (value == true) {
                            doc.reference.update({
                              'songIds': FieldValue.arrayUnion([songId]),
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                          } else {
                            doc.reference.update({
                              'songIds': FieldValue.arrayRemove([songId]),
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                          }
                        },
                      );
                    }),
                    ListTile(
                      leading: const FaIcon(FontAwesomeIcons.plus, size: 14),
                      title: Text(
                        AppTranslations.getText(
                          'createNewSetlistLabel',
                          language,
                        ),
                      ),
                      onTap: () async {
                        Navigator.of(dialogContext).pop();
                        await _createSetlistWithSong(
                          context,
                          setlistsRef,
                          songId,
                          language,
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppTranslations.getText('cancelButton', language)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createSetlistWithSong(
    BuildContext context,
    CollectionReference<Map<String, dynamic>> setlistsRef,
    String songId,
    String language,
  ) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppTranslations.getText('newSetlistTitle', language)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: AppTranslations.getText('setlistNameHint', language),
            ),
            onSubmitted:
                (value) => Navigator.of(dialogContext).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppTranslations.getText('cancelButton', language)),
            ),
            ElevatedButton(
              onPressed:
                  () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(AppTranslations.getText('saveButton', language)),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    await setlistsRef.add({
      'name': name,
      'songIds': [songId],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _goToSetlistOffset(int offset) {
    final ids = _setlistSongIds;
    if (ids == null || ids.isEmpty) return;
    final currentIndex = ids.indexOf(widget.songId);
    if (currentIndex == -1) return;
    final nextIndex = currentIndex + offset;
    if (nextIndex < 0 || nextIndex >= ids.length) return;
    context.go('/songbook/song/${ids[nextIndex]}?setlist=${widget.setlistId}');
  }

  @override
  void dispose() {
    _scrollTicker?.dispose();
    _lyricsScrollController.dispose();
    _metronomeTimer?.cancel();
    _fullscreenController.exit();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/songbook');
    }
  }

  // Uses the browser's native share sheet (Web Share API, via share_plus) so
  // it can hand off straight to whatever the user has installed — Line,
  // Facebook Messenger, etc. — not just a raw copied link. Falls back to
  // copying the link to the clipboard for browsers that don't support
  // Web Share (most desktop browsers) rather than failing silently — same
  // fallback shape as contact_screen.dart's `_ContactChannel`.
  Future<void> _shareSong(BuildContext context, String songName) async {
    final url = Uri.base.toString();
    try {
      final result = await Share.shareUri(Uri.parse(url));
      if (result.status != ShareResultStatus.unavailable) return;
    } catch (_) {
      // Web Share unsupported on this browser — fall through to clipboard.
    }
    if (!context.mounted) return;
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
    } catch (_) {
      // Clipboard access can be denied too — nothing more we can do.
    }
  }

  // Opens the real-DOM print page (songPrintPage in functions/index.js) in
  // a new tab rather than calling window.print() on this page directly —
  // Flutter web's canvas rendering has no text layer for the browser's
  // print engine to lay out on paper, the same reason songPreview exists
  // for search-bot indexing. Always shows the song's original written key
  // (no live transpose state to carry across to a fresh page load).
  void _printSong() {
    final url = '${Uri.base.origin}/songbook/song/${widget.songId}/print';
    launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
  }

  void _startAutoScroll() {
    if (!_lyricsScrollController.hasClients) return;
    _scrollStartOffset = _lyricsScrollController.offset;
    _scrollTicker?.dispose();
    _scrollTicker = createTicker(_onScrollTick)..start();
    setState(() {
      _isAutoScrolling = true;
    });
  }

  void _onScrollTick(Duration elapsed) {
    if (!_lyricsScrollController.hasClients) {
      _stopAutoScroll();
      return;
    }
    // Quadratic curve: gives fine-grained control at the slow end (where
    // this is actually used for reading lyrics) instead of the old linear
    // BPM mapping, whose "slowest" setting still scrolled too fast to read.
    const maxPxPerSecond = 64.0;
    final speedFraction = _scrollSpeedLevel / 100.0;
    final pxPerSecond = maxPxPerSecond * speedFraction * speedFraction;
    final target =
        _scrollStartOffset + pxPerSecond * elapsed.inMilliseconds / 1000.0;
    final maxExtent = _lyricsScrollController.position.maxScrollExtent;
    if (target >= maxExtent) {
      _lyricsScrollController.jumpTo(maxExtent);
      _stopAutoScroll();
    } else {
      _lyricsScrollController.jumpTo(target);
    }
  }

  void _stopAutoScroll() {
    _scrollTicker?.stop();
    _scrollTicker?.dispose();
    _scrollTicker = null;
    if (mounted && _isAutoScrolling) {
      setState(() {
        _isAutoScrolling = false;
      });
    }
  }

  void _toggleAutoScroll() {
    if (_isAutoScrolling) {
      _stopAutoScroll();
    } else {
      _startAutoScroll();
    }
  }

  void _changeScrollSpeed(double value) {
    setState(() {
      _scrollSpeedLevel = value.clamp(5, 100);
    });
    if (_isAutoScrolling) {
      // Restarts the ticker's elapsed-time baseline so the new speed
      // applies from the current position rather than jumping.
      _startAutoScroll();
    }
  }

  void _stopAndResetScroll() {
    _stopAutoScroll();
    if (_lyricsScrollController.hasClients) {
      _lyricsScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _toggleMetronome(bool enabled) {
    setState(() => _metronomeEnabled = enabled);
    if (enabled) {
      _startMetronome();
    } else {
      _stopMetronome();
    }
  }

  void _startMetronome() {
    _metronomeTimer?.cancel();
    _metronomeSound.click();
    final interval = Duration(milliseconds: (60000 / _metronomeBpm).round());
    _metronomeTimer = Timer.periodic(interval, (_) => _metronomeSound.click());
  }

  void _stopMetronome() {
    _metronomeTimer?.cancel();
    _metronomeTimer = null;
  }

  void _changeMetronomeBpm(double delta) {
    setState(() {
      _metronomeBpm = (_metronomeBpm + delta).clamp(30, 250);
    });
    if (_metronomeEnabled) {
      _startMetronome();
    }
  }

  void _resetLyricsControls() {
    _stopAutoScroll();
    _stopMetronome();
    setState(() {
      _transposeSteps = 0;
      _lyricsFontScale = 1.0;
      _scrollSpeedLevel = 40;
      _metronomeEnabled = false;
    });
  }

  Widget _circleIconButton(IconData icon, VoidCallback onPressed) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: scheme.onInverseSurface),
      ),
    );
  }

  Widget _valuePill(String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _stepperRow({
    required String label,
    required String valueText,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    final labelStyle = TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(width: 12),
        _circleIconButton(FontAwesomeIcons.minus, onDecrement),
        const SizedBox(width: 10),
        _valuePill(valueText),
        const SizedBox(width: 10),
        _circleIconButton(FontAwesomeIcons.plus, onIncrement),
      ],
    );
  }

  Widget _segmentedToggle({
    required String leftLabel,
    required String rightLabel,
    required bool rightSelected,
    required ValueChanged<bool> onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    Widget pill(String label, bool selected, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  selected
                      ? scheme.primary
                      : scheme.onSurface.withOpacity(0.35),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? scheme.onPrimary : scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pill(leftLabel, !rightSelected, () => onChanged(false)),
        const SizedBox(width: 8),
        pill(rightLabel, rightSelected, () => onChanged(true)),
      ],
    );
  }

  // Everything except the play/pause + speed slider + stop row below, which
  // is deliberately split out into _buildAutoScrollBar so it alone can be
  // pinned as a sticky sliver header while these bands scroll away normally.
  Widget _buildMainControls() {
    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;
    final labelStyle = TextStyle(color: onSurface, fontWeight: FontWeight.w600);
    final isNarrow = MediaQuery.of(context).size.width < 900;

    Widget band({required Widget child, required Color background}) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: background,
        child: child,
      );
    }

    final bandA = onSurface.withOpacity(0.04);
    final bandB = Colors.transparent;

    final controlsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        band(
          background: bandA,
          child: Center(
            child: _stepperRow(
              label: 'Key',
              valueText:
                  _transposeSteps == 0
                      ? '0'
                      : (_transposeSteps > 0
                          ? '+$_transposeSteps'
                          : '$_transposeSteps'),
              onDecrement: () => setState(() => _transposeSteps--),
              onIncrement: () => setState(() => _transposeSteps++),
            ),
          ),
        ),
        band(
          background: bandB,
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 20,
            runSpacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Text :', style: labelStyle),
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.magnifyingGlassMinus, size: 18),
                    color: onSurface,
                    onPressed:
                        () => setState(
                          () =>
                              _lyricsFontScale = (_lyricsFontScale - 0.1).clamp(
                                0.7,
                                2.0,
                              ),
                        ),
                  ),
                  Text(
                    '${(_lyricsFontScale * 100).round()}%',
                    style: labelStyle,
                  ),
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.magnifyingGlassPlus, size: 18),
                    color: onSurface,
                    onPressed:
                        () => setState(
                          () =>
                              _lyricsFontScale = (_lyricsFontScale + 0.1).clamp(
                                0.7,
                                2.0,
                              ),
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
        band(
          background: bandA,
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 20,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _metronomeEnabled,
                    onChanged: (v) => _toggleMetronome(v ?? false),
                  ),
                  Text('Metronome', style: labelStyle),
                  const SizedBox(width: 8),
                  _circleIconButton(
                    FontAwesomeIcons.minus,
                    () => _changeMetronomeBpm(-1),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${_metronomeBpm.round()}',
                      textAlign: TextAlign.center,
                      style: labelStyle,
                    ),
                  ),
                  _circleIconButton(FontAwesomeIcons.plus, () => _changeMetronomeBpm(1)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _compactLyrics,
                    onChanged:
                        (v) => setState(() => _compactLyrics = v ?? false),
                  ),
                  Text('Compact', style: labelStyle),
                ],
              ),
            ],
          ),
        ),
        band(
          background: bandB,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _segmentedToggle(
                leftLabel: 'Full',
                rightLabel: 'Scroll',
                rightSelected: !_isFullscreenView,
                onChanged: (scrollSelected) {
                  if (scrollSelected) {
                    _fullscreenController.exit();
                  } else {
                    _fullscreenController.enter();
                  }
                },
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const FaIcon(FontAwesomeIcons.arrowsRotate, size: 16),
                label: const Text('Reset'),
                style: TextButton.styleFrom(foregroundColor: onSurface),
                onPressed: _resetLyricsControls,
              ),
            ],
          ),
        ),
      ],
    );

    if (!isNarrow) {
      return controlsColumn;
    }

    // On narrow screens the control bar starts collapsed to a single toggle
    // row so it doesn't crowd the lyrics — tap it to reveal the full
    // Key/Text/BPM controls. The play/pause/speed/stop row lives outside
    // this collapse entirely (see _buildAutoScrollBar), always visible.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap:
              () => setState(() => _controlBarExpanded = !_controlBarExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                FaIcon(FontAwesomeIcons.sliders, color: onSurface, size: 18),
                const SizedBox(width: 8),
                Text('Controls', style: labelStyle),
                const Spacer(),
                FaIcon(
                  _controlBarExpanded
                      ? FontAwesomeIcons.chevronUp
                      : FontAwesomeIcons.chevronDown,
                  color: onSurface,
                ),
              ],
            ),
          ),
        ),
        if (_controlBarExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: controlsColumn,
          ),
      ],
    );
  }

  // The play/pause + speed slider + stop row — split out of the main
  // control bands so it alone can be pinned as a sticky sliver header in
  // _buildBody. Always visible (bypasses the narrow-screen collapse) since
  // it's the primary control needed while auto-scrolling. Deliberately a
  // single flat Row (no Slider+label stacked in a Column underneath) so its
  // height is just one IconButton tall and predictable — a stacked layout
  // here previously caused a bottom overflow inside the fixed-extent sliver
  // header once real device font metrics didn't match the guessed height.
  Widget _buildAutoScrollBar() {
    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;
    final labelStyle = TextStyle(color: onSurface, fontWeight: FontWeight.w600);
    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: FaIcon(
                _isAutoScrolling
                    ? FontAwesomeIcons.solidCirclePause
                    : FontAwesomeIcons.solidCirclePlay,
              ),
              color: onSurface,
              onPressed: _toggleAutoScroll,
            ),
            SizedBox(
              width: 160,
              child: Slider(
                value: _scrollSpeedLevel,
                min: 5,
                max: 100,
                onChanged: _changeScrollSpeed,
              ),
            ),
            SizedBox(
              width: 28,
              child: Text(
                '${_scrollSpeedLevel.round()}',
                textAlign: TextAlign.center,
                style: labelStyle,
              ),
            ),
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.circleStop),
              tooltip: 'Stop & scroll to top',
              color: onSurface,
              onPressed: _stopAndResetScroll,
            ),
          ],
        ),
      ),
    );
  }

  // Compact mode merges consecutive short lyric lines into one row until the
  // row picks up this many chords, instead of leaving a nearly-empty row for
  // every line that only has a couple of chords.
  static const _compactChordTarget = 3;

  // Normally each lyric line renders as its own row. In compact mode,
  // consecutive lines are merged into a row until it reaches
  // _compactChordTarget chords, then the next row starts — except a
  // standalone label/instrumental line (Key, Intro, Solo, Outro, or a bare
  // chord progression) never merges with its neighbors, since a low-chord-
  // count line like "Key" wouldn't hit the cutoff on its own and would
  // otherwise keep absorbing whatever followed it, including an entire
  // unrelated chord progression, into the same merged row.
  List<Widget> _buildLyricsWidgets(
    ColorScheme scheme,
    Map<String, dynamic> data,
  ) {
    final lyrics = data['lyrics'] as List?;
    if (lyrics == null) return const [];
    final rows =
        _compactLyrics
            ? _mergeLyricsForCompact(lyrics)
            : lyrics.map((lyric) => lyric['content'] as List).toList();
    return [
      for (final row in rows)
        buildLyricLine(
          context,
          row,
          transposeSteps: _transposeSteps,
          fontScale: _lyricsFontScale,
          textColor: scheme.onSurface,
        ),
    ];
  }

  List<List> _mergeLyricsForCompact(List lyrics) {
    final rows = <List>[];
    var currentRow = [];
    var chordCount = 0;
    for (final lyric in lyrics) {
      final content = lyric['content'] as List;
      // A standalone label/instrumental line (Key, Intro, Solo, Outro, or a
      // bare chord progression) never merges with its neighbors — flush
      // whatever was accumulating first, then let it stand as its own row.
      // Without this, a low-chord-count line like "Key" (1 chord) wouldn't
      // trigger a cutoff on its own, so it kept absorbing whatever followed
      // — including an entire unrelated Intro chord progression — into the
      // same merged row.
      if (isStandaloneLabelLine(content)) {
        if (currentRow.isNotEmpty) {
          rows.add(currentRow);
          currentRow = [];
          chordCount = 0;
        }
        rows.add(content);
        continue;
      }
      currentRow = [...currentRow, ...content];
      chordCount += content.where((item) => item['type'] == 'chord').length;
      if (chordCount >= _compactChordTarget) {
        rows.add(currentRow);
        currentRow = [];
        chordCount = 0;
      }
    }
    if (currentRow.isNotEmpty) {
      rows.add(currentRow);
    }
    return rows;
  }

  // Height of the sticky play/pause/speed/stop sliver header — must be a
  // fixed extent for SliverPersistentHeader. _buildAutoScrollBar is a single
  // flat Row (IconButton-tall, ~48px), so 64 leaves a comfortable margin for
  // platform/font-metric variance without risking a bottom overflow again.
  static const _autoScrollBarHeight = 64.0;

  // Artist (singer) / Band — the performer, not the songwriter or the site
  // contributor (see _buildSongwriterLine / the watermark in _buildBody for
  // those). Band is optional (see SubmitSongScreen), shown alongside Artist
  // rather than replacing it. Hidden entirely if both are blank (pre-
  // community-submission legacy songs may have neither).
  Widget _buildArtistLine(ColorScheme scheme, Map<String, dynamic> data) {
    final artist = (data['artist'] as String?)?.trim() ?? '';
    final band = (data['band'] as String?)?.trim() ?? '';
    if (artist.isEmpty && band.isEmpty) return const SizedBox.shrink();
    final parts = [
      if (artist.isNotEmpty) 'ႁွင်ႉ - $artist',
      if (band.isNotEmpty) 'Band: $band',
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        parts.join(' · '),
        style: TextStyle(
          fontSize: 14,
          color: scheme.onSurface.withOpacity(0.6),
        ),
      ),
    );
  }

  // Songwriter — unlike Artist/Band, always shown (falls back to "—") since
  // it sits right under the singer's name and an empty line there would
  // read as a layout gap rather than "not entered".
  Widget _buildSongwriterLine(ColorScheme scheme, Map<String, dynamic> data) {
    final songwriter = (data['songwriter'] as String?)?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        songwriter.isEmpty ? 'တႅမ်ႈ -' : 'တႅမ်ႈ - $songwriter',
        style: TextStyle(
          fontSize: 14,
          color: scheme.onSurface.withOpacity(0.6),
        ),
      ),
    );
  }

  // A live count of how many times this song's reader page has been opened
  // (server-incremented — see functions/index.js's recordSongView and
  // utils/song_view_recorder.dart) — a small "people actually use this"
  // signal, same spirit as favoriteCount elsewhere in the app. Hidden
  // entirely for a song with no count yet (e.g. one that predates this
  // field, or hasn't been opened since) rather than showing "0 views" for
  // every legacy song at once.
  Widget _buildViewCountLine(ColorScheme scheme, Map<String, dynamic> data) {
    final viewCount = (data['viewCount'] as num?)?.toInt() ?? 0;
    if (viewCount <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            FontAwesomeIcons.eye,
            size: 14,
            color: scheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(width: 4),
          Text(
            '$viewCount',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  // The site contributor (whoever typed this song in — not the songwriter
  // or performer) shown as a faint background watermark behind the lyrics
  // instead of a visible "by X" byline. Pre-community-submission legacy
  // songs have no authorName at all, so this renders nothing for them.
  Widget _buildContributorWatermark(
    ColorScheme scheme,
    Map<String, dynamic> data,
  ) {
    final authorName = (data['authorName'] as String?)?.trim() ?? '';
    if (authorName.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Text(
            authorName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface.withOpacity(0.08),
            ),
          ),
        ),
      ),
    );
  }

  // One faint fretboard diagram per chord actually used in the song (no
  // duplicates — a chord repeated 20 times still gets one diagram), stacked
  // top-to-bottom along the right edge in first-appearance order. Same
  // Stack-background technique as _buildContributorWatermark above (an
  // IgnorePointer'd Align layered behind the lyrics Column, scrolling with
  // the content rather than pinned to the viewport) and the same
  // ChordDiagramPainter/chordShapes rendering chords_screen.dart's reference
  // cards use, just drawn at low opacity instead of full color so it reads
  // as a subtle backdrop rather than competing with the lyrics on top.
  Widget _buildChordWatermark(ColorScheme scheme, Map<String, dynamic> data) {
    final lyrics = data['lyrics'] as List?;
    if (lyrics == null) return const SizedBox.shrink();

    final isUkulele = context.watch<InstrumentModeProvider>().isUkulele;
    final entries = <({String name, ChordShape shape})>[];
    for (final chord in uniqueChordsInOrder(lyrics, _transposeSteps)) {
      final shape =
          isUkulele
              ? lookupUkuleleChordShape(chord)
              : lookupChordShape(chord);
      if (shape != null) entries.add((name: chord, shape: shape));
    }
    if (entries.isEmpty) return const SizedBox.shrink();

    final faint = scheme.onSurface.withOpacity(0.14);
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width:
                                ChordDiagramPainter.preferredSizeFor(
                                  entry.shape.frets.length,
                                ).width,
                            height:
                                ChordDiagramPainter.preferredSizeFor(
                                  entry.shape.frets.length,
                                ).height,
                            child: CustomPaint(
                              painter: ChordDiagramPainter(
                                shape: entry.shape,
                                lineColor: faint,
                                dotColor: faint,
                                textColor: faint,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        entry.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: faint,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> data, String songName) {
    final scheme = Theme.of(context).colorScheme;
    final songContent = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: AppShadows.soft(scheme.onSurface),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          songName,
                          style: TextStyle(
                            fontSize: 22,
                            color: scheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _buildArtistLine(scheme, data),
                        _buildSongwriterLine(scheme, data),
                        _buildViewCountLine(scheme, data),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: _buildContributorWatermark(scheme, data),
                              ),
                              Positioned.fill(
                                child: _buildChordWatermark(scheme, data),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _buildLyricsWidgets(scheme, data),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // "Full" mode hands the whole screen to just the song content — no Key/
    // Text/Metronome/Compact controls, no play/pause/speed/stop bar either
    // (see the doc comment on _isFullscreenView's usage in build()) — a
    // real user asked for this after finding "Full" only removed the app
    // bar while every control band stayed on screen.
    if (_isFullscreenView) {
      return CustomScrollView(
        controller: _lyricsScrollController,
        slivers: [songContent],
      );
    }

    // Controls now scroll away with the content like the rest of the page —
    // except _buildAutoScrollBar (play/pause/speed/stop), which is pinned as
    // a sticky sliver header so it's still reachable once auto-scroll has
    // pushed the rest of the controls out of view.
    return CustomScrollView(
      controller: _lyricsScrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: _buildMainControls(),
              ),
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyBarDelegate(
            height: _autoScrollBarHeight,
            child: _buildAutoScrollBar(),
          ),
        ),
        songContent,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('songs')
              .doc(widget.songId)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(leading: BackButton(onPressed: _goBack)),
            body: const Center(child: Text('Song not found')),
          );
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final songName = (data['songName'] as String?) ?? '';
        final body = _buildBody(data, songName);
        final videoId = extractYoutubeVideoId(
          (data['youtubeLink'] as String?) ?? '',
        );

        // "Full" view mode hands the whole tab to the lyrics — no app bar —
        // on top of the real browser fullscreen requested via
        // _fullscreenController.
        final scaffold =
            _isFullscreenView
                ? Scaffold(body: body)
                : Scaffold(
                  appBar: AppBar(
                    leading: BackButton(onPressed: _goBack),
                    title: Text(
                      songName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    actions: [
                      if (videoId != null)
                        IconButton(
                          icon: FaIcon(
                            _showYoutubePlayer
                                ? FontAwesomeIcons.circleStop
                                : FontAwesomeIcons.circlePlay,
                          ),
                          tooltip: AppTranslations.getText(
                            'listenOriginalTooltip',
                            context.watch<LocaleProvider>().currentLanguage,
                          ),
                          onPressed:
                              () => setState(
                                () => _showYoutubePlayer = !_showYoutubePlayer,
                              ),
                        ),
                      if (_setlistSongIds != null) ...[
                        IconButton(
                          icon: const FaIcon(
                            FontAwesomeIcons.chevronLeft,
                            size: 16,
                          ),
                          tooltip: AppTranslations.getText(
                            'previousSongTooltip',
                            context.watch<LocaleProvider>().currentLanguage,
                          ),
                          onPressed:
                              _setlistSongIds!.indexOf(widget.songId) > 0
                                  ? () => _goToSetlistOffset(-1)
                                  : null,
                        ),
                        IconButton(
                          icon: const FaIcon(
                            FontAwesomeIcons.chevronRight,
                            size: 16,
                          ),
                          tooltip: AppTranslations.getText(
                            'nextSongTooltip',
                            context.watch<LocaleProvider>().currentLanguage,
                          ),
                          onPressed:
                              _setlistSongIds!.indexOf(widget.songId) <
                                      _setlistSongIds!.length - 1
                                  ? () => _goToSetlistOffset(1)
                                  : null,
                        ),
                      ],
                      FavoriteButton(songId: widget.songId),
                      IconButton(
                        icon: const FaIcon(
                          FontAwesomeIcons.listCheck,
                          size: 18,
                        ),
                        tooltip: AppTranslations.getText(
                          'addToSetlistTitle',
                          context.watch<LocaleProvider>().currentLanguage,
                        ),
                        onPressed:
                            () => _showAddToSetlistDialog(
                              context,
                              widget.songId,
                            ),
                      ),
                      IconButton(
                        icon: const FaIcon(
                          FontAwesomeIcons.triangleExclamation,
                          size: 18,
                        ),
                        tooltip: AppTranslations.getText(
                          'reportIssueTooltip',
                          context.watch<LocaleProvider>().currentLanguage,
                        ),
                        onPressed:
                            () => _showReportIssueDialog(
                              context,
                              widget.songId,
                              songName,
                            ),
                      ),
                      IconButton(
                        icon: const FaIcon(FontAwesomeIcons.print, size: 18),
                        tooltip: 'Print',
                        onPressed: _printSong,
                      ),
                      IconButton(
                        icon: const FaIcon(FontAwesomeIcons.shareNodes, size: 18),
                        tooltip: 'Share',
                        onPressed: () => _shareSong(context, songName),
                      ),
                    ],
                  ),
                  body: body,
                );

        if (!_showYoutubePlayer || videoId == null) return scaffold;
        return Stack(
          children: [
            scaffold,
            Positioned(
              right: 16,
              bottom: 16,
              child: YoutubeMiniPlayer(
                videoId: videoId,
                onClose: () => setState(() => _showYoutubePlayer = false),
              ),
            ),
          ],
        );
      },
    );
  }
}
