import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub/features/auth/bloc/auth_bloc.dart';
import 'package:eventhub/features/auth/bloc/auth_state.dart';
import 'package:eventhub/features/auth/screens/home_screen.dart';
import 'package:eventhub/features/events/bloc/event_bloc.dart';
import 'package:eventhub/features/events/screens/my_events_screen.dart';

import 'event_bloc_test.dart' show sample;
import 'event_management_widget_test.dart' show SessionBloc;
import 'support/my_store.dart';

class MySession extends SessionBloc {
  MySession() : super('organizer');
  void signOut() => emit(AuthUnauthenticated());
}

void main() {
  late MyStore store;
  late MySession auth;
  Future<void> open(
    WidgetTester tester, {
    bool empty = false,
    bool home = false,
  }) async {
    store = MyStore();
    auth = MySession();
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: auth),
          BlocProvider(create: (_) => EventBloc(store)),
        ],
        child: MaterialApp(
          home: home ? const HomeScreen() : const MyEventsScreen(),
        ),
      ),
    );
    await tester.pump();
    if (home) {
      await tester.tap(find.widgetWithText(NavigationDestination, 'My Events'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
    store.created.add(empty ? [] : [sample]);
    store.registered.add(empty ? [] : [sample]);
    await tester.pumpAndSettle();
    addTearDown(() async {
      if (!store.result.isCompleted) store.result.complete('1');
      await tester.pumpWidget(const SizedBox());
      await auth.close();
      await store.dispose();
    });
  }

  testWidgets('home opens my events; manage shows owner actions', (
    tester,
  ) async {
    await open(tester, home: true);
    expect(find.text('Created'), findsOneWidget);
    await tester.tap(find.text('Manage Event'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Edit Event'), findsOneWidget);
    expect(find.byTooltip('Delete Event'), findsOneWidget);
  });
  testWidgets('both tabs have distinct empty states', (tester) async {
    await open(tester, empty: true);
    expect(find.text('You have not created any events yet'), findsOneWidget);
    await tester.tap(find.text('Registered'));
    await tester.pumpAndSettle();
    expect(find.text('You have no event registrations'), findsOneWidget);
  });
  testWidgets('cancel confirmation, pending state and live list removal', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Registered'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel Registration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep Registration'));
    await tester.pumpAndSettle();
    expect(store.writes, 0);
    await tester.tap(find.text('Cancel Registration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Cancellation'));
    await tester.pumpAndSettle();
    expect(store.writes, 1);
    expect(find.text('Cancelling...'), findsOneWidget);
    store.result.complete('1');
    store.registered.add([]);
    await tester.pumpAndSettle();
    expect(find.text('You have no event registrations'), findsOneWidget);
    expect(find.text('My Events'), findsOneWidget);
  });
  testWidgets('query error shows retry and recovers', (tester) async {
    await open(tester);
    store.registered.addError(StateError('index missing'));
    await tester.pump();
    await tester.tap(find.text('Registered'));
    await tester.pumpAndSettle();
    expect(find.textContaining('index missing'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    expect(store.registeredCalls, 2);
    store.created.add([]);
    store.registered.add([sample]);
    await tester.pumpAndSettle();
    expect(find.text('Cancel Registration'), findsOneWidget);
  });
  testWidgets('logout removes personal data and subscriptions', (tester) async {
    await open(tester);
    auth.signOut();
    await tester.pumpAndSettle();
    expect(find.text('Please log in to view your events'), findsOneWidget);
    expect(find.text('Event'), findsNothing);
    expect(store.created.hasListener, false);
    expect(store.registered.hasListener, false);
  });
}
