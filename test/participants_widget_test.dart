import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub/features/auth/bloc/auth_bloc.dart';
import 'package:eventhub/features/auth/bloc/auth_state.dart';
import 'package:eventhub/features/events/bloc/event_bloc.dart';
import 'package:eventhub/features/events/models/participant.dart';
import 'package:eventhub/features/events/screens/participants_screen.dart';

import 'event_bloc_test.dart' show sample;
import 'event_management_widget_test.dart' show SessionBloc;
import 'support/roster_store.dart';

class RosterSession extends SessionBloc {
  RosterSession(super.uid);
  void logout() => emit(AuthUnauthenticated());
}

void main() {
  late RosterStore store;
  late RosterSession auth;
  Future<void> open(
    WidgetTester tester, {
    String uid = 'organizer',
    bool empty = false,
  }) async {
    store = RosterStore();
    auth = RosterSession(uid);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: auth),
          BlocProvider(create: (_) => EventBloc(store)),
        ],
        child: const MaterialApp(home: ParticipantsScreen(eventId: '1')),
      ),
    );
    await tester.pump();
    store.events.add(sample);
    await tester.pump();
    store.participants.add(
      empty
          ? []
          : [
              Participant(
                userId: 'alice',
                displayName: 'Alice',
                registeredAt: DateTime(2026, 11, 11, 9, 30),
              ),
            ],
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await auth.close();
      await store.dispose();
    });
  }

  testWidgets(
    'organizer sees names, registration dates and live participant count',
    (tester) async {
      await open(tester);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.textContaining('11.11.2026 09:30'), findsOneWidget);
      expect(find.textContaining('Participants: 1 / 10'), findsOneWidget);
      store.participants.add([]);
      await tester.pumpAndSettle();
      expect(find.text('No participants yet'), findsOneWidget);
      expect(find.textContaining('Participants: 0 / 10'), findsOneWidget);
    },
  );
  testWidgets('direct navigation by non-owner is denied', (tester) async {
    await open(tester, uid: 'stranger');
    expect(
      find.text('Only the organizer can view participants'),
      findsOneWidget,
    );
    expect(store.rosterCalls, 0);
    expect(find.text('Alice'), findsNothing);
  });
  testWidgets('permission error removes rows and retry recovers', (
    tester,
  ) async {
    await open(tester);
    store.participants.addError(StateError('permission-denied'));
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsNothing);
    expect(find.textContaining('permission-denied'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    store.events.add(sample);
    await tester.pump();
    store.participants.add([]);
    await tester.pumpAndSettle();
    expect(find.text('No participants yet'), findsOneWidget);
  });
  testWidgets('logout clears roster and subscriptions', (tester) async {
    await open(tester);
    auth.logout();
    await tester.pumpAndSettle();
    expect(find.text('Please log in to view participants'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
    expect(store.events.hasListener, false);
    expect(store.participants.hasListener, false);
  });
  testWidgets('legacy records show UID and unavailable date', (tester) async {
    await open(tester, empty: true);
    store.participants.add([const Participant(userId: 'legacy')]);
    await tester.pumpAndSettle();
    expect(find.text('legacy'), findsOneWidget);
    expect(find.textContaining('Date unavailable'), findsOneWidget);
  });
}
