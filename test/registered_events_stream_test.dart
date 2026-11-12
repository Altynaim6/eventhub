import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub/features/events/models/event_model.dart';
import 'package:eventhub/features/events/repositories/registered_events_stream.dart';

import 'event_bloc_test.dart' show sample, flushEvents;

void main() {
  test('joined events are sorted by date and update in place', () async {
    final earlier = EventModel(
      id: '2',
      title: 'Earlier',
      description: 'Description',
      category: 'Other',
      date: DateTime(2029),
      location: 'Bishkek',
      capacity: 2,
      organizerId: 'organizer',
    );
    final ids = StreamController<Set<String>>.broadcast();
    final first = StreamController<EventModel?>.broadcast();
    final second = StreamController<EventModel?>.broadcast();
    final results = <List<EventModel>>[];
    final subscription = watchReferencedEvents(
      ids.stream,
      (id) => id == '1' ? first.stream : second.stream,
    ).listen(results.add);
    ids.add({'1', '2'});
    await flushEvents();
    first.add(sample);
    await flushEvents();
    expect(results, isEmpty);
    second.add(earlier);
    await flushEvents();
    expect(results.last, [earlier, sample]);
    second.add(null);
    await flushEvents();
    expect(results.last, [sample]);
    await subscription.cancel();
    await ids.close();
    await first.close();
    await second.close();
  });

  test(
    'joins live events, skips missing documents and reuses/removes listeners',
    () async {
      final ids = StreamController<Set<String>>.broadcast();
      final first = StreamController<EventModel?>.broadcast();
      final second = StreamController<EventModel?>.broadcast();
      int watches = 0;
      final results = <List<EventModel>>[];
      final subscription = watchReferencedEvents(ids.stream, (id) {
        watches++;
        return id == '1' ? first.stream : second.stream;
      }).listen(results.add);
      ids.add({'1', 'missing'});
      await flushEvents();
      first.add(sample);
      second.add(null);
      await flushEvents();
      expect(results.last, [sample]);
      ids.add({'1', 'missing'});
      await flushEvents();
      expect(watches, 2);
      first.add(null);
      await flushEvents();
      expect(results.last, isEmpty);
      first.add(sample);
      await flushEvents();
      expect(results.last, [sample]);
      ids.add({'missing'});
      await flushEvents();
      expect(first.hasListener, false);
      expect(results.last, isEmpty);
      ids.add({});
      await flushEvents();
      expect(second.hasListener, false);
      await subscription.cancel();
      expect(ids.hasListener, false);
      await ids.close();
      await first.close();
      await second.close();
    },
  );
  test(
    'propagates query/document errors and recovers with fresh snapshots',
    () async {
      final ids = StreamController<Set<String>>.broadcast();
      final events = StreamController<EventModel?>.broadcast();
      final results = <List<EventModel>>[];
      final errors = <Object>[];
      final subscription = watchReferencedEvents(
        ids.stream,
        (_) => events.stream,
      ).listen(results.add, onError: errors.add);
      ids.add({'1'});
      await flushEvents();
      events.addError(StateError('event denied'));
      ids.addError(StateError('index missing'));
      await flushEvents();
      expect(errors, hasLength(2));
      events.add(sample);
      await flushEvents();
      expect(results.last, [sample]);
      await subscription.cancel();
      expect(events.hasListener, false);
      await ids.close();
      await events.close();
    },
  );
}
