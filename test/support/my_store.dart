import 'dart:async';

import '../event_bloc_test.dart' show TestStore;

import 'package:eventhub/features/events/models/event_model.dart';

class MyStore extends TestStore {
  final created = StreamController<List<EventModel>>.broadcast();
  final registered = StreamController<List<EventModel>>.broadcast();
  int createdCalls = 0;
  int registeredCalls = 0;
  @override
  Stream<List<EventModel>> getEvents() => Stream.value([]);
  @override
  Stream<List<EventModel>> getMyEvents() {
    createdCalls++;
    return created.stream;
  }

  @override
  Stream<List<EventModel>> getRegisteredEvents() {
    registeredCalls++;
    return registered.stream;
  }

  Future<void> dispose() async {
    if (!result.isCompleted) result.complete('1');
    await created.close();
    await registered.close();
    await updates.close();
  }
}
