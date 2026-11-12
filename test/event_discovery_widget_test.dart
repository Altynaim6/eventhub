import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub/features/auth/bloc/auth_bloc.dart';
import 'package:eventhub/features/auth/screens/home_screen.dart';
import 'package:eventhub/features/events/bloc/event_bloc.dart';
import 'package:eventhub/features/events/bloc/event_discovery_cubit.dart';
import 'package:eventhub/features/events/models/event_model.dart';
import 'package:eventhub/features/events/widgets/event_card.dart';

import 'event_bloc_test.dart' show TestStore;
import 'event_management_widget_test.dart' show SessionBloc;
import 'support/discovery_events.dart';

void main() {
  late TestStore store;
  final source = [
    discoveryEvent('campus'),
    discoveryEvent(
      'music',
      title: 'Music Night',
      location: 'Osh',
      category: 'Music',
      date: DateTime(2030, 6, 11),
      capacity: 30,
    ),
    discoveryEvent(
      'science',
      title: 'Илим күнү',
      location: 'Бишкек',
      date: DateTime(2030, 6, 12),
    ),
  ];
  Future<void> open(WidgetTester tester, {List<EventModel>? events}) async {
    store = TestStore();
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(create: (_) => SessionBloc('organizer')),
          BlocProvider(create: (_) => EventBloc(store)),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
    store.updates.add(events ?? source);
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await store.updates.close();
    });
  }

  EventDiscoveryCubit filters(WidgetTester tester) =>
      tester.element(find.byType(TextField)).read<EventDiscoveryCubit>();
  testWidgets(
    'search by title and location, Cyrillic and reset with one subscription',
    (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), '  MUSIC osh ');
      await tester.pumpAndSettle();
      expect(find.text('1 events found'), findsOneWidget);
      expect(find.text('Music Night'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'ИЛИМ');
      await tester.pumpAndSettle();
      expect(find.text('Илим күнү'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('3 events found'), findsOneWidget);
      expect(store.subscriptions, 1);
    },
  );
  testWidgets(
    'category selection persists when snapshots remove its last result',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('All categories'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Music').last);
      await tester.pumpAndSettle();
      expect(find.text('Music Night'), findsOneWidget);
      store.updates.add([source.first]);
      await tester.pumpAndSettle();
      expect(
        find.text('No events match your search and filters'),
        findsOneWidget,
      );
      expect(filters(tester).state.category, 'Music');
      await tester.tap(find.text('Reset filters'));
      await tester.pumpAndSettle();
      expect(find.text('Campus Talk'), findsOneWidget);
      expect(find.text('All categories'), findsOneWidget);
    },
  );
  testWidgets(
    'date dropdown filters today and cancelled range preserves selection',
    (tester) async {
      final now = DateTime.now();
      await open(
        tester,
        events: [
          discoveryEvent('today', date: now),
          discoveryEvent(
            'past',
            date: DateTime(now.year, now.month, now.day - 1),
          ),
        ],
      );
      await tester.tap(find.text('All dates'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today').last);
      await tester.pumpAndSettle();
      expect(find.text('1 events found'), findsOneWidget);
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom range').last);
      await tester.pumpAndSettle();
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('1 events found'), findsOneWidget);
    },
  );

  testWidgets('sort selection changes event order and survives live updates', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Date: earliest first'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Date: latest first').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<EventCard>(find.byType(EventCard).first).event.id,
      'science',
    );
    store.updates.add([source.first, source[1]]);
    await tester.pumpAndSettle();
    expect(
      tester.widget<EventCard>(find.byType(EventCard).first).event.id,
      'music',
    );
    expect(store.subscriptions, 1);
  });
  testWidgets(
    'custom range updates result count and cancellation keeps criteria',
    (tester) async {
      await open(tester);
      filters(tester)
          .setDateRange(DateTime(2030, 6, 11), DateTime(2030, 6, 11));
      await tester.pumpAndSettle();
      expect(find.text('1 events found'), findsOneWidget);
      expect(find.text('11.06.2030 – 11.06.2030'), findsOneWidget);
      await tester.tap(find.text('11.06.2030 – 11.06.2030'));
      await tester.pumpAndSettle();
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('1 events found'), findsOneWidget);
      await tester.tap(find.text('Reset filters'));
      await tester.pumpAndSettle();
      expect(find.text('3 events found'), findsOneWidget);
    },
  );
  testWidgets(
    'empty database differs from unmatched search; errors preserve query',
    (tester) async {
      await open(tester, events: []);
      expect(find.text('No events yet'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pump();
      store.updates.add(source);
      await tester.pumpAndSettle();
      expect(
        find.text('No events match your search and filters'),
        findsOneWidget,
      );
      store.updates.addError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.textContaining('offline'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'missing',
      );
      await tester.tap(find.text('Retry'));
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      store.updates.add(source);
      await tester.pumpAndSettle();
      expect(
        find.text('No events match your search and filters'),
        findsOneWidget,
      );
      expect(store.subscriptions, 2);
    },
  );
  testWidgets('narrow screen with keyboard stays scrollable', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester);
    await tester.showKeyboard(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
  });
}
