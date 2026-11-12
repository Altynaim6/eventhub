# Phase 1: inspection and event state reliability

## Inspected baseline
- Existing feature-based Flutter app: auth and events, Firebase Auth/Firestore,
  flutter_bloc, equatable, Material 3 purple theme.
- Reviewed pubspec, main, all auth and event sources, existing widget test,
  generated Firebase options and firebase.json. Initial Git working tree was clean.
- Firebase project remains eventhub-fae97. No local Firestore rules or indexes
  were found; deployed rules were not inspected or changed.
- Existing create flow validates form input; repository supports CRUD and owner
  checks. Details registration button is disabled; editing/deletion have no UI.

## Findings and changes
The original EventBloc mixed stream snapshots with write lifecycle states.
Snapshots could re-enable submission while a write was pending, and write errors
replaced the home list. Concurrent load requests could create multiple listeners.

EventBloc now owns list loading only. EventOperationBloc owns writes and is
provided per create route. Its pending/success/error state survives snapshots,
with a shared guard against duplicate and cross-type concurrent writes.
List subscriptions are guarded, replaceable after failure, and cancelled on close.
An EventStore interface permits isolated tests without Firebase initialization;
production still uses EventRepository and real Firestore.

Affected sources: event_bloc.dart, new event_operation_bloc.dart,
event_repository.dart, create_event_screen.dart, home_screen.dart.
New regression coverage: test/event_bloc_test.dart. Existing widget test formatted.
No dependencies, document schema, auth behavior, or Firebase configuration changed.

## Remaining work
- Phase 2: expose edit/delete with confirmation and organizer permissions;
  add and test server-enforced Firestore rules alongside these features.
- Registration, transactional capacity, My Events, participants, discovery,
  profile, bottom navigation, localization, full documentation remain pending.
- Existing auth handlers mix stream transitions and command completion; account
  creation can authenticate before profile persistence completes. Review in a
  dedicated auth phase while preserving current behavior.
- Model decoding uses strict casts: incomplete legacy documents can fail the list.
- Client owner checks are not a substitute for verified deployed security rules.
- No authenticated real-Firestore end-to-end test was executed in phase 1.

Suggested commit: fix(events): isolate write operations from realtime list state
No commit or push was performed.

## Validation
- flutter test: 5 tests passed (4 new BLoC regression tests and existing widget smoke test).
- flutter analyze: No issues found.
- Dart formatter applied to affected Dart files and tests; git diff --check passed.
- Android emulator detected; debug build/run attempted (result recorded below).
- Android: debug APK built, installed on emulator-5554; Flutter engine started. Authenticated UI flows were not exercised. Build emitted Java native-access and Firebase plugins Kotlin Gradle compatibility warnings.
