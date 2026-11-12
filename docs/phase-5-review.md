# Phase 5: organizer participant list

## Implemented
- Organizer-only Participants action in event details, reachable from Home and
  My Events -> Created -> Manage Event.
- Live roster with participant name (when available), stable UID, registration
  date/time in the device's local timezone and participant count / event capacity.
- Records sorted by registration date; unknown dates appear last with UID
  tie-break. Empty/error/loading/retry/missing-event/access-denied states added.
- Route-scoped ParticipantsCubit verifies the live event organizer before opening
  a roster subscription. Repository also checks the current Firebase user against
  the stored event. Server rules enforce organizer-only full roster reads.
- Permission failures, event deletion, organizer changes and logout clear roster
  data; subscriptions and stale callbacks are guarded and cancelled on disposal.
- New registrations include an optional displayName snapshot (up to 100 code
  points) from Firebase Auth. It is a self-declared label, not an authorization
  identity; UID remains visible and determines permissions. Existing registrations
  without a name continue to work using UID. Missing dates show Date unavailable.
- No reads of other users' private profiles; no profile/email permissions widened.

## Firebase changes
- firestore.rules accepts and validates optional displayName on registration
  creation, preserving old two-field registrations and registration immutability.
- Existing organizer read rule, self-registration access, collection-group query
  constraints and transactional capacity checks retained.
- No new index or platform config required for this phase: roster sorting is
  client-side. The My Events group index from phase 4 is still required there.
- No deployment was performed. Publish updated rules before using a new build
  that writes displayName against production. Compare current deployed rules first:
    firebase deploy --only firestore:rules --project eventhub-fae97

## Files
Created:
- lib/features/events/models/participant.dart
- lib/features/events/bloc/participants_cubit.dart
- lib/features/events/screens/participants_screen.dart
- test/participant_test.dart
- test/participants_cubit_test.dart
- test/participants_widget_test.dart
- test/support/roster_store.dart
- docs/phase-5-review.md
Modified this phase:
- lib/features/events/repositories/event_repository.dart
- lib/features/events/screens/event_details_screen.dart
- firestore.rules
- test/event_bloc_test.dart
- test/event_management_widget_test.dart
- tools/firestore-tests/rules.test.mjs
Previous-phase changes remain uncommitted.

## Validation
- Firestore demo emulator: all 21 tests passed, including organizer roster access,
  forbidden full-roster reads by participants/strangers/anonymous users, private
  profiles, prohibition of organizer participant edits/cancellation, optional name
  validation and all prior transaction/query tests.
- Flutter coverage includes dates/name fallbacks/sorting, authorization before
  subscription, live updates, revocation, event deletion, errors/retry, logout,
  subscription cleanup, organizer navigation and prior phases.
- Emulator security tests use JS SDK clients and real rules. Flutter state/widget
  tests use repository fakes. Authenticated production end-to-end flows were not
  exercised and production rules are not assumed deployed.

## Next phase
Event discovery: search by title/location, category/date filters and sorting.
Suggested commit: feat(events): add organizer participant roster and registration dates
No commit or push performed.

Android validation: debug APK built, installed and launched on emulator-5554.
Existing Java native-access and Firebase plugin Kotlin Gradle warnings remain.
No authenticated production roster flow was exercised. Dart formatting and
git diff --check passed.
Final Flutter validation: flutter analyze reported No issues found; all 43 tests passed.
