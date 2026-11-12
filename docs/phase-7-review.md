# Phase 7: user profile

## Implemented
- Profile is reachable from Home's app bar and displays account email, editable
  full name and account creation date when available. Email remains read-only;
  changing a sign-in address requires a separate verified-email flow.
- ProfileCubit uses independent live profile, created-event and registered-event
  subscriptions. Statistics show created events, active event registrations and
  the total current participant registrations across the user's created events.
  These are current counts, not lifetime attendance/unique-person totals.
- Profile errors and statistic errors remain distinct; failed statistics show
  unavailable rather than misleading zero. Reload replaces subscriptions.
- Name validation supports Cyrillic, trims whitespace and limits to 100 Unicode
  code points. Unsaved form drafts survive incoming snapshots. A shared operation
  guard prevents duplicate/cross-operation submissions.
- ProfileRepository reads/writes only the authenticated user's users/{uid}.
  Firestore is the canonical stored name, then Firebase Auth displayName is
  updated so future event registrations use the new name. Existing registration
  names remain historical snapshots. No private participant profiles are exposed.
- A missing users/{uid} document falls back to Firebase Auth metadata and can be
  created on Save with trusted account email and a server timestamp.
- Firestore and Firebase Auth cannot be updated atomically together: if Auth name
  synchronization fails after Firestore saved, the error explains that saving
  again retries synchronization. No silent full-success claim in this case.
- Password reset asks for confirmation and calls sendPasswordResetEmail using
  the authenticated account's email, never an editable arbitrary recipient.
  Non-password providers have a disabled reset control. No password is collected.
- Sign-out asks for confirmation, calls Firebase Auth signOut, returns to the
  root login route and disposes personal subscriptions. It also works when the
  profile document failed to load. Existing auth-state listeners remain in use.

## Firebase/security changes
- Profile create/update is still self-only. Only name may change on existing
  documents; email, createdAt, arbitrary roles and profile deletion stay denied.
- Rules now validate profile and registration display names with a shared
  nonblank, Unicode-aware bounded regex. Client and rules accept up to 100 code
  points, including supplementary Unicode characters.
- Signup validates name before Firebase account creation and bounds the form;
  no auth login/logout handler was replaced.
- ProfileStore is provided at app scope for injectable repository access.
  No Firebase platform configuration, new indexes, or dependencies were added.
- Rules were tested locally, not deployed. Compare deployed rules, then publish:
    firebase deploy --only firestore:rules --project eventhub-fae97
  Earlier My Events index requirements remain unchanged.
- Firebase Authentication Email/Password must already be enabled. Password-reset
  email template/sender can optionally be customized in Firebase Authentication
  Templates. No real reset email was sent during development or tests.
Reference: https://firebase.google.com/docs/auth/flutter/manage-users

## Files
Created:
- lib/features/profile/models/user_profile.dart
- lib/features/profile/repositories/profile_repository.dart
- lib/features/profile/bloc/profile_cubit.dart
- lib/features/profile/screens/profile_screen.dart
- test/user_profile_test.dart
- test/profile_cubit_test.dart
- test/profile_widget_test.dart
- test/support/profile_store_stub.dart
- docs/phase-7-review.md
Modified this phase:
- lib/main.dart
- lib/features/auth/screens/home_screen.dart
- lib/features/auth/screens/register_screen.dart
- lib/features/auth/repositories/auth_repository.dart
- firestore.rules
- tools/firestore-tests/rules.test.mjs
Earlier phase changes remain uncommitted.

## Validation
- Firestore demo emulator: 23 tests passed, including name validation, private
  profiles, immutable email/metadata, creating a missing own profile, Unicode
  bounds and prior event/registration/query regressions.
- Flutter model/state tests use fakes to cover identity fallback, statistics,
  async errors/retry, duplicate submissions, stream lifecycle and profile writes.
- Profile widget tests exercise navigation, live data, draft preservation,
  validation, reset/logout confirmation and unsupported reset providers.
- No production profile write, actual email delivery or authenticated production
  end-to-end flow was exercised. Auth/Firestore cross-service synchronization was
  reviewed in the Dart repository, not tested against live production services.

Next phase: bottom navigation for Home, My Events, Create Event and Profile.
Suggested commit: feat(profile): add editing statistics password reset and sign out
No commit or push performed.

Final checks so far: flutter analyze reported No issues found; all 73 Flutter
tests and all 23 Firestore emulator tests passed. Dart formatting and
git diff --check passed.
Android validation: debug APK built, installed and launched on emulator-5554.
Existing Java native-access and Firebase plugin Kotlin Gradle warnings remain.
