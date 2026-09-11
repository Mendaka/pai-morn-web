import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pai_morn_web/auth/auth_provider.dart';
import 'package:pai_morn_web/utils/artist_palette.dart';
import 'package:pai_morn_web/utils/pwa_install_controller.dart';
import 'package:pai_morn_web/widget/hover_scale.dart';
import 'package:pai_morn_web/widget/install_app_banner.dart';
import 'package:pai_morn_web/widget/lyric_line_view.dart';
import 'package:pai_morn_web/widget/todays_new_songs_card.dart';
import 'package:pai_morn_web/theme/app_theme.dart';

class _LatestSong {
  final String id;
  final String songName;
  final String artist;
  final List lyrics;
  const _LatestSong({
    required this.id,
    required this.songName,
    required this.artist,
    required this.lyrics,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<_LatestSong>? _latestSongs;
  // < 1.0 lets the neighboring cards peek in from both edges instead of
  // each page being a single edge-to-edge card with a lot of dead space
  // beside its (narrower) actual content — a user found the old full-width
  // card look "just sitting there" (mostly-empty ruled-paper background,
  // browser-chrome-style header). The peek also makes clearer at a glance
  // that this is a swipeable carousel, not a static hero.
  final PageController _heroPageController = PageController(
    viewportFraction: 0.86,
  );
  Timer? _heroAutoSlideTimer;
  int _heroPageIndex = 0;

  // Separate from InstallAppBanner's own controller instance — this section
  // is a permanent, non-dismissible entry point (the banner up top can be
  // dismissed and never seen again), so it needs to track installability
  // independently.
  final PwaInstallController _installController = PwaInstallController();

  // Shared with book_screen.dart and song_reader_screen.dart (see
  // utils/artist_palette.dart) so the artist previews here, the SongBook
  // covers, and the reader page's accent colors all agree on one identity
  // per artist/band instead of three independently-colored copies.
  static const List<Color> _artistPalette = artistPalette;

  Color _colorForArtist(String name) => colorForArtist(name);

  // A few large, soft-edged color washes behind the hero — the page was
  // otherwise almost entirely black/white/gray, which read as flat. Radial
  // gradients fading to transparent (rather than an actual blur filter)
  // give the same soft "aurora" look for near-zero paint cost, using the
  // same palette the artist cards already use so it reads as more of the
  // same app instead of a bolted-on new color scheme.
  Widget _heroBackdrop() {
    Widget blob(Color color, double size) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withOpacity(0.35), color.withOpacity(0)],
          ),
        ),
      );
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -80,
              left: -60,
              child: blob(_artistPalette[0], 320),
            ),
            Positioned(
              top: 20,
              right: -100,
              child: blob(_artistPalette[3], 380),
            ),
            Positioned(
              bottom: -100,
              left: 80,
              child: blob(_artistPalette[5], 300),
            ),
          ],
        ),
      ),
    );
  }

  // Fetched once in initState rather than inline in _buildStatsSection's
  // FutureBuilder — that method is called from inside a LayoutBuilder, which
  // re-runs its builder (and therefore would recreate the Future.wait(...))
  // on every window resize, restarting the count queries and flashing the
  // strip back to its loading state each time.
  late final Future<List<dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = Future.wait<dynamic>([
      FirebaseFirestore.instance
          .collection('songs')
          .where('status', isEqualTo: 'approved')
          .count()
          .get(),
      FirebaseFirestore.instance.collection('artists').count().get(),
      FirebaseFirestore.instance.collection('stats').doc('siteViews').get(),
    ]);
    _loadLatestSongs();
    _installController.init(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _heroAutoSlideTimer?.cancel();
    _heroPageController.dispose();
    super.dispose();
  }

  // "Latest" is submission order (createdAt, desc) among approved songs —
  // approval date isn't tracked separately, but this is a reasonable proxy
  // and needs no extra fields. Requires a composite index on
  // (status ASC, createdAt DESC) — see firestore.indexes.json.
  Future<void> _loadLatestSongs() async {
    final snap =
        await FirebaseFirestore.instance
            .collection('songs')
            .where('status', isEqualTo: 'approved')
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get();
    if (!mounted) return;
    setState(() {
      _latestSongs =
          snap.docs.map((doc) {
            final data = doc.data();
            return _LatestSong(
              id: doc.id,
              songName: (data['songName'] ?? '').toString(),
              artist: (data['artist'] ?? '').toString(),
              lyrics: (data['lyrics'] as List?) ?? const [],
            );
          }).toList();
    });
    if (_latestSongs!.length > 1) _startAutoSlide();
  }

  void _startAutoSlide() {
    _heroAutoSlideTimer?.cancel();
    _heroAutoSlideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      final songs = _latestSongs;
      if (!mounted || songs == null || songs.isEmpty) return;
      _heroPageIndex = (_heroPageIndex + 1) % songs.length;
      _heroPageController.animateToPage(
        _heroPageIndex,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= AppBreakpoints.desktop;
            final isTablet = constraints.maxWidth >= AppBreakpoints.tablet;
            return Column(
              children: [
                const InstallAppBanner(),
                Stack(
                  children: [
                    _heroBackdrop(),
                    _buildLatestSongsHero(context, isDesktop, isTablet),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const TodaysNewSongsCard(),
                const SizedBox(height: AppSpacing.xxxl),
                _buildStatsSection(context),
                const SizedBox(height: AppSpacing.xxxl),
                _buildArtistsPreviewSection(context, isDesktop, isTablet),
                const SizedBox(height: AppSpacing.xxxl),
                _buildFeaturesSection(context, isDesktop),
                const SizedBox(height: AppSpacing.xxxl),
                _buildInstallAppSection(context),
                const SizedBox(height: AppSpacing.xxxl),
                _buildCtaSection(context),
                const SizedBox(height: AppSpacing.xxxl),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openBook(BuildContext context) {
    context.go('/songbook');
  }

  // ---- Hero: latest-songs carousel ----------------------------------------
  //
  // Replaces the earlier "Most Popular Artists" hero — that duplicated
  // _buildArtistsPreviewSection's "Explore Artists" grid below (both were
  // artist-centric). This one is song-centric instead: real lyrics/chords
  // rendered through the same buildLyricLine() the reading screen uses, so
  // it also doubles as a preview of the actual product. "Latest" is
  // submission order (see _loadLatestSongs) — computed once in initState,
  // not rebuilt on every LayoutBuilder resize like _buildStatsSection's
  // future already guards against. Auto-advances via a Timer driving a
  // PageController, but still swipeable by hand since it's a real PageView.
  Widget _buildLatestSongsHero(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
  ) {
    final scheme = Theme.of(context).colorScheme;
    // "Full screen" here means filling the viewport below the persistent
    // Navbar (rendered by the shell above this screen, not part of this
    // widget's own height) rather than a small fixed-px card — 0.9 leaves
    // just enough visible margin that the stats strip below hints it's
    // scrollable.
    final heroHeight = MediaQuery.of(context).size.height * 0.9;
    final chromeHeight = isDesktop ? 220.0 : 190.0;
    final cardHeight = (heroHeight - chromeHeight).clamp(220.0, 900.0);
    final songs = _latestSongs;
    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 48 : 16,
          vertical: isDesktop ? 32 : 20,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Latest Songs',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isDesktop ? 32 : 24,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: cardHeight,
              width: double.infinity,
              child:
                  songs == null
                      ? const Center(child: CircularProgressIndicator())
                      : songs.isEmpty
                      ? _emptyLatestSongsFallback(scheme)
                      : PageView.builder(
                        controller: _heroPageController,
                        itemCount: songs.length,
                        onPageChanged:
                            (i) => setState(() => _heroPageIndex = i),
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            // The centered card sits at full scale; its
                            // peeking neighbors shrink slightly — a small
                            // "focus" cue that reads as a real carousel
                            // instead of a plain paginated list.
                            child: AnimatedBuilder(
                              animation: _heroPageController,
                              builder: (context, child) {
                                final page =
                                    _heroPageController.hasClients
                                        ? (_heroPageController.page ??
                                            index.toDouble())
                                        : index.toDouble();
                                final scale = (1 - (page - index).abs() * 0.12)
                                    .clamp(0.85, 1.0);
                                return Transform.scale(
                                  scale: scale,
                                  child: child,
                                );
                              },
                              child: _buildLatestSongCard(
                                context,
                                songs[index],
                                cardHeight,
                              ),
                            ),
                          );
                        },
                      ),
            ),
            if (songs != null && songs.length > 1) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < songs.length; i++)
                    _dot(
                      i == _heroPageIndex,
                      scheme,
                      _colorForArtist(
                        songs[i].artist.isNotEmpty
                            ? songs[i].artist
                            : songs[i].songName,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _openBook(context),
              child: const Text('တူၺ်းပပ်ႉၵႂၢမ်း'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyLatestSongsFallback(ColorScheme scheme) {
    return Center(
      child: Text(
        'No songs yet — be the first to contribute!',
        style: TextStyle(color: scheme.onSurface.withOpacity(0.5)),
      ),
    );
  }

  Widget _dot(bool active, ColorScheme scheme, Color accent) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: active ? 20 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? accent : scheme.onSurface.withOpacity(0.25),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // Deliberately bigger and more visually prominent than the small
  // _artistTile grid cards below (_buildArtistsPreviewSection) — this is
  // the hero now, so it needs to read as a step up, not just another tile.
  // All sizing derived from `height` rather than fixed breakpoint values,
  // so it scales smoothly as the viewport's height varies. Light card body
  // (not a full gradient fill) since buildLyricLine's chord color (fixed
  // blueAccent) needs a light background to read well — the color now
  // lives in the header bar and the glow shadow instead, keyed to the
  // song's own artist/band so each card in the carousel reads as visually
  // distinct rather than an identical plain white box. The previous
  // version's macOS-window-style traffic-light header and faint ruled-
  // notebook-paper texture behind the lyrics were removed — a user called
  // that background "just sitting there doing nothing."
  Widget _buildLatestSongCard(
    BuildContext context,
    _LatestSong song,
    double height,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _colorForArtist(
      song.artist.isNotEmpty ? song.artist : song.songName,
    );
    final previewLines = song.lyrics.take(6);
    final titleFontSize = (height * 0.06).clamp(18.0, 30.0);
    final artistFontSize = (height * 0.035).clamp(12.0, 18.0);
    final contentPadding = (height * 0.06).clamp(16.0, 40.0);
    final lyricFontScale = (height / 340).clamp(0.8, 1.4);
    final headerHeight = (height * 0.14).clamp(44.0, 64.0);
    return HoverScale(
      child: GestureDetector(
        onTap: () => context.go('/songbook/song/${song.id}'),
        child: Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.30),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: headerHeight,
                padding: EdgeInsets.symmetric(horizontal: contentPadding),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [accent, Color.lerp(accent, Colors.black, 0.3)!],
                  ),
                ),
                child: Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.waveSquare,
                      size: artistFontSize * 1.3,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'NEWEST',
                      style: TextStyle(
                        fontSize: artistFontSize * 0.85,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const Spacer(),
                    FaIcon(
                      FontAwesomeIcons.solidCirclePlay,
                      size: artistFontSize * 1.6,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(contentPadding),
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.songName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: titleFontSize,
                                color: scheme.onSurface,
                              ),
                            ),
                            if (song.artist.isNotEmpty)
                              Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: artistFontSize,
                                  fontWeight: FontWeight.w600,
                                  color: accent,
                                ),
                              ),
                            SizedBox(height: contentPadding * 0.5),
                            for (final lyric in previewLines)
                              buildLyricLine(
                                context,
                                lyric['content'] as List,
                                transposeSteps: 0,
                                fontScale: lyricFontScale,
                                textColor: scheme.onSurface,
                              ),
                          ],
                        ),
                      ),
                    ),
                    // A soft fade at the very bottom instead of an abrupt
                    // clip — the preview is deliberately cut off (only 6
                    // lines) since "tap to read the rest" is the point, and
                    // a hard edge there read as unfinished rather than
                    // intentional.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: contentPadding * 1.5,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                scheme.surface.withOpacity(0),
                                scheme.surface,
                              ],
                            ),
                          ),
                        ),
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

  // ---- Live stats strip ------------------------------------------------

  Widget _buildStatsSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        final loaded = snapshot.connectionState == ConnectionState.done;
        final songCount =
            (snapshot.data?[0] as AggregateQuerySnapshot?)?.count ?? 0;
        final artistCount =
            (snapshot.data?[1] as AggregateQuerySnapshot?)?.count ?? 0;
        final siteViewsData =
            (snapshot.data?[2] as DocumentSnapshot?)?.data()
                as Map<String, dynamic>?;
        final siteViews = (siteViewsData?['count'] as int?) ?? 0;
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 56,
          runSpacing: 24,
          children: [
            _statTile(
              scheme,
              loaded ? songCount : null,
              'Songs',
              _artistPalette[0],
            ),
            _statTile(
              scheme,
              loaded ? artistCount : null,
              'Artists',
              _artistPalette[3],
            ),
            _statTile(scheme, 4, 'Languages', _artistPalette[6]),
            _statTile(
              scheme,
              loaded ? siteViews : null,
              'Visits',
              _artistPalette[4],
            ),
          ],
        );
      },
    );
  }

  // Counts up from 0 to the real value once it's known (null means "still
  // loading" — shown as a plain dash, not an animated 0) rather than the
  // number just appearing — a cheap, classic "stats strip" touch. Restarts
  // naturally the first time `value` goes from null to non-null, since that
  // swaps in a brand-new TweenAnimationBuilder at this slot.
  Widget _statTile(ColorScheme scheme, int? value, String label, Color accent) {
    final valueStyle = TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.bold,
      color: accent,
    );
    return Column(
      children: [
        value == null
            ? Text('—', style: valueStyle)
            : TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.toDouble()),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder:
                  (context, animatedValue, child) =>
                      Text('${animatedValue.round()}', style: valueStyle),
            ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: scheme.onSurface.withOpacity(0.6),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ---- Artist preview grid ----------------------------------------------

  Widget _buildArtistsPreviewSection(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final crossAxisCount = isDesktop ? 6 : (isTablet ? 4 : 3);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader(
              scheme,
              'Explore Artists',
              'Browse the full songbook',
              () => _openBook(context),
            ),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('artists')
                      .limit(12)
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const SizedBox.shrink();
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemBuilder: (context, index) {
                    final artistData =
                        docs[index].data() as Map<String, dynamic>;
                    final name = artistData['name'] ?? '';
                    final photoUrl =
                        (artistData['photoUrl'] as String?)?.trim() ?? '';
                    return _artistTile(
                      scheme,
                      docs[index].id,
                      name,
                      photoUrl,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _artistTile(
    ColorScheme scheme,
    String artistId,
    String name,
    String photoUrl,
  ) {
    final color = _colorForArtist(name);
    return HoverScale(
      child: GestureDetector(
        onTap: () => context.go('/songbook/artist/$artistId'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient:
                      photoUrl.isEmpty
                          ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              color,
                              Color.lerp(color, Colors.black, 0.35)!,
                            ],
                          )
                          : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child:
                    photoUrl.isEmpty
                        ? FaIcon(
                          FontAwesomeIcons.recordVinyl,
                          color: Colors.white.withOpacity(0.9),
                          size: 32,
                        )
                        : CachedNetworkImage(
                          imageUrl: photoUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            // Every tile used to show the exact same generic music-note
            // icon with nothing to actually distinguish one artist from
            // another — this gives each card real per-artist data instead.
            // A count() aggregate query bills/reads far less than fetching
            // the matching song docs would, and 12 of them (one per tile
            // shown) is cheap enough for a homepage preview grid.
            FutureBuilder<AggregateQuerySnapshot>(
              future:
                  FirebaseFirestore.instance
                      .collection('songs')
                      .where('status', isEqualTo: 'approved')
                      .where('artistIds', arrayContains: artistId)
                      .count()
                      .get(),
              builder: (context, snapshot) {
                final count = snapshot.data?.count;
                if (count == null) return const SizedBox(height: 14);
                return Text(
                  count == 1 ? '1 song' : '$count songs',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurface.withOpacity(0.5),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---- Feature highlights -------------------------------------------

  Widget _buildFeaturesSection(BuildContext context, bool isDesktop) {
    final scheme = Theme.of(context).colorScheme;
    final features = [
      (
        FontAwesomeIcons.music,
        'Transpose & Auto-scroll',
        'Shift the key, resize the text, and let the lyrics scroll themselves while you play.',
      ),
      (
        FontAwesomeIcons.guitar,
        'Chord Diagrams',
        'Tap any chord to see exactly where to place your fingers.',
      ),
      (
        FontAwesomeIcons.peopleGroup,
        'Community Submissions',
        'Anyone can contribute a song — every submission is reviewed before it goes live.',
      ),
      (
        FontAwesomeIcons.solidStar,
        'Contributor Badges',
        'Earn bronze, silver, and gold recognition as your approved songs add up.',
      ),
    ];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          runSpacing: 20,
          children: [
            for (var i = 0; i < features.length; i++)
              SizedBox(
                width: isDesktop ? 240 : 300,
                child: _featureCard(
                  scheme,
                  features[i].$1,
                  features[i].$2,
                  features[i].$3,
                  _artistPalette[i % _artistPalette.length],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _featureCard(
    ColorScheme scheme,
    IconData icon,
    String title,
    String description,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.onSurface.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.onSurface.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: FaIcon(icon, size: 20, color: accent),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: scheme.onSurface.withOpacity(0.65),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Community CTA ------------------------------------------------

  // A permanent, always-in-the-page-flow install entry point — unlike
  // InstallAppBanner (dismissible, can vanish for good once closed), this
  // stays reachable for anyone who wants it later. Hides entirely once
  // already installed/launched standalone, since there's nothing left to
  // offer at that point.
  Widget _buildInstallAppSection(BuildContext context) {
    if (_installController.isStandalone) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_artistPalette[1], _artistPalette[2]],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _artistPalette[1].withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            const FaIcon(
              FontAwesomeIcons.mobileScreenButton,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 12),
            const Text(
              'Install the Paimorn App',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add it to your home screen for quick, app-like access — '
              'no app store needed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _artistPalette[1],
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _handleInstallTap(context),
              icon: const FaIcon(FontAwesomeIcons.download, size: 16),
              label: const Text('Download App'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleInstallTap(BuildContext context) async {
    if (_installController.isIOS) {
      _showInstallInstructions(
        context,
        'Tap the Share button below, then choose "Add to Home Screen".',
      );
      return;
    }
    if (_installController.canPromptInstall) {
      await _installController.promptInstall();
      if (mounted) setState(() {});
      return;
    }
    _showInstallInstructions(
      context,
      'Open your browser menu and choose "Install app" or '
      '"Add to Home screen".',
    );
  }

  void _showInstallInstructions(BuildContext context, String message) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Install this app'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Got it'),
              ),
            ],
          ),
    );
  }

  Widget _buildCtaSection(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // A vivid gradient instead of a flat black/white block — same two
    // palette colors the hero backdrop's blobs use, so this reads as the
    // "big finish" of the same color thread rather than a new one. White
    // text throughout since it's a fixed color background, not a theme
    // token, so it doesn't need to flip between light/dark mode.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_artistPalette[0], _artistPalette[3]],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _artistPalette[0].withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            const Text(
              'Have a song to share?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Submit the lyrics and chords — once approved, it joins the '
              'songbook for everyone.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _artistPalette[0],
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                // /submit-song is a real route now (guarded — falls back to
                // the Login screen itself if not signed in), rendered
                // inside the persistent shell, so it already has a real
                // Scaffold/Navbar/ScaffoldMessenger ancestor and a working
                // back button — no more need to push an ad-hoc
                // Scaffold-wrapped copy here.
                context.go('/submit-song');
              },
              child: Text(
                auth.isLoggedIn ? 'Submit a Song' : 'Login to Submit',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(
    ColorScheme scheme,
    String title,
    String actionLabel,
    VoidCallback onAction,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: scheme.onSurface),
          onPressed: onAction,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(actionLabel),
              const SizedBox(width: 4),
              const FaIcon(FontAwesomeIcons.arrowRight, size: 16),
            ],
          ),
        ),
      ],
    );
  }
}
