import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors LocaleProvider's simple ChangeNotifier style. Listens to
/// FirebaseAuth's sign-in state and, while signed in, keeps a *live*
/// listener on the matching `users/{uid}` doc (not a one-shot read) so
/// things like the Phase F badge tier update on screen the moment an admin
/// approves a song, without the user needing to refresh anything.
class AuthProvider extends ChangeNotifier {
  User? _user;
  Map<String, dynamic>? _userDoc;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _userDocSubscription;

  AuthProvider() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _onAuthChanged,
    );
  }

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _userDoc?['isAdmin'] == true;
  bool get isBlocked => _userDoc?['blocked'] == true;
  int get approvedSongCount => (_userDoc?['approvedSongCount'] as int?) ?? 0;
  String? get displayName => _userDoc?['displayName'] as String?;
  String? get photoUrl => _userDoc?['photoUrl'] as String?;
  int get currentStreak => (_userDoc?['currentStreak'] as int?) ?? 0;
  int get longestStreak => (_userDoc?['longestStreak'] as int?) ?? 0;
  DateTime? get createdAt => (_userDoc?['createdAt'] as Timestamp?)?.toDate();

  // Session-only UI state, not persisted — admin opts into seeing an "Edit"
  // button on song rows while browsing, instead of it always cluttering the
  // normal reading view. Deliberately reset on sign-out/sign-in so a shared
  // machine doesn't leak it into the next session.
  bool _editModeEnabled = false;
  bool get editModeEnabled => isAdmin && _editModeEnabled;

  void toggleEditMode() {
    _editModeEnabled = !_editModeEnabled;
    notifyListeners();
  }

  // Guards the daily-streak check (see _maybeUpdateStreak) to run at most
  // once per sign-in session rather than on every live snapshot this
  // listener receives — including the one our own streak-updating write
  // triggers, which would otherwise just be a redundant (harmless but
  // wasteful) re-check every single time, not literally an infinite loop.
  bool _streakCheckedThisSession = false;

  void _onAuthChanged(User? user) {
    _user = user;
    _userDocSubscription?.cancel();
    _userDocSubscription = null;
    _editModeEnabled = false;
    _streakCheckedThisSession = false;

    if (user == null) {
      _userDoc = null;
      notifyListeners();
      return;
    }

    _userDocSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
          if (!doc.exists) {
            // Only self-heal on a SERVER-confirmed absence. A cache-only
            // snapshot (metadata.isFromCache) can report exists:false
            // simply because this device's local offline cache hasn't
            // synced the document yet (e.g. a first load on a new browser/
            // device after persistenceEnabled:true was turned on) — even
            // though the document genuinely exists on the server. Acting
            // on that false negative overwrote a real, long-standing
            // account's profile (including isAdmin) with blank defaults,
            // a real incident this exact gap caused. The server snapshot
            // always follows shortly after and corrects `_userDoc` via the
            // branch below, so simply waiting for it here loses nothing.
            if (doc.metadata.isFromCache) return;
            // Self-heals a rare race from register(): createUserWithEmail-
            // AndPassword() signs the user in as a side effect, but the very
            // next Firestore write (creating this doc) can occasionally run
            // before the client's ID token is recognized as signed-in,
            // failing permission-denied — leaving a real, working account
            // with no profile doc at all (confirmed happening to a real
            // account: "(no name)" on Profile, then "not-found" the first
            // time they tried to save a display name). Recreating it here
            // means every future sign-in/reload repairs it automatically,
            // not just the moment right after registration.
            FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'displayName': user.displayName ?? '',
              'isAdmin': false,
              'approvedSongCount': 0,
              'createdAt': FieldValue.serverTimestamp(),
            });
            return;
          }
          _userDoc = doc.data();
          _maybeUpdateStreak(user.uid, _userDoc!);
          notifyListeners();
        });
    notifyListeners();
  }

  // A Duolingo-style "days in a row" counter, computed and written entirely
  // client-side from *this device's* local date — deliberately not a Cloud
  // Function, since there's no natural server-side event to hook (unlike
  // favoriteCount/viewCount, "the app was opened" isn't a Firestore write
  // on its own). Trusted at the same level as displayName/photoUrl in
  // firestore.rules: a cosmetic gamification number, not worth server-side
  // validation for.
  void _maybeUpdateStreak(String uid, Map<String, dynamic> data) {
    if (_streakCheckedThisSession) return;
    _streakCheckedThisSession = true;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastActiveStr = data['lastActiveDate'] as String?;
    final currentStreak = (data['currentStreak'] as int?) ?? 0;
    final longestStreak = (data['longestStreak'] as int?) ?? 0;

    int newStreak;
    if (lastActiveStr == null) {
      newStreak = 1;
    } else {
      final lastActive = DateTime.parse(lastActiveStr);
      final daysSinceActive = today.difference(lastActive).inDays;
      if (daysSinceActive == 0) {
        return; // already logged in today — nothing to update
      } else if (daysSinceActive == 1) {
        newStreak = currentStreak + 1; // consecutive day
      } else {
        newStreak = 1; // streak broken — a day (or more) was missed
      }
    }

    final todayStr = today.toIso8601String().split('T').first;
    FirebaseFirestore.instance.collection('users').doc(uid).update({
      'currentStreak': newStreak,
      'longestStreak': newStreak > longestStreak ? newStreak : longestStreak,
      'lastActiveDate': todayStr,
    });
  }

  /// Returns null on success, or a human-readable error message.
  Future<String?> signIn(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? e.code;
    }
  }

  /// Returns null on success, or a human-readable error message. Creates
  /// the matching `users/{uid}` doc on success.
  Future<String?> register(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
      final uid = credential.user!.uid;
      // Deliberately no email field here: this doc is publicly readable
      // (needed later to show author names/badges next to songs), and
      // Firebase Auth already owns the email address — no need to expose
      // it a second time via Firestore.
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'displayName': displayName.trim(),
        'isAdmin': false,
        'approvedSongCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? e.code;
    }
  }

  /// Returns null on success, or a human-readable error message. Firebase
  /// intentionally doesn't distinguish "no account for this email" from
  /// success here (avoids leaking which emails are registered), so a null
  /// return just means the request went through, not that an email is
  /// guaranteed to land.
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? e.code;
    }
  }

  Future<void> signOut() => FirebaseAuth.instance.signOut();

  @override
  void dispose() {
    _authSubscription?.cancel();
    _userDocSubscription?.cancel();
    super.dispose();
  }
}
