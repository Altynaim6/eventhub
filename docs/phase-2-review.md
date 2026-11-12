# Phase 2: event editing, deletion and Firestore access control

## Implementation
- Reused CreateEventScreen as an editor, prefilling all fields and preserving
  event ID, organizer and creation metadata (including legacy categories).
- Organizer actions on details: edit, delete, confirmation, busy protection,
  asynchronous errors and navigation only after a successful write.
- Editing returns the saved model to details. Home continues receiving real-time
  Firestore updates. Each editor and details route has its own operation BLoC.
- UI checks authenticated organizer through AuthBloc; repository checks current
  Firebase user against stored organizer before update/delete. Rules enforce
  permissions on the server regardless of the client.
- Repository validates nonempty fields, positive capacity and a future date.
- New firestore.rules permits authenticated event reads, owner-only mutations,
  immutable owner/metadata, an allowlist of editable fields and field validation.
  Profiles are private, with self-only creation and name updates. Unimplemented
  collections and nested registrations remain denied.
- Legacy event documents without createdAt remain editable/deletable. Existing
  optional fields survive edits but cannot be changed through this phase's rules.

## Files
Created: firestore.rules, test/event_management_widget_test.dart,
  tools/firestore-tests/package.json, tools/firestore-tests/package-lock.json,
  tools/firestore-tests/rules.test.mjs, this report.
Modified this phase: create_event_screen.dart, event_details_screen.dart,
  home_screen.dart, event_repository.dart, firebase.json, .gitignore.
Earlier phase changes remain in the working tree.

## Firebase configuration
firebase.json now references firestore.rules; existing generated platform
configuration is preserved. No Firebase deployment or production data writes
were performed. Local rules do not protect production until deployed.
Before deployment, compare against currently deployed rules, which have not
been retrieved. Intended deployment command after review:
  firebase deploy --only firestore:rules --project eventhub-fae97

## Reproduce rules tests
  cd tools/firestore-tests
  npm ci
  cd ../..
  firebase emulators:exec --only firestore --project demo-eventhub "npm.cmd --prefix tools/firestore-tests test"
Requires Firebase CLI, Node and a Java version supported by the installed CLI.
These tests use a local demo project, never production Firestore.
Reference: https://firebase.google.com/docs/rules/unit-tests

## Scope and next phase
Registration and participant capacity enforcement will be implemented with
transactions and corresponding rules in the next phase. No registrations exist
in the current schema. Authenticated real-data end-to-end flows were not tested.
No commit or push performed.
Suggested commit: feat(events): add organizer editing deletion and Firestore rules

## Validation results
- flutter test: all 9 tests passed, including four event management widget tests.
- flutter analyze: No issues found.
- Firestore emulator: all 6 security tests passed; no production access.
- git diff --check passed; affected Dart files formatted.
- npm audit initially found a vulnerable transitive grpc-js version. Added a
  test-only override to ^1.13.6; reinstall reports 0 vulnerabilities.
- Authenticated production Firestore end-to-end testing and rules deployment
  remain outside this validation; phase 2 Android rebuild was not run.
