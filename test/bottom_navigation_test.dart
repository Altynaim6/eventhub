import 'package:eventhub/features/auth/bloc/auth_bloc.dart';
import 'package:eventhub/features/auth/screens/home_screen.dart';
import 'package:eventhub/features/events/bloc/event_bloc.dart';
import 'package:eventhub/features/events/bloc/event_event.dart';
import 'package:eventhub/features/events/bloc/event_operation_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'event_bloc_test.dart' show sample;
import 'event_management_widget_test.dart' show SessionBloc;
import 'support/my_store.dart';

void main() {
  testWidgets('tabs preserve a draft and successful creation resets it', (
    tester,
  ) async {
    final store = MyStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(create: (_) => SessionBloc('organizer')),
          BlocProvider(create: (_) => EventBloc(store)),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> select(String label) async {
      await tester.tap(find.widgetWithText(NavigationDestination, label));
      await tester.pumpAndSettle();
    }

    await select('Create Event');
    await tester.enterText(find.byType(TextFormField).first, 'Draft');
    await select('Home');
    await select('Create Event');
    expect(find.text('Draft'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );

    await select('Create Event');
    final field = tester.element(find.byType(TextFormField).first);
    field.read<EventOperationBloc>().add(CreateEvent(sample));
    store.result.complete('event-id');
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );

    await select('Create Event');
    expect(find.text('Draft'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
