# Phase 6: discovery search, filters and sorting

## Implemented
- Home discovery searches event title and location using case-insensitive
  substrings, including Cyrillic/Kyrgyz text. Whitespace-separated words are
  combined with AND; each word may match either title or location.
- Category selection includes standard and existing legacy categories. A selected
  category survives snapshots even if its last event disappears.
- Date presets: All dates, Upcoming, Today, Next 7 days, Custom range.
  Today uses the device's local calendar day. Next 7 days includes today and the
  following six days. Upcoming starts at the current instant. Custom range includes
  the entire final calendar day; invalid reverse ranges are rejected.
- Sorting: date ascending/descending, case-insensitive title, most available
  places descending, with deterministic date/ID tie-breaks. Title order is Dart
  string order, not locale-specific dictionary collation.
- Result count, clear search/reset criteria, empty database vs no-match messages,
  preserved criteria on errors/retry and live Firestore updates added.
- Responsive controls and sliver-based scroll layout support narrow screens and
  keyboard. Card date/available-place text now wraps within the available width.
- Date-dependent results refresh every minute; the timer is disposed with Home.

## Architecture and Firebase
EventDiscoveryCubit owns criteria independently of EventBloc list loading and
CRUD navigation states. A pure immutable filter model applies them to each real
Firestore snapshot. Search/filter changes create no additional subscriptions or
writes. Existing Firebase repositories, rules, schema and indexes are unchanged.

Filtering is local over the entire existing event stream. This is appropriate
for the current project dataset but does not reduce Firestore read volume. A
large production catalogue would need pagination and a dedicated search strategy.
No dependencies, Firebase deployments or production data writes were introduced.
No new manual Firebase settings are needed for this phase. Existing prior-phase
rules/index deployment requirements still apply.

## Files
Created:
- lib/features/events/models/event_discovery_filters.dart
- lib/features/events/bloc/event_discovery_cubit.dart
- lib/features/events/widgets/event_discovery_view.dart
- test/event_discovery_filters_test.dart
- test/event_discovery_cubit_test.dart
- test/event_discovery_widget_test.dart
- test/support/discovery_events.dart
- docs/phase-6-review.md
Modified this phase:
- lib/features/auth/screens/home_screen.dart
- lib/features/events/widgets/event_card.dart
Earlier phases remain uncommitted.

## Validation coverage
- Pure filter/Cubit tests: title/location/Cyrillic search, combined criteria,
  local/UTC date boundaries, final-day inclusivity, year boundaries, all sort
  modes, immutable source/results, reset and invalid date ranges.
- Widget tests: search/clear, dynamic categories, live updates with one
  subscription, sort order, custom range/cancel, date dropdown, retry preserving
  query, empty states and narrow layout with keyboard.
- Existing authentication/event/participant/My Events regressions included in
  the full Flutter suite. No production authenticated end-to-end flow exercised.
- Firestore rules and operations were not changed in this phase, so the unchanged
  emulator security suite was not rerun.

Next phase: user profile, editing, statistics, password reset and logout.
Suggested commit: feat(events): add discovery search filters and sorting
No commit or push performed.

Final results: flutter analyze reported No issues found; all 58 Flutter tests
passed. Android debug APK was built, installed and launched on emulator-5554.
Existing Java native-access and Firebase plugin Kotlin Gradle warnings remain.
Dart formatting and git diff --check passed.
