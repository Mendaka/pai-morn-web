import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:pai_morn_web/home_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pai_morn_web/utils/recently_viewed_songs.dart';
import 'package:pai_morn_web/utils/instrument_mode.dart';
import 'package:pai_morn_web/utils/site_view_recorder.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/auth/auth_provider.dart';
import 'package:pai_morn_web/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pai_morn_web/widget/about_screen.dart';
import 'package:pai_morn_web/widget/admin_shell.dart';
import 'package:pai_morn_web/widget/artist_profile_screen.dart';
import 'package:pai_morn_web/widget/book_screen.dart';
import 'package:pai_morn_web/widget/chords_screen.dart';
import 'package:pai_morn_web/widget/community_screen.dart';
import 'package:pai_morn_web/widget/community_thread_screen.dart';
import 'package:pai_morn_web/widget/contact_screen.dart';
import 'package:pai_morn_web/widget/favorites_screen.dart';
import 'package:pai_morn_web/widget/guide_screen.dart';
import 'package:pai_morn_web/widget/legal_page_screen.dart';
import 'package:pai_morn_web/widget/home_screen.dart';
import 'package:pai_morn_web/widget/login_screen.dart';
import 'package:pai_morn_web/widget/my_songs_screen.dart';
import 'package:pai_morn_web/widget/profile_screen.dart';
import 'package:pai_morn_web/widget/public_setlist_screen.dart';
import 'package:pai_morn_web/widget/request_song_screen.dart';
import 'package:pai_morn_web/widget/setlist_detail_screen.dart';
import 'package:pai_morn_web/widget/setlist_screen.dart';
import 'package:pai_morn_web/widget/song_reader_screen.dart';
import 'package:pai_morn_web/widget/song_requests_vote_screen.dart';
import 'package:pai_morn_web/widget/submit_song_screen.dart';
import 'package:pai_morn_web/widget/tuner_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean path-based URLs (`/songbook/song/abc123`) instead of the
  // hash-based default (`/#/songbook/song/abc123`) — required for the
  // deep-linkable song routes to read as real shareable URLs.
  usePathUrlStrategy();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyArbwA8fpx8UQ-Quuai65GwxYDIhyzofvs",
      authDomain: "song-and-chord.firebaseapp.com",
      projectId: "song-and-chord",
      storageBucket: "song-and-chord.appspot.com",
      messagingSenderId: "232124936247",
      appId: "1:232124936247:web:9172641b4e8558c7aa0fb2",
      measurementId: "G-65F29F45FH",
    ),
  );
  // Keeps whatever a user has read (songs opened, setlists, etc.) available
  // offline via IndexedDB — must be set before any other Firestore call.
  // Combined with _prewarmRecentSongs below so the last few songs someone
  // actually reads stay available even if they never reopen them this
  // session before losing connectivity.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  unawaited(_prewarmRecentSongs());
  unawaited(recordSiteView());
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => InstrumentModeProvider()..load()),
      ],
      child: MyApp(),
    ),
  );
}

// Best-effort — re-fetches each of the last few songs opened on this device
// so they're warm in Firestore's persistent (IndexedDB) cache even if the
// user never reopens them this session before going offline. Silently
// no-ops per-song on any error (deleted song, offline already, etc.) since
// this is purely a cache warm-up, not something the UI waits on.
Future<void> _prewarmRecentSongs() async {
  final ids = await loadRecentlyViewedIds();
  for (final id in ids) {
    unawaited(_prewarmSong(id));
  }
}

Future<void> _prewarmSong(String id) async {
  try {
    await FirebaseFirestore.instance.collection('songs').doc(id).get();
  } catch (_) {
    // Best-effort cache warm-up — nothing more useful to do on failure.
  }
}

/// Builds a full [ThemeData] from a base [ColorScheme], wiring shared
/// component themes (buttons, inputs, cards, app bar, text) so individual
/// screens stop reinventing them inline. See lib/theme/app_theme.dart for
/// the underlying radius/spacing/shadow/breakpoint tokens.
ThemeData _buildTheme(ColorScheme scheme) {
  final radius = BorderRadius.circular(AppRadius.sm);
  final buttonShape = RoundedRectangleBorder(borderRadius: radius);

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.onSurface,
        foregroundColor: scheme.surface,
        shape: buttonShape,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.onSurface.withOpacity(0.3)),
        shape: buttonShape,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: scheme.onSurface),
    ),
    // colorScheme.primary is deliberately inverted for this monochrome
    // theme (white in light mode, black in dark mode — see the two
    // ColorScheme literals below), which is exactly what Flutter's text
    // cursor/selection colors default to when unset. Left alone, that's an
    // invisible white cursor on a white field in light mode (and an
    // invisible black one in dark mode) — a real user reported not being
    // able to see where they were typing. onSurface is the correct
    // "readable ink" color in both modes, so pin cursor/selection to it
    // explicitly instead of inheriting primary.
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.onSurface,
      selectionColor: scheme.onSurface.withOpacity(0.2),
      selectionHandleColor: scheme.onSurface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.onSurface.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: scheme.onSurface.withOpacity(0.15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: scheme.onSurface.withOpacity(0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: scheme.onSurface.withOpacity(0.6)),
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: scheme.onSurface.withOpacity(0.08)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: scheme.onSurface.withOpacity(0.08)),
      ),
    ),
    textTheme: TextTheme(
      displaySmall: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: scheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: scheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: scheme.onSurface),
      bodyMedium: TextStyle(fontSize: 14, color: scheme.onSurface),
      bodySmall: TextStyle(
        fontSize: 12,
        color: scheme.onSurface.withOpacity(0.6),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const _themePrefsKey = 'theme_mode_dark';

  // Starts light (same as before) so there's no flash-of-unstyled-content
  // while the async prefs read resolves — on a returning dark-mode visitor
  // this corrects itself within a frame or two, which reads as "already
  // dark" rather than a visible flicker in practice.
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_themePrefsKey) ?? false;
    if (mounted && isDark) {
      setState(() => _themeMode = ThemeMode.dark);
    }
  }

  void _toggleTheme() {
    final newMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    setState(() => _themeMode = newMode);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool(_themePrefsKey, newMode == ThemeMode.dark),
    );
  }

  // A guarded page needs to know whether the user is logged in/admin before
  // deciding which real screen to render — same fallback behavior
  // (LoginScreen / AboutScreen) as when this lived in home_page.dart's
  // MenuItem switch, just relocated to each route's own builder.
  Widget _requireLogin(Widget page) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isLoggedIn) return const LoginScreen();
        return page;
      },
    );
  }

  Widget _requireAdmin(Widget page) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isAdmin) return const AboutScreen();
        return page;
      },
    );
  }

  // Built once (not rebuilt on every theme toggle) so in-app navigation
  // history/state survives theme switches. `_toggleTheme` stays safe to
  // pass down as-is (a method tearoff reads `_themeMode` fresh at call
  // time, regardless of when the closure was captured) — but a *value*
  // like `_themeMode` itself is a different story: go_router's ShellRoute
  // only re-invokes this builder on navigation, not on every ancestor
  // setState, so a snapshot of `_themeMode` passed down through it would
  // go stale the moment the theme toggles without also navigating (this
  // was a real bug, found via Navbar's theme-icon staying on the wrong
  // icon after toggling — fixed by having Navbar read the live theme via
  // `Theme.of(context)` instead of accepting a `themeMode` prop at all).
  late final GoRouter _router = GoRouter(
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return MyHomePage(
            currentLocation: state.uri.toString(),
            onToggleTheme: _toggleTheme,
            child: child,
          );
        },
        routes: [
          GoRoute(path: '/', builder: (context, state) => HomeScreen()),
          GoRoute(path: '/songbook', builder: (context, state) => BookScreen()),
          GoRoute(
            path: '/tuner',
            builder: (context, state) => const TunerScreen(),
          ),
          GoRoute(
            path: '/chords',
            builder: (context, state) => const ChordsScreen(),
          ),
          GoRoute(
            path: '/request-song',
            builder: (context, state) => const RequestSongScreen(),
          ),
          GoRoute(
            path: '/song-requests/vote',
            builder: (context, state) => const SongRequestsVoteScreen(),
          ),
          GoRoute(
            path: '/community',
            builder: (context, state) => const CommunityScreen(),
          ),
          GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
          GoRoute(path: '/guide', builder: (context, state) => const GuideScreen()),
          GoRoute(
            path: '/privacy',
            builder:
                (context, state) => const LegalPageScreen(
                  titleKey: 'privacyTitle',
                  lastUpdatedKey: 'privacyLastUpdated',
                  bodyKey: 'privacyBody',
                ),
          ),
          GoRoute(
            path: '/terms',
            builder:
                (context, state) => const LegalPageScreen(
                  titleKey: 'termsTitle',
                  lastUpdatedKey: 'termsLastUpdated',
                  bodyKey: 'termsBody',
                ),
          ),
          GoRoute(
            path: '/contact',
            builder: (context, state) => const ContactScreen(),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: '/submit-song',
            builder:
                (context, state) => _requireLogin(const SubmitSongScreen()),
          ),
          GoRoute(
            path: '/my-songs',
            builder: (context, state) => _requireLogin(const MySongsScreen()),
          ),
          GoRoute(
            path: '/favorites',
            builder:
                (context, state) => _requireLogin(const FavoritesScreen()),
          ),
          GoRoute(
            path: '/setlists',
            builder: (context, state) => _requireLogin(const SetlistScreen()),
          ),
          GoRoute(
            path: '/profile',
            builder:
                (context, state) => _requireLogin(
                  ProfileScreen(
                    startInEditMode: state.uri.queryParameters['edit'] == '1',
                  ),
                ),
          ),
          GoRoute(
            path: '/admin',
            builder: (context, state) => _requireAdmin(const AdminShell()),
          ),
        ],
      ),
      // Deliberately a sibling of the ShellRoute above, not nested inside
      // it — kept simple since it's reached via `context.go()` (see below)
      // rather than a `ShellRoute`-nested push. SongReaderScreen has its
      // own AppBar/back button (built that way from the start, so it's
      // reachable consistently from SongBook, My Songs, or a raw link),
      // so losing the persistent Navbar while reading isn't a regression —
      // just this route living where a detail page like this belongs.
      //
      // Reached via `context.go(...)`, not `.push(...)`: go_router treats
      // `.push()` as a purely "imperative" overlay that does NOT update
      // the visible browser URL at all (confirmed empirically — a
      // monkeypatched `history.pushState` showed go_router passing the
      // *previous* location as the URL argument, only recording the
      // pushed route inside the history *state* object's
      // `imperativeMatches`). Since the entire point of this route is a
      // real, shareable address-bar URL, `.go()` is required — the
      // trade-off is that going back from a song no longer restores
      // SongBook's in-progress browsing state (which page of the artist/
      // song list you were on); it lands back on the artist grid instead.
      GoRoute(
        path: '/songbook/song/:songId',
        builder:
            (context, state) => SongReaderScreen(
              songId: state.pathParameters['songId']!,
              setlistId: state.uri.queryParameters['setlist'],
            ),
      ),
      // A sibling of the song route above for the same reasons (own
      // AppBar, real shareable `.go()`-based URL) — reached from Home's
      // "Explore Artists" grid (see home_screen.dart's `_artistTile`).
      GoRoute(
        path: '/songbook/artist/:artistId',
        builder:
            (context, state) => ArtistProfileScreen(
              artistId: state.pathParameters['artistId']!,
            ),
      ),
      // Same reasoning as the song route above — reached via `context.go`
      // (not `.push`) so the address bar actually updates and a thread
      // link is real/shareable.
      GoRoute(
        path: '/community/thread/:threadId',
        builder:
            (context, state) => CommunityThreadScreen(
              threadId: state.pathParameters['threadId']!,
            ),
      ),
      // Same reasoning as the two routes above — its own AppBar/back
      // button, reached via `context.go` so reordering/renaming/deleting a
      // setlist has a real, shareable address.
      GoRoute(
        path: '/setlists/:setlistId',
        builder:
            (context, state) => _requireLogin(
              SetlistDetailScreen(
                setlistId: state.pathParameters['setlistId']!,
              ),
            ),
      ),
      // No _requireLogin — this is the read-only link anyone can open (see
      // the Share button in setlist_detail_screen.dart), unrelated to the
      // owner-only route above despite the shared '/setlists' prefix; the
      // extra path segments keep the two from ever colliding.
      GoRoute(
        path: '/setlists/shared/:ownerUid/:setlistId',
        builder:
            (context, state) => PublicSetlistScreen(
              ownerUid: state.pathParameters['ownerUid']!,
              setlistId: state.pathParameters['setlistId']!,
            ),
      ),
      // This URL only exists so the "Share" button on
      // TodaysNewSongsCard has something with its own OG tags to point
      // at (see dailyUpdatePreview/dailyUpdateCard in functions/index.js,
      // which serve those tags to a link-preview bot before this route
      // ever runs client-side) — a real visitor just lands on Home.
      GoRoute(
        path: '/daily-update',
        redirect: (context, state) => '/',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Paimorn',
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(
        const ColorScheme.light(
          primary: Colors.white,
          onPrimary: Colors.black,
          secondary: Colors.black,
          onSecondary: Colors.white,
          error: Color(0xFFD64545),
          onError: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
      ),
      darkTheme: _buildTheme(
        const ColorScheme.dark(
          primary: Colors.black,
          onPrimary: Colors.white,
          secondary: Colors.white,
          onSecondary: Colors.black,
          error: Color(0xFFE57373),
          onError: Colors.black,
          surface: Colors.black,
          onSurface: Colors.white,
        ),
      ),
      // Light/dark used to cut instantly — every color-driven widget in the
      // whole app now cross-fades to the new theme instead, since
      // AnimatedTheme interpolates whatever ThemeData its `data` resolves to
      // on each build rather than applying it immediately. No per-widget
      // change needed anywhere else: everything already reads colors via
      // Theme.of(context)/context.watch, so this one wrapper covers the
      // entire app.
      builder:
          (context, child) => AnimatedTheme(
            data: Theme.of(context),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            child: child!,
          ),
      routerConfig: _router,
    );
  }
}
