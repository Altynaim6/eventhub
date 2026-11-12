import 'package:flutter/material.dart';
import 'package:eventhub/features/events/models/event_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub/features/auth/bloc/auth_bloc.dart';
import 'package:eventhub/features/auth/bloc/auth_state.dart';
import 'package:eventhub/features/events/bloc/event_bloc.dart';
import 'package:eventhub/features/events/bloc/event_operation_bloc.dart';
import 'package:eventhub/features/events/screens/event_details_screen.dart';

import 'event_bloc_test.dart' show TestStore, sample;

class SessionBloc extends Cubit<AuthState> implements AuthBloc {
  SessionBloc(String uid) : super(AuthAuthenticated(uid));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<TestStore> open(
    WidgetTester tester,
    String uid, {
    EventModel? event,
    bool registered = false,
  }) async {
    final store = TestStore();
    store.currentEvent = event ?? sample;
    store.isRegistered = registered;
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(create: (_) => SessionBloc(uid)),
          BlocProvider(create: (_) => EventBloc(store)),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider(
                        create: (_) => EventOperationBloc(store),
                        child: EventDetailsScreen(event: sample),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    addTearDown(() async {
      if (!store.result.isCompleted) store.result.complete('1');
      await tester.pumpWidget(const SizedBox());
      await store.updates.close();
    });
    return store;
  }

  testWidgets('non-owner has no edit or delete actions', (tester) async {
    await open(tester, 'other');
    expect(find.byTooltip('Edit Event'), findsNothing);
    expect(find.byTooltip('Delete Event'), findsNothing);
    expect(find.byTooltip('Participants'), findsNothing);
  });
  testWidgets('register and cancel keep details open and show busy status', (
    tester,
  ) async {
    final store = await open(tester, 'other');
    expect(find.text('10 places available • 0 registered'), findsOneWidget);
    await tester.tap(find.text('Register for Event'));
    await tester.pump();
    expect(store.writes, 1);
    expect(find.text('Saving...'), findsOneWidget);
    store.result.complete('1');
    await tester.pumpAndSettle();
    expect(find.text('You are registered'), findsOneWidget);
    expect(find.text('Event Details'), findsOneWidget);
    await tester.tap(find.text('Cancel Registration'));
    await tester.pumpAndSettle();
    expect(store.writes, 2);
    expect(find.text('Register for Event'), findsOneWidget);
  });

  testWidgets('full event disables registration', (tester) async {
    await open(
      tester,
      'other',
      event: EventModel(
        id: sample.id,
        title: sample.title,
        description: sample.description,
        category: sample.category,
        date: sample.date,
        location: sample.location,
        capacity: 1,
        registeredCount: 1,
        organizerId: sample.organizerId,
      ),
    );
    expect(find.text('Event Full'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Event Full'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('registered user can cancel after event starts', (tester) async {
    final store = await open(
      tester,
      'other',
      registered: true,
      event: EventModel(
        id: sample.id,
        title: sample.title,
        description: sample.description,
        category: sample.category,
        date: DateTime(2020),
        location: sample.location,
        capacity: 1,
        registeredCount: 1,
        organizerId: sample.organizerId,
      ),
    );
    await tester.tap(find.text('Cancel Registration'));
    await tester.pump();
    expect(store.writes, 1);
    store.result.complete('1');
    await tester.pumpAndSettle();
    expect(find.text('Registration Closed'), findsOneWidget);
  });

  testWidgets('organizer opens participant roster from event details', (
    tester,
  ) async {
    await open(tester, 'organizer');
    await tester.tap(find.byTooltip('Participants'));
    await tester.pumpAndSettle();
    expect(find.text('No participants yet'), findsOneWidget);
    expect(find.textContaining('Participants: 0 / 10'), findsOneWidget);
  });

  testWidgets('editor prefills existing event', (tester) async {
    await open(tester, 'organizer');
    await tester.tap(find.byTooltip('Edit Event'));
    await tester.pumpAndSettle();
    expect(find.text('Event'), findsOneWidget);
    expect(find.text('Description'), findsWidgets);
    expect(find.text('Bishkek'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
  });
  testWidgets('saving edited event updates details only after success', (
    tester,
  ) async {
    final store = await open(tester, 'organizer');
    await tester.tap(find.byTooltip('Edit Event'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Updated event');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    expect(store.writes, 1);
    expect(find.text('Saving...'), findsOneWidget);
    store.result.complete('1');
    await tester.pumpAndSettle();
    expect(find.text('Event Details'), findsOneWidget);
    expect(find.text('Updated event'), findsOneWidget);
  });

  testWidgets('cancel deletion keeps event; confirm waits then returns home', (
    tester,
  ) async {
    final store = await open(tester, 'organizer');
    await tester.tap(find.byTooltip('Delete Event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.writes, 0);
    await tester.tap(find.byTooltip('Delete Event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(store.writes, 1);
    expect(find.text('Event Details'), findsOneWidget);
    store.result.complete('1');
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });
}
