import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub/features/events/bloc/event_bloc.dart';
import 'package:eventhub/features/events/bloc/event_operation_bloc.dart';
import 'package:eventhub/features/events/bloc/event_event.dart';
import 'package:eventhub/features/events/bloc/event_state.dart';
import 'package:eventhub/features/events/models/event_model.dart';
import 'package:eventhub/features/events/models/participant.dart';
import 'package:eventhub/features/events/repositories/event_repository.dart';

class TestStore implements EventStore {
  int subscriptions = 0;
  int writes = 0;
  final updates = StreamController<List<EventModel>>.broadcast();
  Completer<String> result = Completer<String>();

  @override
  Stream<List<EventModel>> getEvents() {
    subscriptions++;
    return updates.stream;
  }

  @override
  Stream<List<EventModel>> getMyEvents() => Stream.value([]);
  @override
  Stream<List<EventModel>> getRegisteredEvents() => Stream.value([]);

  @override
  Stream<List<Participant>> watchParticipants(String eventId) =>
      Stream.value([]);

  bool isRegistered = false;
  EventModel currentEvent = sample;
  @override
  Stream<EventModel?> watchEvent(String id) => Stream.value(currentEvent);
  @override
  Stream<bool> watchRegistration(String id) => Stream.value(isRegistered);
  @override
  Future<void> registerForEvent(String id) async {
    writes++;
    await result.future;
  }

  @override
  Future<void> cancelRegistration(String id) async {
    writes++;
    await result.future;
  }

  @override
  Future<String> createEvent(EventModel event) {
    writes++;
    return result.future;
  }

  @override
  Future<void> updateEvent(EventModel event) async {
    writes++;
    await result.future;
  }

  @override
  Future<void> deleteEvent(String id) async {
    writes++;
    await result.future;
  }
}

final sample = EventModel(
  id: '1',
  title: 'Event',
  description: 'Description',
  category: 'Other',
  date: DateTime(2030),
  location: 'Bishkek',
  capacity: 10,
  organizerId: 'organizer',
);

Future<void> flushEvents() => Future<void>.delayed(Duration.zero);

void main() {
  late TestStore store;
  late EventBloc list;
  late EventOperationBloc operations;
  setUp(() {
    store = TestStore();
    list = EventBloc(store);
    operations = EventOperationBloc(store);
  });
  tearDown(() async {
    if (!store.result.isCompleted) store.result.complete('1');
    await operations.close();
    await list.close();
    await store.updates.close();
  });

  test(
    'snapshots preserve pending write and success navigation state',
    () async {
      list.add(const LoadEvents());
      operations.add(CreateEvent(sample));
      await flushEvents();
      store.updates.add([sample]);
      await flushEvents();
      expect(list.state, isA<EventLoaded>());
      expect(operations.state, isA<EventOperationInProgress>());
      store.result.complete('1');
      await flushEvents();
      store.updates.add([]);
      await flushEvents();
      expect(operations.state, isA<EventOperationSuccess>());
    },
  );

  test('rejects duplicate and cross-type writes while busy', () async {
    operations.add(CreateEvent(sample));
    operations.add(CreateEvent(sample));
    operations.add(const DeleteEvent('1'));
    await flushEvents();
    expect(store.writes, 1);
  });

  test('write failure preserves list and permits retry', () async {
    list.add(const LoadEvents());
    await flushEvents();
    store.updates.add([sample]);
    operations.add(CreateEvent(sample));
    await flushEvents();
    store.result.completeError(StateError('write failed'));
    await flushEvents();
    expect(operations.state, isA<EventError>());
    expect((list.state as EventLoaded).events, [sample]);
    store.result = Completer<String>();
    operations.add(CreateEvent(sample));
    await flushEvents();
    expect(store.writes, 2);
  });

  test(
    'simultaneous loads use one subscription and retry replaces it',
    () async {
      list.add(const LoadEvents());
      list.add(const LoadEvents());
      await flushEvents();
      expect(store.subscriptions, 1);
      store.updates.addError(StateError('offline'));
      await flushEvents();
      expect(list.state, isA<EventError>());
      list.add(const LoadEvents());
      await flushEvents();
      store.updates.add([sample]);
      await flushEvents();
      expect(store.subscriptions, 2);
      expect(list.state, isA<EventLoaded>());
    },
  );
}
