import 'dart:async';

import 'package:eventhub/features/events/models/event_model.dart';
import 'package:eventhub/features/events/models/participant.dart';

import '../event_bloc_test.dart' show TestStore;

class RosterStore extends TestStore {
  final events = StreamController<EventModel?>.broadcast();
  final participants = StreamController<List<Participant>>.broadcast();
  int rosterCalls = 0;
  @override
  Stream<EventModel?> watchEvent(String eventId) => events.stream;
  @override
  Stream<List<Participant>> watchParticipants(String eventId) {
    rosterCalls++;
    return participants.stream;
  }

  Future<void> dispose() async {
    if (!result.isCompleted) result.complete('1');
    await events.close();
    await participants.close();
    await updates.close();
  }
}
