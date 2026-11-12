import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub/features/events/models/event_model.dart';
import 'package:eventhub/features/events/bloc/participants_cubit.dart';
import 'package:eventhub/features/events/models/participant.dart';

import 'event_bloc_test.dart' show sample, flushEvents;
import 'support/roster_store.dart';

void main() {
  late RosterStore store;
  late ParticipantsCubit cubit;
  setUp(() async {
    store = RosterStore();
    cubit = ParticipantsCubit(store, '1', 'organizer');
    await flushEvents();
  });
  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
    await store.dispose();
  });
  test(
    'subscribes to roster only after organizer check and reuses subscription',
    () async {
      expect(store.rosterCalls, 0);
      store.events.add(sample);
      await flushEvents();
      store.participants.add([const Participant(userId: 'alice')]);
      await flushEvents();
      expect(cubit.state.status, ParticipantsStatus.ready);
      expect(cubit.state.participants, hasLength(1));
      store.events.add(sample);
      await flushEvents();
      expect(store.rosterCalls, 1);
      store.participants.add([]);
      await flushEvents();
      expect(cubit.state.participants, isEmpty);
    },
  );
  test('non-organizer never opens roster', () async {
    await cubit.close();
    cubit = ParticipantsCubit(store, '1', 'stranger');
    await flushEvents();
    store.events.add(sample);
    await flushEvents();
    expect(cubit.state.status, ParticipantsStatus.denied);
    expect(store.rosterCalls, 0);
  });
  test(
    'ownership change clears roster and rejects late participant updates',
    () async {
      store.events.add(sample);
      await flushEvents();
      store.participants.add([const Participant(userId: 'alice')]);
      await flushEvents();
      store.events.add(
        EventModel.fromMap(sample.id, {
          ...sample.toFirestore(),
          'createdAt': null,
          'organizerId': 'new-owner',
        }),
      );
      await flushEvents();
      store.participants.add([const Participant(userId: 'late')]);
      await flushEvents();
      expect(cubit.state.status, ParticipantsStatus.denied);
      expect(cubit.state.participants, isEmpty);
      expect(store.participants.hasListener, false);
    },
  );

  test('deleted event clears sensitive data and unsubscribes', () async {
    store.events.add(sample);
    await flushEvents();
    store.participants.add([const Participant(userId: 'alice')]);
    await flushEvents();
    store.events.add(null);
    await flushEvents();
    expect(cubit.state.status, ParticipantsStatus.missing);
    expect(cubit.state.participants, isEmpty);
    expect(store.participants.hasListener, false);
  });
  test('permission error clears data; retry replaces subscriptions', () async {
    store.events.add(sample);
    await flushEvents();
    store.participants.add([const Participant(userId: 'alice')]);
    await flushEvents();
    store.participants.addError(StateError('permission-denied'));
    await flushEvents();
    expect(cubit.state.participants, isEmpty);
    expect(cubit.state.status, ParticipantsStatus.error);
    await Future.wait([cubit.reload(), cubit.reload()]);
    store.events.add(sample);
    await flushEvents();
    store.participants.add([]);
    await flushEvents();
    expect(cubit.state.status, ParticipantsStatus.ready);
    expect(store.rosterCalls, 2);
  });
  test(
    'event stream error clears roster and close cancels both streams',
    () async {
      store.events.add(sample);
      await flushEvents();
      store.participants.add([const Participant(userId: 'alice')]);
      await flushEvents();
      store.events.addError(StateError('offline'));
      await flushEvents();
      expect(cubit.state.participants, isEmpty);
      expect(store.participants.hasListener, false);
      await cubit.close();
      expect(store.events.hasListener, false);
    },
  );
}
