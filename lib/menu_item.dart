enum MenuItem {
  home,
  about,
  contact,
  guide,
  privacy,
  terms,
  book,
  tuner,
  chords,
  requestSong,
  community,
  login,
  submitSong,
  admin,
  mySongs,
  favorites,
  setlists,
  profile,
}

/// Maps each top-level [MenuItem] to its URL path, and back. Kept in one
/// place so `Navbar`/`AccountDrawer` can keep their existing
/// `ValueChanged<MenuItem> onMenuSelected` API — the shell in home_page.dart
/// just turns a selection into `context.go(pathForMenuItem(item))` instead
/// of a local `setState`.
String pathForMenuItem(MenuItem item) {
  switch (item) {
    case MenuItem.home:
      return '/';
    case MenuItem.book:
      return '/songbook';
    case MenuItem.tuner:
      return '/tuner';
    case MenuItem.chords:
      return '/chords';
    case MenuItem.requestSong:
      return '/request-song';
    case MenuItem.community:
      return '/community';
    case MenuItem.about:
      return '/about';
    case MenuItem.contact:
      return '/contact';
    case MenuItem.guide:
      return '/guide';
    case MenuItem.privacy:
      return '/privacy';
    case MenuItem.terms:
      return '/terms';
    case MenuItem.login:
      return '/login';
    case MenuItem.submitSong:
      return '/submit-song';
    case MenuItem.mySongs:
      return '/my-songs';
    case MenuItem.favorites:
      return '/favorites';
    case MenuItem.setlists:
      return '/setlists';
    case MenuItem.profile:
      return '/profile';
    case MenuItem.admin:
      return '/admin';
  }
}

/// Inverse of [pathForMenuItem] — used by the shell to know which nav item
/// to highlight for the current route. Falls back to [MenuItem.home] for
/// any unrecognized/nested path (e.g. `/songbook/song/abc123` still
/// highlights "SongBook").
MenuItem menuItemForLocation(String location) {
  if (location.startsWith('/songbook')) return MenuItem.book;
  if (location.startsWith('/tuner')) return MenuItem.tuner;
  if (location.startsWith('/chords')) return MenuItem.chords;
  if (location.startsWith('/request-song')) return MenuItem.requestSong;
  if (location.startsWith('/community')) return MenuItem.community;
  if (location.startsWith('/about')) return MenuItem.about;
  if (location.startsWith('/contact')) return MenuItem.contact;
  if (location.startsWith('/guide')) return MenuItem.guide;
  if (location.startsWith('/privacy')) return MenuItem.privacy;
  if (location.startsWith('/terms')) return MenuItem.terms;
  if (location.startsWith('/login')) return MenuItem.login;
  if (location.startsWith('/submit-song')) return MenuItem.submitSong;
  if (location.startsWith('/my-songs')) return MenuItem.mySongs;
  if (location.startsWith('/favorites')) return MenuItem.favorites;
  if (location.startsWith('/setlists')) return MenuItem.setlists;
  if (location.startsWith('/profile')) return MenuItem.profile;
  if (location.startsWith('/admin')) return MenuItem.admin;
  return MenuItem.home;
}
