import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub/features/events/bloc/registration_cubit.dart';
import 'package:eventhub/features/events/models/event_model.dart';

import 'event_bloc_test.dart' show TestStore, sample, flushEvents;

class LiveStore extends TestStore {
  final events = StreamController<EventModel?>.broadcast();
  final registrations = StreamController<bool>.broadcast();
  @override
  Stream<EventModel?> watchEvent(String id) => events.stream;
  @override
  Stream<bool> watchRegistration(String id) => registrations.stream;
}

void main() {
  late LiveStore store;
  late RegistrationCubit cubit;
  setUp(() {
    store = LiveStore();
    cubit = RegistrationCubit(store, '1');
  });
  tearDown(() async {
    if (!store.result.isCompleted) store.result.complete('1');
    if (!cubit.isClosed) await cubit.close();
    await store.events.close();
    await store.registrations.close();
    await store.updates.close();
  });
  Future<void> ready() async {
    store.events.add(sample);
    store.registrations.add(false);
    await flushEvents();
  }

  test(
    'waits for both snapshots and guards duplicate writes during snapshots',
    () async {
      await cubit.setRegistered(true);
      expect(store.writes, 0);
      await ready();
      final pending = cubit.setRegistered(true);
      await cubit.setRegistered(true);
      store.events.add(sample);
      store.registrations.add(true);
      await flushEvents();
      expect(cubit.state.busy, true);
      expect(store.writes, 1);
      store.result.complete('1');
      await pending;
      expect(cubit.state.registered, true);
      expect(cubit.state.busy, false);
    },
  );
  test('errors permit retry and cancellation changes status', () async {
    await ready();
    final pending = cubit.setRegistered(true);
    store.result.completeError(StateError('offline'));
    await pending;
    expect(cubit.state.error, contains('offline'));
    expect(cubit.state.busy, false);
    store.result = Completer<String>()..complete('1');
    await cubit.setRegistered(true);
    expect(cubit.state.registered, true);
    await cubit.setRegistered(false);
    expect(cubit.state.registered, false);
  });
  test('stream failure is exposed; deleted event blocks submission', () async {
    await ready();
    store.events.addError(StateError('permission-denied'));
    await flushEvents();
    expect(cubit.state.error, contains('permission-denied'));
    store.events.add(null);
    await flushEvents();
    await cubit.setRegistered(true);
    expect(store.writes, 0);
  });
  test(
    'closing cancels subscriptions and ignores in-flight completion',
    () async {
      await ready();
      final pending = cubit.setRegistered(true);
      await cubit.close();
      expect(store.events.hasListener, false);
      expect(store.registrations.hasListener, false);
      store.result.complete('1');
      await pending;
    },
  );
}
