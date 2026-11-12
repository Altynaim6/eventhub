import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub/features/events/bloc/my_events_cubit.dart';

import 'event_bloc_test.dart' show sample, flushEvents;
import 'support/my_store.dart';

void main() {
  late MyStore store;
  late MyEventsCubit cubit;
  setUp(() async {
    store = MyStore();
    cubit = MyEventsCubit(store);
    await flushEvents();
  });
  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
    await store.dispose();
  });
  test(
    'lists load independently, snapshots update and errors allow reload',
    () async {
      store.created.add([sample]);
      await flushEvents();
      expect(cubit.state.created.events, [sample]);
      expect(cubit.state.registered.loading, true);
      store.registered.addError(StateError('offline'));
      await flushEvents();
      expect(cubit.state.registered.error, contains('offline'));
      expect(cubit.state.created.events, [sample]);
      await Future.wait([cubit.reload(), cubit.reload()]);
      expect(store.createdCalls, 2);
      expect(store.registeredCalls, 2);
      store.registered.add([]);
      store.created.add([]);
      await flushEvents();
      expect(cubit.state.registered.error, isNull);
      expect(cubit.state.created.events, isEmpty);
    },
  );
  test(
    'snapshots cannot clear pending cancellation or enable duplicate request',
    () async {
      final pending = cubit.cancel(sample.id);
      await cubit.cancel(sample.id);
      store.registered.add([]);
      await flushEvents();
      expect(store.writes, 1);
      expect(cubit.state.cancelling, contains(sample.id));
      store.result.complete('1');
      await pending;
      expect(cubit.state.cancelling, isEmpty);
      expect(cubit.state.notice, 'Registration cancelled');
    },
  );
  test('failure keeps list and retry can succeed', () async {
    store.registered.add([sample]);
    await flushEvents();
    final pending = cubit.cancel(sample.id);
    store.result.completeError(StateError('denied'));
    await pending;
    expect(cubit.state.notice, contains('denied'));
    expect(cubit.state.registered.events, [sample]);
    store.result = Completer<String>()..complete('1');
    await cubit.cancel(sample.id);
    expect(cubit.state.noticeId, 2);
  });
  test(
    'close cancels list subscriptions and ignores pending completion',
    () async {
      final pending = cubit.cancel(sample.id);
      await cubit.close();
      expect(store.created.hasListener, false);
      expect(store.registered.hasListener, false);
      store.result.complete('1');
      await pending;
    },
  );
}
