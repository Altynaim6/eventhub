# Phase 4: My Events

## Implemented
- My Events opens from Home's app bar and provides Created and Registered tabs.
- Created events link to the existing organizer editor/delete actions in details.
- Registered events support direct cancellation with confirmation, per-event
  pending state, duplicate-submission guard and success/error messages.
- Both lists update in real time, have independent loading/empty/error states,
  and support retry. Subscriptions are disposed on route exit/logout/account
  change. An event may appear in both lists if its organizer also registered.
- Repository queries created events by organizerId and registrations using a
  collection-group query constrained by the current Firebase user's userId.
- A tested stream join listens only to referenced event documents, sorts by
  date, skips missing events, reuses listeners for unchanged IDs and removes
  listeners after cancellation. Event edits/capacity changes remain live.
- Existing transactional cancellation and organizer permission checks reused.
  No dependencies or registration document schema changed.

## Firebase changes and manual setup
- firestore.rules adds a list-only recursive registration group rule requiring
  resource.data.userId to equal request.auth.uid. Query must constrain this field.
  Existing per-event organizer access and all mutation protections are preserved.
- New firestore.indexes.json adds an ascending COLLECTION_GROUP index on
  registrations.userId, preserving its standard collection-scope indexes.
- firebase.json now references this index file. Platform configuration unchanged.
- Nothing was deployed. Production requires the updated rules AND this index.
  Before deployment compare/merge current deployed rules and any existing indexes.
  Intended commands from the repository root after review:
    firebase deploy --only firestore:rules --project eventhub-fae97
    firebase deploy --only firestore:indexes --project eventhub-fae97
  Alternatively enable the single-field collection-group ascending index for
  registrations.userId in the Firebase console. Wait for the index to finish
  building before testing the Registered tab. Emulator does not validate
  production index availability.
Reference: https://firebase.google.com/docs/firestore/security/rules-query
Reference: https://firebase.google.com/docs/firestore/query-data/index-overview

## Files
Created:
- lib/features/events/bloc/my_events_cubit.dart
- lib/features/events/screens/my_events_screen.dart
- lib/features/events/repositories/registered_events_stream.dart
- firestore.indexes.json
- test/my_events_cubit_test.dart
- test/my_events_widget_test.dart
- test/registered_events_stream_test.dart
- test/support/my_store.dart
- docs/phase-4-review.md
Modified this phase:
- lib/features/auth/screens/home_screen.dart
- lib/features/events/repositories/event_repository.dart
- test/event_bloc_test.dart
- firestore.rules
- firebase.json
- tools/firestore-tests/rules.test.mjs
Earlier phase changes are still present and uncommitted.

## Validation
- Firestore demo emulator: 18 security/transaction tests passed, including own
  registration group queries, denial of foreign/unfiltered/anonymous queries,
  cancellation removing the queried registration and all earlier regressions.
- Flutter tests cover list state, errors/retry, duplicate cancellation, subscription
  lifecycle, referenced-document joins, navigation/management, empty states,
  confirmation and cancellation, logout and previous-phase behavior.
- No authenticated production Firebase end-to-end test or deployment performed.

Next phase: organizer-only participant list, registration dates and counts.
Suggested commit: feat(events): add live created and registered event lists
No commit or push performed.

Final results: flutter analyze reported No issues found; all 29 Flutter tests
passed. Dart formatting and git diff --check passed. Android debug APK was
built, installed and launched on emulator-5554. Existing Java native-access
and Firebase plugins Kotlin Gradle warnings remain. Emulator tests do not
validate index deployment; real-account production My Events testing remains
to be performed after deploying the rules and index.
