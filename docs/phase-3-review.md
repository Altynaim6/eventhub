# Phase 3: event registration and capacity

## Implemented
- Registration and cancellation through Firestore transactions: read event and
  UID-keyed registration before any writes, then change both registration and
  registeredCount atomically. Concurrent requests retry against current state.
- Duplicate registration/cancellation, full events, missing events, unauthenticated
  requests and registration after the start are rejected. Cancellation remains
  possible after the start. Registration timestamp is server generated.
- Event editing/deletion now use transactions too. Capacity cannot drop below
  registeredCount; events with active participants cannot be deleted, preventing
  orphan registrations. An organizer can delete once all participants cancel.
- Real-time registration panel uses route-scoped RegistrationCubit. Loading,
  busy, error, registered, full and closed states do not trigger editor navigation.
  Repeated taps are guarded; both subscriptions are cancelled on disposal.
- Event cards and details panel display available places. EventModel defaults
  missing registeredCount to zero, preserving phase 2 event documents.

## Data schema
  events/{eventId}.registeredCount: integer, initially zero
  events/{eventId}/registrations/{uid}:
    userId: uid
    registeredAt: server timestamp
New events always start with zero participants. Existing events do not require
migration if no registrations predate this feature. Out-of-band/admin-created
registrations without a corresponding count require administrative reconciliation;
client rules intentionally cannot repair arbitrary inconsistent data.

## Rules
- Count must remain an integer between zero and capacity.
- A count-only update is allowed only together with the authenticated user's
  registration creation/deletion, with exactly +1/-1. getAfter/existsAfter link
  both sides of the atomic operation. Standalone counter or registration writes,
  metadata updates and writes for another user are denied.
- Registration reads are limited to the participant and event organizer.
- Owner metadata updates preserve count; event deletion requires count zero.
- Existing profile protections retained. No indexes or Firebase platform settings
  changed. Rules have not been deployed; production security is not claimed.
Reference: https://firebase.google.com/docs/firestore/manage-data/transactions

## Files this phase
Created:
- lib/features/events/bloc/registration_cubit.dart
- lib/features/events/widgets/event_registration_panel.dart
- test/registration_cubit_test.dart
- test/event_model_test.dart
- docs/phase-3-review.md
Modified:
- lib/features/events/models/event_model.dart
- lib/features/events/repositories/event_repository.dart
- lib/features/events/screens/create_event_screen.dart
- lib/features/events/screens/event_details_screen.dart
- lib/features/events/widgets/event_card.dart
- test/event_bloc_test.dart
- test/event_management_widget_test.dart
- firestore.rules
- tools/firestore-tests/rules.test.mjs
Earlier phase changes remain uncommitted in the working tree.

## Validation
- Firestore demo emulator: 17 tests passed, including concurrent last-slot claims,
  duplicate registration and cancellation, capacity edits racing registration,
  atomic-write bypass attempts, privacy, expired/missing events and phase 2 rules.
  Emulator tests use Firebase JS clients to verify the same two-document protocol
  and server rules; they do not execute the Dart repository on a device.
- Flutter covers registration state, duplicate-submission guard, asynchronous
  failures/retry, disposal, live snapshots, full/closed event UI, registration and
  cancellation navigation, legacy model decoding and previous-phase regressions.
- No production Firebase end-to-end registration was executed.

## Next phase
My Events: created and registered events, management and cancellation actions.
Participant list UI remains a later phase. Rules deployment remains separate.
Suggested commit: feat(events): add transactional registration and capacity enforcement
No commit or push performed.

Final validation: flutter analyze reported No issues found. Android debug APK
was built, installed and launched on emulator-5554. Existing Java native-access
and Firebase plugin Kotlin Gradle warnings remain. Production UI flows were
not exercised. git diff --check passed.
Final Flutter suite: all 17 tests passed.
