import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pai_morn_web/auth/auth_provider.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/utils/artist_palette.dart';
import 'package:pai_morn_web/utils/category_labels.dart';
import 'package:pai_morn_web/utils/gender_labels.dart';
import 'package:pai_morn_web/utils/recently_viewed_songs.dart';
import 'package:pai_morn_web/utils/youtube_link.dart';
import 'package:pai_morn_web/widget/app_search_field.dart';
import 'package:pai_morn_web/widget/favorite_button.dart';
import 'package:pai_morn_web/widget/submit_song_screen.dart';
import 'package:pai_morn_web/widget/hover_scale.dart';
import 'package:pai_morn_web/theme/app_theme.dart';

class BookScreen extends StatefulWidget {
  const BookScreen({super.key});

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> with TickerProviderStateMixin {
  String? selectedGender;
  String? selectedBand;
  // 'solo' | 'duet' | 'group' | null — derived from a song's artistIds
  // length (see _singerCountBucket), never asked for at submission time.
  String? selectedSingerCount;
  String? selectedCategory;
  // Display form already combines root + major/minor (e.g. "D", "Dm") —
  // see _keyDisplay in _buildFilterSidebar/_docMatchesActiveFilters.
  String? selectedKey;
  String? selectedEntityId;
  String? selectedEntityName;
  bool _allSongsMode = false;

  final TextEditingController _artistSearchController = TextEditingController();
  String _artistSearchQuery = '';
  final TextEditingController _allSongsSearchController =
      TextEditingController();
  String _allSongsSearchQuery = '';

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  final ScrollController _featuredScrollController = ScrollController();
  final ScrollController _popularScrollController = ScrollController();
  final ScrollController _recentlyViewedScrollController = ScrollController();
  // Desktop's content area and its 200px-wide filter sidebar (see
  // desktopBookScreen) are two side-by-side, independently-scrollable
  // regions by default — a user reported this as "can't scroll the whole
  // page," since a wheel scroll only ever moved whichever one the mouse
  // happened to be directly over. These four controllers, plus the
  // _wheelScrollListener wrapping the whole Row in desktopBookScreen, let
  // one wheel gesture anywhere across both columns move the sidebar and
  // whichever list is currently the visible one (grid/song list/All Songs)
  // together — each still independently clamped to its own scroll extent,
  // so a short list just stops early instead of over-scrolling.
  final ScrollController _gridScrollController = ScrollController();
  final ScrollController _songListScrollController = ScrollController();
  final ScrollController _allSongsScrollController = ScrollController();
  final ScrollController _sidebarScrollController = ScrollController();

  // Fetched once (not a live stream) — matches home_screen.dart's own
  // "_statsFuture"/"_loadLatestSongs" convention, since a "what's popular"
  // strip doesn't need to update the instant someone favorites a song.
  late final Future<List<QueryDocumentSnapshot>> _popularSongsFuture;
  // Same "fetched once, not live" reasoning as _popularSongsFuture — this
  // reflects local view history at the moment SongBook was opened, not a
  // running list. Since `/songbook` (main.dart) is a plain GoRoute (not a
  // StatefulShellRoute branch), navigating to a song and back rebuilds this
  // screen fresh each time, so the common "read a song, go back" flow still
  // shows the just-viewed song here without needing a live listener.
  late final Future<List<QueryDocumentSnapshot>> _recentlyViewedFuture;

  @override
  void initState() {
    super.initState();
    _setInitialSelection();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _popularSongsFuture = _loadPopularSongs();
    _recentlyViewedFuture = _loadRecentlyViewed();
  }

  // Firestore's documentId whereIn doesn't preserve the given order, so the
  // results are re-sorted back into most-recently-viewed-first order using
  // the id list itself (also drops any id whose song no longer exists,
  // e.g. deleted since it was last viewed).
  Future<List<QueryDocumentSnapshot>> _loadRecentlyViewed() async {
    final ids = await loadRecentlyViewedIds();
    if (ids.isEmpty) return [];
    final snap =
        await FirebaseFirestore.instance
            .collection('songs')
            .where(FieldPath.documentId, whereIn: ids)
            .get();
    final byId = {for (final doc in snap.docs) doc.id: doc};
    return [for (final id in ids) if (byId.containsKey(id)) byId[id]!];
  }

  // "Popular" = most-favorited. A client-side collectionGroup read across
  // every user's private favorites/ subcollection was the first approach
  // tried here, but firestore.rules correctly blocks it (each user's own
  // favorites list is private — a broad cross-user read can never satisfy
  // `request.auth.uid == userId` for every other user's docs) and it would
  // have exposed everyone's favorite lists to any visitor even if it were
  // allowed. Real fix: a denormalized `favoriteCount` field on the song
  // itself, maintained server-side by onFavoriteAdded/onFavoriteRemoved
  // (functions/index.js) — this is then just another public field on an
  // already-publicly-readable approved song, same as `songName`/`category`.
  Future<List<QueryDocumentSnapshot>> _loadPopularSongs() async {
    final snap =
        await FirebaseFirestore.instance
            .collection('songs')
            .where('status', isEqualTo: 'approved')
            .orderBy('favoriteCount', descending: true)
            .limit(10)
            .get();
    return snap.docs;
  }

  // "ลูกเล่น" (flair) touch — a low-effort way to discover something new in
  // the songbook without browsing. A fresh one-shot query at tap time
  // (rather than reusing whatever the grid happens to have loaded for the
  // current filter) so it always picks from the true full approved set,
  // independent of any active Gender/Band/Category filter or search text.
  bool _pickingRandomSong = false;

  Future<void> _openRandomSong() async {
    if (_pickingRandomSong) return;
    setState(() => _pickingRandomSong = true);
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('songs')
              .where('status', isEqualTo: 'approved')
              .get();
      if (snap.docs.isEmpty || !mounted) return;
      final doc = snap.docs[Random().nextInt(snap.docs.length)];
      if (!mounted) return;
      context.go('/songbook/song/${doc.id}');
    } finally {
      if (mounted) setState(() => _pickingRandomSong = false);
    }
  }

  Widget _randomSongButton() {
    final scheme = Theme.of(context).colorScheme;
    final language = context.watch<LocaleProvider>().currentLanguage;
    return Tooltip(
      message: AppTranslations.getText('randomSongLabel', language),
      child: InkWell(
        onTap: _openRandomSong,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.inverseSurface,
            shape: BoxShape.circle,
          ),
          child:
              _pickingRandomSong
                  ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onInverseSurface,
                    ),
                  )
                  : FaIcon(
                    FontAwesomeIcons.shuffle,
                    size: 20,
                    color: scheme.onInverseSurface,
                  ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _artistSearchController.dispose();
    _allSongsSearchController.dispose();
    _featuredScrollController.dispose();
    _popularScrollController.dispose();
    _recentlyViewedScrollController.dispose();
    _gridScrollController.dispose();
    _songListScrollController.dispose();
    _allSongsScrollController.dispose();
    _sidebarScrollController.dispose();
    super.dispose();
  }

  Future<void> _setInitialSelection() async {
    setState(() {
      selectedCategory = 'All';
      selectedGender = null;
    });
  }

  // "Entity" — a real artist (id is the artists/{id} doc ID) or a Band
  // (id is the synthetic "band:$bandName" key — see _entityIdsForDoc) — is
  // whatever the grid shows one card per. Selecting either works the same
  // way from here on: both eventually resolve to a song-list query in
  // _buildSongListView, which branches on the id's shape.
  void _selectEntity(String entityId, String entityName) {
    setState(() {
      selectedEntityId = entityId;
      selectedEntityName = entityName;
      _allSongsMode = false;
    });
    _slideController.forward(from: 0.0);
  }

  void _selectAllSongs() {
    setState(() {
      _allSongsMode = true;
      selectedEntityId = null;
      selectedEntityName = null;
    });
    _slideController.forward(from: 0.0);
  }

  // Reached from the "Edit" button that appears on song rows while an
  // admin has Edit Mode on (Navbar account menu) — opens the same form
  // used for new submissions, pre-filled, with its submit action turned
  // into "release" (see SubmitSongScreen.isEditing).
  void _openEditSong(String songId, Map<String, dynamic> data) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) =>
                SubmitSongScreen(editingSongId: songId, editingSongData: data),
      ),
    );
  }

  // Steps back one level at a time: song list -> artist grid. Reading a
  // song is no longer a level of this screen's own state at all — it's a
  // separate pushed route (SongReaderScreen via /songbook/song/:id) with
  // its own back button. Used by the narrow-screen AppBar's back arrow.
  void _goBackOneLevel() {
    setState(() {
      if (selectedEntityId != null) {
        selectedEntityId = null;
        selectedEntityName = null;
      } else if (_allSongsMode) {
        _allSongsMode = false;
      }
    });
  }

  Widget _buildContentArea({bool hideArtistOverlay = false}) {
    // Only ever show approved songs on the public site — Phase C's
    // migration already backfilled status: 'approved' onto every
    // pre-existing doc, so this can't silently hide anything that used to
    // be visible. Category is deliberately NOT applied here anymore — it's
    // only selectable inside the "All Songs" view now.
    // Gender/Band/Singers all filter client-side now (see
    // _docMatchesActiveFilters) rather than as server .where() clauses —
    // Singers can't be a Firestore filter at all (it's derived from
    // artistIds.length, and Firestore has no array-length query), so once
    // that needed client-side filtering anyway, Gender/Band moved alongside
    // it for one consistent filtering path used by the artist grid, the
    // per-artist song list, and the All Songs view alike.
    final Query approvedSongsQuery = FirebaseFirestore.instance
        .collection('songs')
        .where('status', isEqualTo: 'approved');
    final hasGenderFilter = selectedGender != null && selectedGender != 'All';
    final hasBandFilter = selectedBand != null && selectedBand != 'All';
    final hasSingerFilter =
        selectedSingerCount != null && selectedSingerCount != 'All';
    final hasCategoryFilter =
        selectedCategory != null && selectedCategory != 'All';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('artists').snapshots(),
      builder: (context, artistSnapshot) {
        if (!artistSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final artistDocs = artistSnapshot.data!.docs;
        final artistNames = <String, String>{
          for (final doc in artistDocs)
            doc.id: (doc.data() as Map<String, dynamic>)['name'] ?? '',
        };

        // Every approved song, unfiltered — used to compute the grid's
        // entities (_entityDisplayNames — an "entity" is either a real
        // artist or a Band, see _entityIdsForDoc), per-entity song counts
        // (_entitySongCounts), and — when a Gender/Band/Singers filter is
        // active — which entities have >=1 matching song (those fields
        // live on song docs, not artist docs, so narrowing the grid means
        // scanning songs). One shared snapshot for all three instead of a
        // separate query per concern.
        return StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('songs')
                  .where('status', isEqualTo: 'approved')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
          builder: (context, allApprovedSnapshot) {
            if (!allApprovedSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final allApprovedDocs = allApprovedSnapshot.data!.docs;
            final entityNames = _entityDisplayNames(
              artistNames,
              allApprovedDocs,
            );
            final songCounts = _entitySongCounts(allApprovedDocs);

            var visibleEntityIds = entityNames.keys.toSet();
            if (hasGenderFilter ||
                hasBandFilter ||
                hasSingerFilter ||
                hasCategoryFilter) {
              final matchingEntityIds = <String>{};
              for (final doc in allApprovedDocs) {
                final data = doc.data() as Map<String, dynamic>;
                if (!_docMatchesActiveFilters(
                  data,
                  hasGenderFilter: hasGenderFilter,
                  hasBandFilter: hasBandFilter,
                  hasSingerFilter: hasSingerFilter,
                  hasCategoryFilter: hasCategoryFilter,
                )) {
                  continue;
                }
                matchingEntityIds.addAll(_entityIdsForDoc(data));
              }
              visibleEntityIds = matchingEntityIds;
            }

            return _buildArtistAndSongsStack(
              entityNames,
              visibleEntityIds,
              songCounts,
              approvedSongsQuery,
              hideArtistOverlay,
              // allApprovedDocs is already orderBy(createdAt, descending) —
              // the first 10 are exactly "10 newest approved songs," no
              // second query needed. Always the true newest regardless of
              // any active Gender/Band/Singer/Category filter — a fixed
              // "what's new" strip, not filtered content.
              allApprovedDocs.take(10).toList(),
            );
          },
        );
      },
    );
  }

  // Combines the two raw fields (`key` root + `keyIsMinor`) into the one
  // display/comparison string used everywhere a key is shown or filtered —
  // "D" for major, "Dm" for minor. Null/empty root means the song predates
  // the key field (see submit_song_screen.dart) and just has no key set.
  String? _keyDisplay(Map<String, dynamic> data) {
    final root = (data['key'] as String?)?.trim();
    if (root == null || root.isEmpty) return null;
    return (data['keyIsMinor'] as bool? ?? false) ? '${root}m' : root;
  }

  bool _docMatchesActiveFilters(
    Map<String, dynamic> data, {
    required bool hasGenderFilter,
    required bool hasBandFilter,
    required bool hasSingerFilter,
    required bool hasCategoryFilter,
    bool hasKeyFilter = false,
  }) {
    // Normalized before comparing — a doc still holding a pre-migration raw
    // gender value (see gender_labels.dart) would otherwise never match
    // `selectedGender`, which always comes from the normalized set built
    // for the sidebar/dropdown.
    if (hasGenderFilter &&
        normalizeGenderValue(data['gender'] as String?) != selectedGender) {
      return false;
    }
    if (hasBandFilter && data['band'] != selectedBand) return false;
    if (hasSingerFilter && _singerCountBucket(data) != selectedSingerCount) {
      return false;
    }
    // Same normalization reasoning as gender — see category_labels.dart.
    if (hasCategoryFilter &&
        normalizeCategoryValue(data['category'] as String?) !=
            selectedCategory) {
      return false;
    }
    if (hasKeyFilter && _keyDisplay(data) != selectedKey) return false;
    return true;
  }

  // Solo (1 credited artist) / Duet (2) / Group (3+) — derived from
  // artistIds.length so it can never drift out of sync with how many
  // artists a song actually credits, instead of being a separate field a
  // submitter has to remember to set correctly.
  String _singerCountBucket(Map<String, dynamic> data) {
    final count = ((data['artistIds'] as List?) ?? const []).length;
    if (count <= 1) return 'solo';
    if (count == 2) return 'duet';
    return 'group';
  }

  // The browsing "entity" (or entities) an approved song belongs to on the
  // SongBook grid. A song with a Band set belongs to exactly ONE entity —
  // that Band's shared card (id "band:$bandName"), merging every artist
  // who's ever recorded under it — e.g. an album with 10 songs by 10
  // different singers still reads as one browsable act instead of 10
  // near-identical cards each showing just that one album's name. A song
  // with no Band belongs to each of its own artistIds, same as always. An
  // artist who only ever appears on Band songs never gets their own
  // fragment of a card this way — they show up solely via the Band's card,
  // which is the whole point (see the real bug this fixed: two different
  // singers on the same "Sumai" album each getting their own "Sumai"-
  // labeled card, reading as an accidental duplicate).
  List<String> _entityIdsForDoc(Map<String, dynamic> data) {
    final band = (data['band'] as String?)?.trim() ?? '';
    if (band.isNotEmpty) return ['band:$band'];
    return (data['artistIds'] as List?)?.cast<String>() ?? const [];
  }

  String _entityDisplayNameFor(
    String entityId,
    Map<String, String> artistNames,
  ) {
    final band = entityId.startsWith('band:') ? entityId.substring(5) : null;
    return band ?? artistNames[entityId] ?? '';
  }

  // Every entity with at least one approved song, and its display name —
  // an artist's own `artists/{id}.name` for a real-artist entity, or the
  // band text itself for a Band entity. An artist with zero qualifying
  // songs (all their songs are Band songs, or they have none approved at
  // all) simply never appears here, which also happens to fix an old known
  // gap where a brand-new artist showed an empty-feeling card the moment
  // they were created, before their first song was ever approved.
  Map<String, String> _entityDisplayNames(
    Map<String, String> artistNames,
    List<QueryDocumentSnapshot> approvedSongDocs,
  ) {
    final names = <String, String>{};
    for (final doc in approvedSongDocs) {
      final data = doc.data() as Map<String, dynamic>;
      for (final id in _entityIdsForDoc(data)) {
        names.putIfAbsent(id, () => _entityDisplayNameFor(id, artistNames));
      }
    }
    return names;
  }

  // How many approved songs each entity has — shown on the grid card so a
  // browser knows what they're getting into before tapping in.
  Map<String, int> _entitySongCounts(
    List<QueryDocumentSnapshot> approvedSongDocs,
  ) {
    final counts = <String, int>{};
    for (final doc in approvedSongDocs) {
      final data = doc.data() as Map<String, dynamic>;
      for (final id in _entityIdsForDoc(data)) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    return counts;
  }

  Widget _buildArtistAndSongsStack(
    Map<String, String> entityNames,
    Set<String> visibleEntityIds,
    Map<String, int> songCounts,
    Query approvedSongsQuery,
    bool hideArtistOverlay,
    List<QueryDocumentSnapshot> newestDocs,
  ) {
    final language = context.watch<LocaleProvider>().currentLanguage;
    final searchQuery = _artistSearchQuery.trim().toLowerCase();
    final entityIdList =
        visibleEntityIds
            .where(
              (id) =>
                  searchQuery.isEmpty ||
                  (entityNames[id] ?? '').toLowerCase().contains(searchQuery),
            )
            .toList()
          ..sort(
            (a, b) => (entityNames[a] ?? '').compareTo(entityNames[b] ?? ''),
          );

    // Only on the desktop layout: the narrow layout already has an AppBar
    // showing "All Artists"/"All Songs"/the entity name (see
    // _narrowBookScreen), so this heading would just repeat that in less
    // space. Desktop's content area had no title of its own at all before.
    final isDesktop =
        MediaQuery.of(context).size.width >= AppBreakpoints.desktop;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Heading, the "Newest Songs" featured row, the search field, and
        // the grid all scroll away together as one unit now — a user
        // reported the featured row as permanently pinned in place ("ค้าง
        // อยู่...เกะกะ", eating screen space that could show more of the
        // grid) and asked for it to scroll with everything else instead,
        // same as how every other page on this site behaves. The grid
        // itself no longer owns its own scrolling (see _artistGridView's
        // shrinkWrap/NeverScrollableScrollPhysics) — this SingleChildScrollView
        // does, using the same _gridScrollController the desktop Row-wide
        // Listener in desktopBookScreen already drives, so cross-sidebar
        // scroll sync (see that method's own comment) keeps working
        // unchanged.
        SingleChildScrollView(
          controller: _gridScrollController,
          physics:
              isDesktop
                  ? const NeverScrollableScrollPhysics()
                  : const AlwaysScrollableScrollPhysics(),
          child: AnimatedOpacity(
            opacity: (selectedEntityId == null && !_allSongsMode) ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isDesktop)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 5,
                          height: 30,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [_artistPalette[0], _artistPalette[3]],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          AppTranslations.getText('songbook', language),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                FutureBuilder<List<QueryDocumentSnapshot>>(
                  future: _recentlyViewedFuture,
                  builder: (context, snapshot) {
                    final recentDocs = snapshot.data ?? const [];
                    if (recentDocs.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildFeaturedRow(
                        recentDocs,
                        language,
                        'recentlyViewedLabel',
                        _recentlyViewedScrollController,
                      ),
                    );
                  },
                ),
                if (newestDocs.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildFeaturedRow(
                      newestDocs,
                      language,
                      'newestSongsLabel',
                      _featuredScrollController,
                    ),
                  ),
                FutureBuilder<List<QueryDocumentSnapshot>>(
                  future: _popularSongsFuture,
                  builder: (context, snapshot) {
                    final popularDocs = snapshot.data ?? const [];
                    if (popularDocs.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildFeaturedRow(
                        popularDocs,
                        language,
                        'popularSongsLabel',
                        _popularScrollController,
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _searchField(
                          controller: _artistSearchController,
                          hintText: 'Search artist or band...',
                          onChanged:
                              (v) => setState(() => _artistSearchQuery = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _randomSongButton(),
                    ],
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Mobile used to get only 2 (very wide) columns here — a
                    // real user found the resulting cards oversized/clunky on
                    // a phone screen. 3 columns fits comfortably down to
                    // ~350px-wide phones (every _buildArtistCard element
                    // scales off the card's own width, so text/icon shrink
                    // proportionally with it) and reads as a denser, more
                    // "app-like" grid instead of a couple of oversized tiles.
                    // Note: `constraints` here is already inside this
                    // screen's own 16px body padding on each side, so this
                    // threshold is ~32px lower than the actual device width
                    // it's meant to catch (e.g. a 390px-wide phone arrives
                    // here as ~358px).
                    final crossAxisCount =
                        constraints.maxWidth >= AppBreakpoints.desktop
                            ? 4
                            : constraints.maxWidth >= 320
                            ? 3
                            : 2;
                    return _artistGridView(
                      entityIdList,
                      entityNames,
                      songCounts,
                      language,
                      crossAxisCount,
                      constraints.maxWidth,
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        if (!hideArtistOverlay &&
            selectedEntityId != null &&
            entityNames.containsKey(selectedEntityId))
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            left: 0,
            top: 0,
            width: 100,
            height: 150,
            child: _backTappableCard(
              _buildSelectedArtistCard(
                entityNames[selectedEntityId]!,
                subtitle: _songsCountLabel(
                  songCounts[selectedEntityId] ?? 0,
                  language,
                ),
              ),
            ),
          ),

        if (!hideArtistOverlay && _allSongsMode)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            left: 0,
            top: 0,
            width: 100,
            height: 150,
            child: _backTappableCard(
              _buildAllSongsCard(width: 100, height: 150),
            ),
          ),

        if (selectedEntityId != null)
          SlideTransition(
            position: _slideAnimation,
            child: _buildSongListView(
              approvedSongsQuery,
              leftPadding: hideArtistOverlay ? 0 : 120,
              isDesktop: !hideArtistOverlay,
            ),
          ),

        if (_allSongsMode)
          SlideTransition(
            position: _slideAnimation,
            child: _buildAllSongsView(
              approvedSongsQuery,
              leftPadding: hideArtistOverlay ? 0 : 120,
              isDesktop: !hideArtistOverlay,
            ),
          ),
      ],
    );
  }

  // The root browsing screen's discovery hooks — real content instead of
  // only a picking grid. Shared by both "Newest Songs" (10 most recently
  // approved, independent of any active filter) and "Popular Songs" (10
  // most-favorited, see _loadPopularSongs).
  Widget _buildFeaturedRow(
    List<QueryDocumentSnapshot> docs,
    String language,
    String headingKey,
    ScrollController scrollController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppTranslations.getText(headingKey, language),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 190,
          // A plain vertical mouse-wheel over a horizontal ListView does
          // nothing by default in Flutter (only an explicit horizontal
          // wheel/trackpad gesture scrolls it) — confirmed via testing that
          // this made the row feel completely stuck to a normal mouse user,
          // which is exactly the "can't scroll" bug reported. Translating
          // vertical wheel delta into horizontal scroll here matches how
          // most web carousels already behave for a plain mouse.
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent &&
                  scrollController.hasClients) {
                final target = (scrollController.offset +
                        event.scrollDelta.dy)
                    .clamp(0.0, scrollController.position.maxScrollExtent);
                scrollController.jumpTo(target);
              }
            },
            child: ListView.separated(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _featuredSongCard(docs[index]),
            ),
          ),
        ),
      ],
    );
  }

  // Same "no real photos" visual language as _buildArtistCard — a YouTube
  // thumbnail when the song has one (falls back below on any load failure,
  // e.g. a bad link or a removed video), otherwise straight to the flat
  // gradient/icon card. Never falls back to a person's likeness either way.
  Widget _featuredSongCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final songName = (data['songName'] as String?) ?? '';
    final artist = (data['artist'] as String?)?.trim() ?? '';
    final videoId = extractYoutubeVideoId((data['youtubeLink'] as String?) ?? '');

    Widget fallbackArt() => Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _colorForArtist(songName),
            Color.lerp(_colorForArtist(songName), Colors.black, 0.35)!,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: const FaIcon(
        FontAwesomeIcons.music,
        color: Colors.white,
        size: 40,
      ),
    );

    return SizedBox(
      width: 140,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => context.go('/songbook/song/${doc.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                width: 140,
                height: 140,
                child:
                    videoId == null
                        ? fallbackArt()
                        : Image.network(
                          'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => fallbackArt(),
                        ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              songName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            if (artist.isNotEmpty)
              Text(
                artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Wraps the floating "selected artist/band" or "All Songs" cover — shown
  // in place of the grid while its song list is open — so tapping it also
  // works as a back button. Previously this card was purely decorative;
  // on desktop (which has no AppBar/back-arrow, unlike the narrow layout's
  // _goBackOneLevel-driven leading icon) there was no way at all to return
  // to the artist grid short of leaving the page and coming back. A small
  // circular back-arrow badge overlaps the top-left corner so the
  // affordance is visible, not just discoverable by trial-and-error hover.
  Widget _backTappableCard(Widget card) {
    final scheme = Theme.of(context).colorScheme;
    return HoverScale(
      child: GestureDetector(
        onTap: _goBackOneLevel,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            card,
            Positioned(
              top: -8,
              left: -8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.subtle(Colors.black),
                ),
                child: FaIcon(
                  FontAwesomeIcons.arrowLeft,
                  size: 16,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // One icon + color per preset category (category_labels.dart) so the
  // filter sidebar's Category section reads at a glance instead of as plain
  // text chips — colors reused from the same _artistPalette rather than a
  // second palette. A custom "Other" category (free text, no preset entry)
  // falls back to a neutral label icon/color.
  IconData _categoryIconFor(String value) {
    switch (value) {
      case categoryDhamma:
        return FontAwesomeIcons.spa;
      case categoryTradition:
        return FontAwesomeIcons.landmark;
      case categoryLove:
        return FontAwesomeIcons.solidHeart;
      case categoryPolitics:
        return FontAwesomeIcons.checkToSlot;
      case categoryLife:
        return FontAwesomeIcons.leaf;
      default:
        return FontAwesomeIcons.tag;
    }
  }

  Color _categoryColorFor(String value) {
    switch (value) {
      case categoryDhamma:
        return const Color(0xFFD4A017);
      case categoryTradition:
        return _artistPalette[2];
      case categoryLove:
        return _artistPalette[5];
      case categoryPolitics:
        return _artistPalette[3];
      case categoryLife:
        return _artistPalette[1];
      default:
        // A fixed neutral rather than a theme-derived color (e.g.
        // scheme.onSurface) — this app's dark theme's onSurface reads
        // near-white, which would make the selected tile's white
        // checkmark/text unreadable against it.
        return const Color(0xFF636E72);
    }
  }

  // Shared with home_screen.dart and song_reader_screen.dart (see
  // utils/artist_palette.dart) — same palette + hash everywhere is what
  // makes an artist/band's color read as one consistent identity across
  // the whole app instead of three independently-colored copies.
  static const List<Color> _artistPalette = artistPalette;

  Color _colorForArtist(String name) => colorForArtist(name);

  // Flat gradient card — same visual language as about_screen.dart's
  // contributor cards (same colorForArtist hash, same black-lerp-0.35
  // darkening for the gradient's second stop, same AppShadows.subtle/
  // AppRadius.lg), replacing an earlier skeuomorphic "physical book" look
  // (page-stack, spine, gloss streak) a user flagged as feeling dated next
  // to the rest of the redesigned site. Deliberately never a real photo —
  // just color + a monogram/icon badge, generated from the name alone, so
  // there's nothing here that could ever be an actual person's likeness.
  // Reused by the artist grid (all breakpoints), the floating "selected
  // artist" card, and _buildAllSongsCard.
  Widget _buildArtistCard(
    String displayName, {
    double width = 150,
    double height = 200,
    Color? colorOverride,
    IconData icon = FontAwesomeIcons.recordVinyl,
    String subtitle = 'Lyrics & Chords',
    // A big bold initial (the way Spotify/Apple Music cover a real artist
    // with no photo yet) gives each card its own identity for free, with
    // zero new data. Left off for the "All Songs" card (see
    // _buildAllSongsCard), which isn't a name an initial would mean
    // anything for — it keeps its own icon.
    bool useMonogram = false,
  }) {
    final baseColor = colorOverride ?? _colorForArtist(displayName);
    final deepColor = Color.lerp(baseColor, Colors.black, 0.35)!;
    final trimmedName = displayName.trim();
    final monogram =
        trimmedName.isEmpty ? '?' : trimmedName.substring(0, 1).toUpperCase();
    final badgeSize = width * 0.42;

    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [baseColor, deepColor],
          ),
          boxShadow: AppShadows.subtle(Colors.black),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: width * 0.08,
          vertical: height * 0.06,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: badgeSize,
              height: badgeSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.18),
              ),
              child:
                  useMonogram
                      ? Text(
                        monogram,
                        style: TextStyle(
                          fontSize: badgeSize * 0.5,
                          height: 1.0,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      )
                      : Icon(icon, size: badgeSize * 0.5, color: Colors.white),
            ),
            SizedBox(height: height * 0.06),
            Text(
              displayName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: width * 0.11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(height: height * 0.02),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: width * 0.07,
                letterSpacing: 0.3,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // "All Songs" reuses the artist-card visuals (via _buildArtistCard's
  // color/icon/subtitle overrides) so it reads as a natural first "cover" in
  // the artist grid rather than a bolted-on control.
  Widget _buildAllSongsCard({double width = 150, double height = 200}) {
    return _buildArtistCard(
      'All Songs',
      width: width,
      height: height,
      colorOverride: const Color(0xFF2D3436),
      icon: FontAwesomeIcons.listOl,
      subtitle: 'Every Song',
    );
  }

  // Single grid used at every breakpoint; only crossAxisCount changes. Index
  // 0 is always the "All Songs" card, followed by the (possibly
  // search/gender-filtered) artist list.
  Widget _artistGridView(
    List<String> entityIdList,
    Map<String, String> entityNames,
    Map<String, int> songCounts,
    String language,
    int crossAxisCount,
    double maxWidth,
  ) {
    final isGridVisible = selectedEntityId == null && !_allSongsMode;
    // _buildArtistCard sizes its icon/monogram/text off the width/height
    // passed in, not off whatever box it actually ends up laid out in — so
    // callers inside a grid must hand it the real per-tile size, or the
    // content is sized for the 150x200 default and looks oversized/cramped
    // once the grid packs more (smaller) columns on narrow screens.
    const spacing = 18.0;
    final cellWidth =
        (maxWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;
    final cellHeight = cellWidth * 4 / 3;
    return AnimatedOpacity(
      opacity: isGridVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      child: GridView.builder(
        // This no longer owns scrolling at all — it's laid out at its
        // natural content height (shrinkWrap) inside the outer
        // SingleChildScrollView built in _buildArtistAndSongsStack, which
        // is what actually scrolls (see that method's own comment for why).
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: entityIdList.length + 1,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: 3 / 4,
        ),
        itemBuilder: (context, index) {
          if (index == 0) {
            return GestureDetector(
              onTap: _selectAllSongs,
              child: _buildAllSongsCard(width: cellWidth, height: cellHeight),
            );
          }
          final entityId = entityIdList[index - 1];
          final displayName = entityNames[entityId] ?? '';
          return HoverScale(
            child: GestureDetector(
              onTap: () => _selectEntity(entityId, displayName),
              child: _buildArtistCard(
                displayName,
                width: cellWidth,
                height: cellHeight,
                subtitle: _songsCountLabel(songCounts[entityId] ?? 0, language),
                useMonogram: true,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedArtistCard(String displayName, {String? subtitle}) {
    return _buildArtistCard(
      displayName,
      width: 100,
      height: 150,
      subtitle: subtitle ?? 'Lyrics & Chords',
      useMonogram: true,
    );
  }

  // Only English marks singular/plural — Shan and Burmese use the same word
  // regardless of count, so the singular key only needs an 'en' entry
  // (see l10n.dart) and this check is harmless elsewhere.
  String _songsCountLabel(int count, String language) {
    final key =
        count == 1 && language == 'en'
            ? 'songCountLabelSingular'
            : 'songsCountLabel';
    return AppTranslations.getText(
      key,
      language,
    ).replaceFirst('{count}', '$count');
  }

  // Shared by _buildSongListView and _buildAllSongsView — a colored music-
  // note badge plus a colored left accent stripe replace the old plain
  // title-and-chevron row, so each song's card visually ties back to the
  // artist/band cover it belongs to (same `accentColor`) instead of every
  // row in the app looking identical regardless of context.
  Widget _songRow({
    required String songId,
    required String songName,
    required String? subtitle,
    required Color accentColor,
    required Color textColor,
    required bool editModeEnabled,
    required VoidCallback onEdit,
    required VoidCallback onTap,
  }) {
    return HoverScale(
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Container(width: 5, color: accentColor),
              Expanded(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: accentColor.withOpacity(0.15),
                    child: FaIcon(FontAwesomeIcons.music, color: accentColor),
                  ),
                  title: Text(
                    songName,
                    style: TextStyle(
                      fontSize: 18,
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle:
                      subtitle == null || subtitle.isEmpty
                          ? null
                          : Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor.withOpacity(0.6),
                              fontSize: 13,
                            ),
                          ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FavoriteButton(
                        songId: songId,
                        size: 20,
                        color: textColor,
                      ),
                      if (editModeEnabled)
                        IconButton(
                          icon: FaIcon(FontAwesomeIcons.penToSquare, color: textColor, size: 18),
                          tooltip: 'Edit',
                          onPressed: onEdit,
                        ),
                      FaIcon(FontAwesomeIcons.angleRight, color: textColor, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongListView(
    Query songsQuery, {
    required double leftPadding,
    required bool isDesktop,
  }) {
    final textColor = Theme.of(context).colorScheme.onPrimary;
    final language = context.watch<LocaleProvider>().currentLanguage;
    // Every song in this list belongs to the same selected artist/band, so
    // one shared accent color (matching that entity's grid cover) ties the
    // whole list together instead of varying per row.
    final accentColor = _colorForArtist(selectedEntityName ?? '');
    final editModeEnabled = context.watch<AuthProvider>().editModeEnabled;
    final hasGenderFilter = selectedGender != null && selectedGender != 'All';
    final hasBandFilter = selectedBand != null && selectedBand != 'All';
    final hasSingerFilter =
        selectedSingerCount != null && selectedSingerCount != 'All';
    final hasCategoryFilter =
        selectedCategory != null && selectedCategory != 'All';
    // A "band:" entity id (see _entityIdsForDoc) selects by the raw `band`
    // field instead of `artistIds` — every song sharing that exact Band
    // text belongs to this one entity regardless of which artist sang it.
    final entityId = selectedEntityId ?? '';
    final entityQuery =
        entityId.startsWith('band:')
            ? songsQuery.where('band', isEqualTo: entityId.substring(5))
            : songsQuery.where('artistIds', arrayContains: entityId);
    return Padding(
      padding: EdgeInsets.only(left: leftPadding),
      child: StreamBuilder<QuerySnapshot>(
        stream: entityQuery.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          // Gender/Band/Singers/Category all applied client-side here — see
          // the comment on approvedSongsQuery in _buildContentArea for why.
          final docs =
              snapshot.data!.docs.where((doc) {
                return _docMatchesActiveFilters(
                  doc.data() as Map<String, dynamic>,
                  hasGenderFilter: hasGenderFilter,
                  hasBandFilter: hasBandFilter,
                  hasSingerFilter: hasSingerFilter,
                  hasCategoryFilter: hasCategoryFilter,
                );
              }).toList();
          return ListView.builder(
            // เปลี่ยนจาก GridView.builder เป็น ListView.builder
            controller: _songListScrollController,
            physics:
                isDesktop
                    ? const NeverScrollableScrollPhysics()
                    : const AlwaysScrollableScrollPhysics(),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final songName = data['songName'] ?? 'No Name';
              final category = normalizeCategoryValue(
                data['category'] as String?,
              );
              return _songRow(
                songId: doc.id,
                songName: songName,
                subtitle:
                    category == null
                        ? null
                        : categoryDisplayLabel(category, language),
                accentColor: accentColor,
                textColor: textColor,
                editModeEnabled: editModeEnabled,
                onEdit: () => _openEditSong(doc.id, data),
                onTap: () => context.go('/songbook/song/${doc.id}'),
              );
            },
          );
        },
      ),
    );
  }

  // The "All Songs" view: every approved song across every artist, with a
  // Category chip filter (Category lost its sidebar slot in this redesign,
  // so it lives here instead) and a search box matching either song name or
  // category name. Filtering (Category, Gender/Band/Singers, and search) all
  // happens client-side on the already-loaded snapshot — Category and the
  // search box because Firestore can't substring-match, Gender/Band/Singers
  // because approvedSongsQuery no longer applies them server-side (see the
  // comment on it in _buildContentArea).
  Widget _buildAllSongsView(
    Query approvedSongsQuery, {
    required double leftPadding,
    required bool isDesktop,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textColor = scheme.onPrimary;
    final editModeEnabled = context.watch<AuthProvider>().editModeEnabled;
    final language = context.watch<LocaleProvider>().currentLanguage;
    final hasGenderFilter = selectedGender != null && selectedGender != 'All';
    final hasBandFilter = selectedBand != null && selectedBand != 'All';
    final hasSingerFilter =
        selectedSingerCount != null && selectedSingerCount != 'All';
    final hasCategoryFilter =
        selectedCategory != null && selectedCategory != 'All';
    final hasKeyFilter = selectedKey != null && selectedKey != 'All';
    return Padding(
      padding: EdgeInsets.only(left: leftPadding),
      child: StreamBuilder<QuerySnapshot>(
        stream: approvedSongsQuery.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          // Category is now applied here too (see _docMatchesActiveFilters)
          // instead of a second, separate filter pass — it moved into the
          // shared filter sidebar alongside Gender/Band/Singers. Key only
          // ever applies here (not the artist grid/per-artist list) — an
          // artist's songs routinely span several keys, so narrowing by key
          // only makes sense for a flat song search, not artist browsing.
          final allDocs =
              snapshot.data!.docs.where((doc) {
                return _docMatchesActiveFilters(
                  doc.data() as Map<String, dynamic>,
                  hasGenderFilter: hasGenderFilter,
                  hasBandFilter: hasBandFilter,
                  hasSingerFilter: hasSingerFilter,
                  hasCategoryFilter: hasCategoryFilter,
                  hasKeyFilter: hasKeyFilter,
                );
              }).toList();

          final query = _allSongsSearchQuery.trim().toLowerCase();
          final filteredDocs =
              allDocs.where((doc) {
                if (query.isEmpty) return true;
                final data = doc.data() as Map<String, dynamic>;
                final category =
                    normalizeCategoryValue(data['category'] as String?) ?? '';
                final songName = (data['songName'] ?? '').toString();
                return songName.toLowerCase().contains(query) ||
                    category.toLowerCase().contains(query);
              }).toList();

          // Every distinct key among ALL approved songs (not just the
          // currently-filtered subset) — same "stable chip list" approach
          // _buildFilterSidebar uses for Category/Gender/Band, so picking a
          // key doesn't also reshuffle which other keys are offered.
          final keySet = <String>{};
          for (final doc in snapshot.data!.docs) {
            final display = _keyDisplay(doc.data() as Map<String, dynamic>);
            if (display != null) keySet.add(display);
          }
          final keyList = keySet.toList()..sort();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _searchField(
                  controller: _allSongsSearchController,
                  hintText: 'Search song or category...',
                  onChanged: (v) => setState(() => _allSongsSearchQuery = v),
                ),
              ),
              if (keyList.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              AppTranslations.getText('allOption', language),
                            ),
                            selected: !hasKeyFilter,
                            onSelected:
                                (_) => setState(() => selectedKey = null),
                          ),
                        ),
                        for (final key in keyList)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(key),
                              selected: selectedKey == key,
                              onSelected:
                                  (_) => setState(() => selectedKey = key),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: _allSongsScrollController,
                  physics:
                      isDesktop
                          ? const NeverScrollableScrollPhysics()
                          : const AlwaysScrollableScrollPhysics(),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final songName = data['songName'] ?? 'No Name';
                    final artist = (data['artist'] as String?)?.trim() ?? '';
                    final category = normalizeCategoryValue(
                      data['category'] as String?,
                    );
                    // Spans every artist, so each row's accent (and its
                    // subtitle) is derived per-row instead of a single
                    // shared color — the same color an artist/band's own
                    // grid cover uses, so a browser can visually connect a
                    // row here back to its cover if they've seen it before.
                    final subtitleParts = [
                      if (artist.isNotEmpty) artist,
                      if (category != null)
                        categoryDisplayLabel(category, language),
                    ];
                    return _songRow(
                      songId: doc.id,
                      songName: songName,
                      subtitle:
                          subtitleParts.isEmpty
                              ? null
                              : subtitleParts.join(' • '),
                      accentColor: _colorForArtist(artist),
                      textColor: textColor,
                      editModeEnabled: editModeEnabled,
                      onEdit: () => _openEditSong(doc.id, data),
                      onTap: () => context.go('/songbook/song/${doc.id}'),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _searchField({
    required TextEditingController controller,
    required String hintText,
    required ValueChanged<String> onChanged,
  }) {
    return AppSearchField(
      controller: controller,
      hintText: hintText,
      onChanged: onChanged,
    );
  }

  // Filter sidebar — Category now leads (see the note on
  // _categoryIconFor/_categoryColorFor below), followed by Gender, Band,
  // and Singer count, all combining together (AND) via
  // _docMatchesActiveFilters. Category used to be confined to its own chip
  // row inside the All Songs view, with a deliberately separate section
  // here for just Gender/Band — a real user was confused early on when a
  // generic "Category" heading here turned out to mean Gender, not the
  // actual Dhamma/Tradition/Love/Politics/Life feature. Giving Category its
  // own clearly-labeled, icon-per-value section (instead of a vague shared
  // umbrella header) resolves that same confusion while still unifying it
  // into one filter panel used everywhere (grid, per-artist list, All
  // Songs) instead of only inside All Songs.
  Widget _buildFilterSidebar({required bool isDesktop}) {
    final language = context.watch<LocaleProvider>().currentLanguage;
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('songs')
              .where('status', isEqualTo: 'approved')
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        final genders = <String>{};
        final bands = <String>{};
        final categories = <String>{};
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          // Normalized so a straggler doc with a pre-preset raw value (see
          // gender_labels.dart/category_labels.dart) doesn't show up as a
          // duplicate, untranslated tile alongside its stable-key
          // equivalent.
          final gender = normalizeGenderValue(data['gender'] as String?);
          if (gender != null) genders.add(gender);
          final band = (data['band'] as String?)?.trim() ?? '';
          if (band.isNotEmpty) bands.add(band);
          final category = normalizeCategoryValue(
            data['category'] as String?,
          );
          if (category != null) categories.add(category);
        }

        final genderList = genders.toList()..sort();
        final bandList = bands.toList()..sort();
        final categoryList = categories.toList()..sort();
        final allLabel = AppTranslations.getText('allOption', language);

        // Each section gets its own accent color, reused from the same
        // _artistPalette that colors the Home page and the artist covers —
        // gives the three sections distinct visual identities instead of
        // one undifferentiated list, without introducing a second palette.
        // Fixed palette colors, not scheme.onSurface — this app's light
        // theme inverts convention (onSurface reads dark, but onSurface in
        // dark mode is near-white), so a theme-derived accent here would
        // render the "All" tile's white checkmark/text on a white
        // background in dark mode (a real bug this exact pattern already
        // caused elsewhere in the app — see the roadmap notes on always
        // giving new buttons/tiles an explicit, non-theme-derived color).
        final genderAccent = _artistPalette[3];
        final bandAccent = _artistPalette[1];
        final singerAccent = _artistPalette[5];
        final categoryAccent = _artistPalette[6];

        return ListView(
          controller: _sidebarScrollController,
          // NeverScrollable only when embedded in desktop's fixed side
          // column (see desktopBookScreen's wrapping Listener); as a mobile
          // Drawer this is the only scrollable in view, so it keeps native
          // touch scrolling.
          physics:
              isDesktop
                  ? const NeverScrollableScrollPhysics()
                  : const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _buildHeader(
              AppTranslations.getText('categoryLabel', language),
              icon: FontAwesomeIcons.tags,
              accentColor: categoryAccent,
            ),
            _buildCustomListTile(
              title: allLabel,
              isSelected:
                  selectedCategory == null || selectedCategory == 'All',
              accentColor: categoryAccent,
              onTap: () {
                setState(() {
                  selectedCategory = 'All';
                  selectedEntityId = null;
                  selectedEntityName = null;
                  _allSongsMode = false;
                  _slideController.reverse();
                });
              },
            ),
            ...categoryList.map((category) {
              return _buildCustomListTile(
                title: categoryDisplayLabel(category, language),
                isSelected: category == selectedCategory,
                accentColor: _categoryColorFor(category),
                leadingIcon: _categoryIconFor(category),
                onTap: () {
                  setState(() {
                    selectedCategory = category;
                    selectedEntityId = null;
                    selectedEntityName = null;
                    _allSongsMode = false;
                    _slideController.reverse();
                  });
                },
              );
            }),
            _buildHeader(
              AppTranslations.getText('genderLabel', language),
              icon: FontAwesomeIcons.restroom,
              accentColor: genderAccent,
            ),
            _buildCustomListTile(
              title: allLabel,
              isSelected: selectedGender == null || selectedGender == 'All',
              accentColor: genderAccent,
              onTap: () {
                setState(() {
                  selectedGender = null;
                  selectedEntityId = null;
                  selectedEntityName = null;
                  _allSongsMode = false;
                  _slideController.reverse();
                });
              },
            ),
            ...genderList.map((gender) {
              return _buildCustomListTile(
                title: genderDisplayLabel(gender, language),
                isSelected: gender == selectedGender,
                accentColor: genderAccent,
                onTap: () {
                  setState(() {
                    selectedGender = gender;
                    selectedEntityId = null;
                    selectedEntityName = null;
                    _allSongsMode = false;
                    _slideController.reverse();
                  });
                },
              );
            }),
            _buildHeader(
              AppTranslations.getText('bandFilterLabel', language),
              icon: FontAwesomeIcons.peopleGroup,
              accentColor: bandAccent,
            ),
            _buildCustomListTile(
              title: allLabel,
              isSelected: selectedBand == null || selectedBand == 'All',
              accentColor: bandAccent,
              onTap: () {
                setState(() {
                  selectedBand = null;
                  selectedEntityId = null;
                  selectedEntityName = null;
                  _allSongsMode = false;
                  _slideController.reverse();
                });
              },
            ),
            ...bandList.map((band) {
              return _buildCustomListTile(
                title: band,
                isSelected: band == selectedBand,
                accentColor: bandAccent,
                onTap: () {
                  setState(() {
                    selectedBand = band;
                    selectedEntityId = null;
                    selectedEntityName = null;
                    _allSongsMode = false;
                    _slideController.reverse();
                  });
                },
              );
            }),
            // Solo/Duet/Group are fixed, derived buckets (see
            // _singerCountBucket) — not scanned from live data like
            // Gender/Band, since every song always falls into exactly one
            // of these three regardless of what's actually been submitted.
            _buildHeader(
              AppTranslations.getText('singerCountLabel', language),
              icon: FontAwesomeIcons.users,
              accentColor: singerAccent,
            ),
            _buildCustomListTile(
              title: allLabel,
              isSelected:
                  selectedSingerCount == null || selectedSingerCount == 'All',
              accentColor: singerAccent,
              onTap: () {
                setState(() {
                  selectedSingerCount = null;
                  selectedEntityId = null;
                  selectedEntityName = null;
                  _allSongsMode = false;
                  _slideController.reverse();
                });
              },
            ),
            for (final bucket in const ['solo', 'duet', 'group'])
              _buildCustomListTile(
                title: AppTranslations.getText(
                  {
                    'solo': 'singerSolo',
                    'duet': 'singerDuet',
                    'group': 'singerGroup',
                  }[bucket]!,
                  language,
                ),
                isSelected: bucket == selectedSingerCount,
                accentColor: singerAccent,
                onTap: () {
                  setState(() {
                    selectedSingerCount = bucket;
                    selectedEntityId = null;
                    selectedEntityName = null;
                    _allSongsMode = false;
                    _slideController.reverse();
                  });
                },
              ),
          ],
        );
      },
    );
  }

  // A selected tile fills solid with its section's accent color (white
  // text/icon for contrast) instead of the old barely-there
  // onSurface-at-8%-opacity tint + thin outline — reads as a proper active
  // filter chip rather than a checkbox in a settings list.
  Widget _buildCustomListTile({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    required Color accentColor,
    // Lets Category rows show their own themed icon (see
    // _categoryIconFor) instead of the generic check/circle-outline below —
    // selection is still conveyed by the solid accent-color fill, so
    // swapping the leading icon doesn't lose that affordance. Gender/Band/
    // Singer rows don't pass this, so they're unaffected.
    IconData? leadingIcon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 12.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: isSelected ? accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border:
                isSelected
                    ? null
                    : Border.all(color: scheme.onSurface.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              FaIcon(
                leadingIcon ??
                    (isSelected
                        ? FontAwesomeIcons.solidCircleCheck
                        : FontAwesomeIcons.circle),
                color:
                    isSelected
                        ? Colors.white
                        : (leadingIcon != null
                            ? accentColor
                            : scheme.onSurface.withOpacity(0.5)),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.normal,
                    fontSize: 15,
                    color: isSelected ? Colors.white : scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Small-caps, muted-color section label with a leading icon — reads as a
  // filter-panel section grouping rather than a plain bold list header, and
  // the icon+color pairing (see the three *Accent locals in
  // _buildFilterSidebar) gives each of the three sections its own visual
  // identity at a glance.
  Widget _buildHeader(String title, {IconData? icon, Color? accentColor}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 8.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 15,
              color: accentColor ?? scheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              letterSpacing: 0.8,
              color: scheme.onSurface.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }

  // Same soft radial-gradient "aurora" blobs as Home's hero backdrop and
  // the About page's whole-page backdrop — a user asked for this page's
  // background to match Home's, so it reuses the exact same helper shape
  // (colors from the shared _artistPalette, faded-to-transparent radial
  // gradients) rather than inventing a third treatment.
  Widget _backdrop() {
    Widget blob(Color color, double size) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withOpacity(0.3), color.withOpacity(0)],
          ),
        ),
      );
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(top: -60, right: -80, child: blob(_artistPalette[3], 320)),
            Positioned(top: 260, left: -100, child: blob(_artistPalette[0], 280)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _backdrop(),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= AppBreakpoints.desktop) {
                return desktopBookScreen();
              } else {
                return _narrowBookScreen();
              }
            },
          ),
        ],
      ),
    );
  }

  // A user reported the desktop layout as "can't scroll" — root cause: the
  // content area (grid/song-list/All-Songs) and the 200px filter sidebar
  // are two independent scrollables side by side, so a wheel scroll only
  // ever moved whichever one the mouse happened to be directly over (and
  // did nothing at all in the gaps between). All four scrollables in this
  // Row now use NeverScrollableScrollPhysics (see their own build methods)
  // and this wrapping Listener drives them manually instead, so one wheel
  // gesture anywhere across the whole Row moves the sidebar and whichever
  // content list is currently visible together — each still independently
  // clamped to its own scroll extent.
  Widget desktopBookScreen() {
    final borderColor = Theme.of(
      context,
    ).colorScheme.onSurface.withOpacity(0.08);
    return Listener(
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
        final dy = event.scrollDelta.dy;
        void scroll(ScrollController controller) {
          if (!controller.hasClients) return;
          controller.jumpTo(
            (controller.offset + dy).clamp(
              0.0,
              controller.position.maxScrollExtent,
            ),
          );
        }

        scroll(_sidebarScrollController);
        if (selectedEntityId != null) {
          scroll(_songListScrollController);
        } else if (_allSongsMode) {
          scroll(_allSongsScrollController);
        } else {
          scroll(_gridScrollController);
        }
      },
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildContentArea(),
            ),
          ),
          Container(
            width: 200,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: borderColor)),
            ),
            child: _buildFilterSidebar(isDesktop: true),
          ),
        ],
      ),
    );
  }

  // Shared by both the tablet and mobile breakpoints (<900px): the category
  // panel that used to sit fixed on the right (like on desktop) is too wide
  // for these screens, so it moves into an end drawer instead, and the
  // old "Back to songs/artists/categories" buttons are replaced by a single
  // back arrow in the AppBar that steps back one level at a time.
  Widget _narrowBookScreen() {
    final showBack = selectedEntityId != null || _allSongsMode;
    final title =
        selectedEntityName ?? (_allSongsMode ? 'All Songs' : 'All Artists');
    return Scaffold(
      // Transparent so the outer Scaffold's _backdrop() (see build()) shows
      // through — this inner Scaffold exists only for its own AppBar/
      // endDrawer, not for a background of its own.
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading:
            showBack
                ? IconButton(
                  icon: const FaIcon(FontAwesomeIcons.arrowLeft, size: 18),
                  onPressed: _goBackOneLevel,
                )
                : null,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: true,
        actions: [
          Builder(
            builder: (context) {
              return IconButton(
                icon: const FaIcon(FontAwesomeIcons.restroom, size: 18),
                onPressed: () {
                  Scaffold.of(context).openEndDrawer();
                },
              );
            },
          ),
        ],
      ),
      endDrawer: Drawer(child: _buildFilterSidebar(isDesktop: false)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildContentArea(hideArtistOverlay: true),
      ),
    );
  }
}
